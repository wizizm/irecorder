import AppKit
import Foundation
import IRecorderCore

/// Fallback typing capture for apps (Cursor / Electron) that do not expose AXValue.
/// Latin under Chinese IME is ignored (pinyin noise). Cursor chat Chinese is captured
/// after send via `CursorChatAXProbe` (message bubbles in the AX tree).
final class KeyInsertionWatcher {
    var onEvent: ((CaptureEvent) -> Void)?
    /// Fired on plain Return while key-fallback is active (Cursor chat send).
    var onPlainReturn: (() -> Void)?

    /// Shared focus snapshot from `AXWatcher` (updated on its poll).
    weak var focus: AXFocusCoverage?

    private var monitor: Any?

    func start() {
        stop()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func handle(_ event: NSEvent) {
        guard AXWatcher.isTrusted(prompt: false) else { return }
        if focus?.focusedIsSecure == true { return }
        // Prefer AX path when the field exposes a string value (Notes / TextEdit / 企业微信).
        if focus?.focusedExposesStringValue == true { return }

        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let keyCode = UInt16(event.keyCode)
        if KeyInsertionPolicy.isPlainReturn(
            keyCode: keyCode,
            command: flags.contains(.command),
            option: flags.contains(.option),
            control: flags.contains(.control),
            shift: flags.contains(.shift)
        ) || KeyInsertionPolicy.isCommandReturn(
            keyCode: keyCode,
            command: flags.contains(.command),
            option: flags.contains(.option),
            control: flags.contains(.control)
        ) {
            onPlainReturn?()
            return
        }

        guard let raw = KeyInsertionPolicy.insertion(
            characters: event.characters,
            command: flags.contains(.command),
            option: flags.contains(.option),
            control: flags.contains(.control),
            keyCode: keyCode
        ) else { return }

        let text = KeyInsertionPolicy.sanitizeKeyInsertion(raw)
        let ime = InputSourceProbe.isChineseIMEActive()
        let front = NSWorkspace.shared.frontmostApplication
        let vscodeBased = VSCodeBasedIDEPolicy.matches(
            appName: front?.localizedName ?? "",
            bundleID: front?.bundleIdentifier
        )
        guard KeyInsertionPolicy.shouldAcceptForKeyFallback(
            insertion: text,
            chineseIMEActive: ime,
            vscodeBasedIDE: vscodeBased
        ) else { return }

        let app = front?.localizedName ?? "Unknown"
        onEvent?(CaptureEvent(kind: .type, appName: app, payload: text))
    }
}

/// Focus coverage published by `AXWatcher` for the key-fallback path.
final class AXFocusCoverage {
    var focusedExposesStringValue = false
    var focusedIsSecure = false
}
