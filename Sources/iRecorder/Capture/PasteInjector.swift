import AppKit
import Foundation

/// Writes the pasteboard and synthesizes ⌘V, with capture suppress via the coordinator.
final class PasteInjector {
    private let coordinator: CaptureCoordinator

    init(coordinator: CaptureCoordinator) {
        self.coordinator = coordinator
    }

    /// Activate target, suppress capture, write pasteboard, then synthesize ⌘V. Call on main.
    func paste(payload: String, into app: NSRunningApplication?) {
        // macOS 14+: activate() replaces deprecated activateIgnoringOtherApps.
        _ = app?.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            guard let self else { return }
            self.coordinator.noteProgrammaticClipboard(payload)
            let board = NSPasteboard.general
            board.clearContents()
            board.setString(payload, forType: .string)
            Self.postCommandV()
        }
    }

    private static func postCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
