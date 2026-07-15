import Foundation
import IRecorderCore
import os.log

final class CaptureCoordinator {
    private let settings: SettingsStore
    private let ax = AXWatcher()
    private let clipboard = ClipboardWatcher()
    private let paste = PasteDetector()
    private let typeSuppressor = InsertionSuppressor()
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
            try FileManager.default.createDirectory(
                at: settings.logDirectoryURL,
                withIntermediateDirectories: true
            )
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
        switch event.kind {
        case .paste:
            typeSuppressor.notePaste(event.payload)
        case .type:
            if typeSuppressor.shouldSuppressType(event.payload) { return }
        case .copy:
            break
        }
        do {
            let maxBytes = PayloadTruncatePolicy.maxBytes(
                for: event.kind,
                configured: settings.clipboardTruncateMaxBytes
            )
            try writer.append(event, maxPayloadBytes: maxBytes)
        } catch {
            log.error("append failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
