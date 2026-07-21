import AppKit
import Combine
import Foundation
import IRecorderCore
import ServiceManagement
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    let settings: SettingsStore
    let coordinator: CaptureCoordinator

    @Published var isRecording: Bool
    @Published var accessibilityTrusted: Bool
    @Published var loginItemEnabled: Bool
    @Published var retentionDays: Int
    @Published var logDirectoryPath: String
    /// Display unit: kilobytes (1000 bytes). 0 = unlimited.
    @Published var clipboardTruncateMaxKB: Int
    @Published var typeLineIdleSeconds: Int
    @Published var openTodayLogHotKey: HotKeySpec
    @Published var pasteHistoryHotKey: HotKeySpec

    private let hotKeyMonitor: HotKeyMonitor
    private let pasteInjector: PasteInjector
    private let pasteHistoryPanel = PasteHistoryPanelController()

    /// Fixed Carbon hot-key IDs for multi-binding dispatch.
    private enum HotKeyBindingID {
        static let openTodayLog: UInt32 = 1
        static let pasteHistory: UInt32 = 2
    }

    init(settings: SettingsStore = SettingsStore()) {
        self.settings = settings
        self.coordinator = CaptureCoordinator(settings: settings)
        self.isRecording = settings.isRecording
        self.accessibilityTrusted = AXWatcher.isTrusted(prompt: false)
        self.loginItemEnabled = settings.launchAtLogin
        self.retentionDays = settings.retentionDays
        self.logDirectoryPath = settings.logDirectoryURL.path
        self.clipboardTruncateMaxKB = settings.clipboardTruncateMaxBytes / 1000
        self.typeLineIdleSeconds = settings.typeLineIdleSeconds
        self.openTodayLogHotKey = settings.openTodayLogHotKey
        self.pasteHistoryHotKey = settings.pasteHistoryHotKey
        self.hotKeyMonitor = HotKeyMonitor()
        self.pasteInjector = PasteInjector(coordinator: coordinator)
        self.hotKeyMonitor.setBinding(
            id: HotKeyBindingID.openTodayLog,
            spec: settings.openTodayLogHotKey
        ) { [weak self] in
            self?.openTodayLog()
        }
        self.hotKeyMonitor.setBinding(
            id: HotKeyBindingID.pasteHistory,
            spec: settings.pasteHistoryHotKey
        ) { [weak self] in
            self?.showPasteHistory()
        }
    }

    func start() {
        applyLoginItem(settings.launchAtLogin)
        coordinator.start()
        hotKeyMonitor.setBinding(
            id: HotKeyBindingID.openTodayLog,
            spec: openTodayLogHotKey
        ) { [weak self] in
            self?.openTodayLog()
        }
        hotKeyMonitor.setBinding(
            id: HotKeyBindingID.pasteHistory,
            spec: pasteHistoryHotKey
        ) { [weak self] in
            self?.showPasteHistory()
        }
        hotKeyMonitor.start()
        refreshAccessibility()
    }

    func stop() {
        hotKeyMonitor.stop()
        coordinator.stop()
    }

    /// Start capture without popping permission UI (re-check status quietly).
    func startPromptingAccessibilityIfNeeded() {
        start()
    }

    func toggleRecording() {
        isRecording.toggle()
        settings.isRecording = isRecording
    }

    func refreshAccessibility() {
        accessibilityTrusted = AXWatcher.isTrusted(prompt: false)
    }

    /// User-initiated only (Settings button / menu item).
    func promptAccessibility() {
        _ = AXWatcher.isTrusted(prompt: true)
        refreshAccessibility()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        // After user toggles the checkbox, status usually updates only after relaunch.
        for delay in [0.5, 1.0, 2.0, 3.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.refreshAccessibility()
            }
        }
    }

    /// Quit and reopen so Accessibility grant takes effect for this process.
    func relaunchToApplyAccessibility() {
        let appURL = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
        // Fallback terminate if open callback is delayed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            NSApp.terminate(nil)
        }
    }

    /// Bring Settings forward and keep its frame on the visible screen (menu-bar apps often restore off-screen).
    func bringSettingsWindowForward() {
        NSApp.activate(ignoringOtherApps: true)
        let raise: () -> Void = { [weak self] in
            self?.raiseSettingsWindows()
        }
        // openSettings() creates the window asynchronously — retry a few times.
        for delay in [0.0, 0.05, 0.12, 0.25, 0.45] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: raise)
        }
    }

    private func raiseSettingsWindows() {
        NSApp.activate(ignoringOtherApps: true)
        let settingsWindows = NSApp.windows.filter { Self.isSettingsWindow($0) }
        for window in settingsWindows {
            window.deminiaturize(nil)
            window.collectionBehavior.insert(.moveToActiveSpace)
            Self.placeSettingsWindowOnScreen(window)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }

    private static func isSettingsWindow(_ window: NSWindow) -> Bool {
        let id = window.identifier?.rawValue ?? ""
        let title = window.title
        let className = String(describing: type(of: window))
        return id.localizedCaseInsensitiveContains("settings")
            || title.contains("设置")
            || title.localizedCaseInsensitiveContains("settings")
            || className.localizedCaseInsensitiveContains("settings")
    }

    private static func placeSettingsWindowOnScreen(_ window: NSWindow) {
        let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else {
            window.center()
            return
        }
        let visible = screen.visibleFrame
        let fixed = WindowFrameClamp.ensureVisible(frame: window.frame, screenVisible: visible)
        if fixed.origin != window.frame.origin {
            window.setFrame(fixed, display: true)
        }
    }

    func openTodayLog() {
        let url = coordinator.todayLogURL()
        try? FileManager.default.createDirectory(
            at: settings.logDirectoryURL,
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: Data())
        }
        NSWorkspace.shared.open(url)
    }

    /// Capture frontmost app, show paste-history panel; select pastes into prior app.
    func showPasteHistory() {
        let priorApp = NSWorkspace.shared.frontmostApplication
        pasteHistoryPanel.show(
            logDirectory: settings.logDirectoryURL,
            onSelect: { [weak self] item in
                guard let self else { return }
                self.pasteInjector.paste(payload: item.payload, into: priorApp)
            },
            // Panel already hides itself; no AppState side effects needed.
            onDismiss: {}
        )
    }

    func openLogFolder() {
        try? FileManager.default.createDirectory(
            at: settings.logDirectoryURL,
            withIntermediateDirectories: true
        )
        NSWorkspace.shared.open(settings.logDirectoryURL)
    }

    func chooseLogDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = settings.logDirectoryURL
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.logDirectoryURL = url
        logDirectoryPath = url.path
        coordinator.reloadWriter()
    }

    func updateRetentionDays(_ days: Int) {
        retentionDays = max(0, days)
        settings.retentionDays = retentionDays
        coordinator.pruneIfNeeded()
    }

    func updateClipboardTruncateMaxKB(_ kb: Int) {
        clipboardTruncateMaxKB = max(0, kb)
        settings.clipboardTruncateMaxBytes = clipboardTruncateMaxKB * 1000
    }

    func updateTypeLineIdleSeconds(_ seconds: Int) {
        typeLineIdleSeconds = max(1, seconds)
        settings.typeLineIdleSeconds = typeLineIdleSeconds
        coordinator.syncIdleInterval()
    }

    func updateOpenTodayLogHotKey(_ hotKey: HotKeySpec) {
        openTodayLogHotKey = hotKey
        settings.openTodayLogHotKey = hotKey
        hotKeyMonitor.setBinding(
            id: HotKeyBindingID.openTodayLog,
            spec: hotKey
        ) { [weak self] in
            self?.openTodayLog()
        }
        hotKeyMonitor.start()
    }

    func updatePasteHistoryHotKey(_ hotKey: HotKeySpec) {
        pasteHistoryHotKey = hotKey
        settings.pasteHistoryHotKey = hotKey
        hotKeyMonitor.setBinding(
            id: HotKeyBindingID.pasteHistory,
            spec: hotKey
        ) { [weak self] in
            self?.showPasteHistory()
        }
        hotKeyMonitor.start()
    }

    func setHotKeyRecordingSuspended(_ suspended: Bool) {
        hotKeyMonitor.isSuspended = suspended
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        loginItemEnabled = enabled
        settings.launchAtLogin = enabled
        applyLoginItem(enabled)
    }

    private func applyLoginItem(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Not running as a registered app bundle yet — ignore until packaged.
        }
    }
}
