import AppKit
import Foundation
import IRecorderCore

final class PasteDetector {
    var onEvent: ((CaptureEvent) -> Void)?

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
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command),
              !flags.contains(.shift),
              !flags.contains(.option),
              !flags.contains(.control) else { return }
        guard event.charactersIgnoringModifiers?.lowercased() == "v" else { return }
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else { return }
        let app = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
        onEvent?(CaptureEvent(kind: .paste, appName: app, payload: text))
    }
}
