import AppKit
import Foundation
import IRecorderCore

final class ClipboardWatcher {
    var onEvent: ((CaptureEvent) -> Void)?

    private var poller: Poller?
    private var lastChangeCount: Int = -1
    private var lastString: String?

    func start() {
        stop()
        lastChangeCount = NSPasteboard.general.changeCount
        lastString = NSPasteboard.general.string(forType: .string)
        let poller = Poller(interval: 0.4) { [weak self] in
            self?.tick()
        }
        poller.start()
        self.poller = poller
    }

    func stop() {
        poller?.stop()
        poller = nil
    }

    private func tick() {
        let board = NSPasteboard.general
        let count = board.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        guard let text = board.string(forType: .string), !text.isEmpty else { return }
        if text == lastString { return }
        lastString = text
        let app = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
        onEvent?(CaptureEvent(kind: .copy, appName: app, payload: text))
    }
}
