import AppKit
import IRecorderCore
import SwiftUI

/// Invisible view that, while `isActive`, captures the next keyDown with modifiers as a HotKeySpec.
struct HotKeyCaptureView: NSViewRepresentable {
    @Binding var isActive: Bool
    var onCapture: (HotKeySpec) -> Void

    func makeNSView(context: Context) -> CaptureNSView {
        let view = CaptureNSView()
        view.onCapture = onCapture
        view.onCancel = { isActive = false }
        return view
    }

    func updateNSView(_ nsView: CaptureNSView, context: Context) {
        nsView.onCapture = onCapture
        nsView.onCancel = { isActive = false }
        nsView.setActive(isActive)
    }

    final class CaptureNSView: NSView {
        var onCapture: ((HotKeySpec) -> Void)?
        var onCancel: (() -> Void)?
        private var monitor: Any?
        private var active = false

        override var acceptsFirstResponder: Bool { true }

        func setActive(_ active: Bool) {
            guard self.active != active else { return }
            self.active = active
            if active {
                window?.makeFirstResponder(self)
                startMonitor()
            } else {
                stopMonitor()
            }
        }

        private func startMonitor() {
            stopMonitor()
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.active else { return event }
                if event.keyCode == 53 { // Escape
                    self.active = false
                    self.stopMonitor()
                    self.onCancel?()
                    return nil
                }
                let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
                let command = flags.contains(.command)
                let shift = flags.contains(.shift)
                let option = flags.contains(.option)
                let control = flags.contains(.control)
                // Global shortcuts should include ⌘ or ⌃ — avoids sticky/extra modifiers from mis-records.
                guard command || control else { return event }
                let spec = HotKeySpec(
                    keyCode: UInt16(event.keyCode),
                    command: command,
                    shift: shift,
                    option: option,
                    control: control,
                    isEnabled: true
                )
                self.active = false
                self.stopMonitor()
                self.onCapture?(spec)
                return nil
            }
        }

        private func stopMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit {
            stopMonitor()
        }
    }
}
