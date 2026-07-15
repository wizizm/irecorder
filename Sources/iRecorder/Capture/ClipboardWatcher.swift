import AppKit
import Foundation
import IRecorderCore

final class ClipboardWatcher {
    var onEvent: ((CaptureEvent) -> Void)?

    private var timer: Timer?
    private var lastChangeCount: Int = -1
    private var lastString: String?

    func start() {
        stop()
        lastChangeCount = NSPasteboard.general.changeCount
        lastString = NSPasteboard.general.string(forType: .string)
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
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
