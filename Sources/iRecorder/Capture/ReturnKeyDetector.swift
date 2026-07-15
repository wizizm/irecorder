import AppKit
import Foundation

/// Flushes the typing buffer when Return/Enter is pressed.
final class ReturnKeyDetector {
    var onReturn: (() -> Void)?

    private var monitor: Any?

    func start() {
        stop()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            if event.keyCode == 36 || event.keyCode == 76 { // Return / keypad Enter
                self.onReturn?()
            }
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
