import Foundation
import IRecorderCore
import os.log

final class CaptureCoordinator {
    private let settings: SettingsStore
    private let ax = AXWatcher()
    private let clipboard = ClipboardWatcher()
    private let paste = PasteDetector()
    private var writer: LogWriter
    private let log = Logger(subsystem: "com.linwenjie.iRecorder", category: "capture")

    init(settings: SettingsStore) {
        self.settings = settings
        self.writer = LogWriter(directory: settings.logDirectoryURL)
    }

    func start() {
        reloadWriter()
        pruneIfNeeded()
        wire(ax)
        wire(clipboard)
        wire(paste)
        ax.start()
        clipboard.start()
        paste.start()
        _ = AXWatcher.isTrusted(prompt: true)
    }

    func stop() {
        ax.stop()
        clipboard.stop()
        paste.stop()
    }

    func reloadWriter() {
        writer = LogWriter(directory: settings.logDirectoryURL)
    }

    func pruneIfNeeded() {
        do {
            try writer.prune(retainDays: settings.retentionDays)
        } catch {
            log.error("prune failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func todayLogURL() -> URL {
        let name = LogFileNamer.fileName(for: Date())
        return settings.logDirectoryURL.appendingPathComponent(name)
    }

    private func wire(_ watcher: AXWatcher) {
        watcher.onEvent = { [weak self] event in self?.handle(event) }
    }

    private func wire(_ watcher: ClipboardWatcher) {
        watcher.onEvent = { [weak self] event in self?.handle(event) }
    }

    private func wire(_ watcher: PasteDetector) {
        watcher.onEvent = { [weak self] event in self?.handle(event) }
    }

    private func handle(_ event: CaptureEvent) {
        guard settings.isRecording else { return }
        do {
            try writer.append(event)
        } catch {
            log.error("append failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
