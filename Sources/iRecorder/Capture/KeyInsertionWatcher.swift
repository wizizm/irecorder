import AppKit
import Foundation
import IRecorderCore

/// Fallback typing capture for apps (Cursor / Electron) that do not expose AXValue.
/// Uses keyDown `characters` (IME commit yields CJK; English yields letters).
/// Skipped when the focused element already has a readable AX string value.
final class KeyInsertionWatcher {
    var onEvent: ((CaptureEvent) -> Void)?

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
        guard let text = KeyInsertionPolicy.insertion(
            characters: event.characters,
            command: flags.contains(.command),
            option: flags.contains(.option),
            control: flags.contains(.control),
            keyCode: UInt16(event.keyCode)
        ) else { return }

        let ime = InputSourceProbe.isChineseIMEActive()
        guard KeyInsertionPolicy.shouldAcceptForKeyFallback(
            insertion: text,
            chineseIMEActive: ime
        ) else { return }

        let app = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
        onEvent?(CaptureEvent(kind: .type, appName: app, payload: text))
    }
}

/// Focus coverage published by `AXWatcher` for the key-fallback path.
final class AXFocusCoverage {
    var focusedExposesStringValue = false
    var focusedIsSecure = false
}
