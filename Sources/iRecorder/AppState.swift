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
    }

    func start() {
        applyLoginItem(settings.launchAtLogin)
        coordinator.start()
        refreshAccessibility()
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
    }

    /// Bring an already-created Settings window above other apps (safe if not open yet).
    func bringSettingsWindowForward() {
        NSApp.activate(ignoringOtherApps: true)
        let raise = { [weak self] in
            self?.raiseSettingsWindows()
        }
        DispatchQueue.main.async(execute: raise)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: raise)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: raise)
    }

    private func raiseSettingsWindows() {
        NSApp.activate(ignoringOtherApps: true)
        let settingsWindows = NSApp.windows.filter { window in
            let id = window.identifier?.rawValue ?? ""
            let title = window.title
            let className = String(describing: type(of: window))
            return id.localizedCaseInsensitiveContains("settings")
                || title.contains("设置")
                || title.localizedCaseInsensitiveContains("settings")
                || className.localizedCaseInsensitiveContains("settings")
        }
        for window in settingsWindows {
            window.deminiaturize(nil)
            window.collectionBehavior.insert(.moveToActiveSpace)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
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
