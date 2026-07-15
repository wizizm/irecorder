import Foundation
import IRecorderCore
import os.log

final class CaptureCoordinator {
    private let settings: SettingsStore
    private let ax = AXWatcher()
    private let clipboard = ClipboardWatcher()
    private let paste = PasteDetector()
    private let returnKey = ReturnKeyDetector()
    private let typeSuppressor = InsertionSuppressor()
    private let typeBuffer: TypeLineBuffer
    private let copyPasteMerger = CopyPasteMerger(mergeWindow: 3)
    private var writer: LogWriter
    private var idleTimer: Timer?
    private let log = Logger(subsystem: "com.linwenjie.iRecorder", category: "capture")

    init(settings: SettingsStore) {
        self.settings = settings
        self.writer = LogWriter(directory: settings.logDirectoryURL)
        self.typeBuffer = TypeLineBuffer(idleInterval: TimeInterval(settings.typeLineIdleSeconds))
    }

    func start() {
        reloadWriter()
        syncIdleInterval()
        pruneIfNeeded()
        wire(ax)
        wire(clipboard)
        wire(paste)
        returnKey.onReturn = { [weak self] in
            self?.flushTypeEnter()
        }
        ax.start()
        clipboard.start()
        paste.start()
        returnKey.start()
        startIdleTimer()
        _ = AXWatcher.isTrusted(prompt: true)
    }

    func stop() {
        idleTimer?.invalidate()
        idleTimer = nil
        flushTypePending()
        writeAll(copyPasteMerger.flushPending())
        ax.stop()
        clipboard.stop()
        paste.stop()
        returnKey.stop()
    }

    func reloadWriter() {
        writer = LogWriter(directory: settings.logDirectoryURL)
    }

    func syncIdleInterval() {
        typeBuffer.idleInterval = TimeInterval(settings.typeLineIdleSeconds)
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

    private func startIdleTimer() {
        idleTimer?.invalidate()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.flushTypeIfIdle()
            self?.flushCopyPasteIfExpired()
        }
        RunLoop.main.add(timer, forMode: .common)
        idleTimer = timer
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
        if SelfCaptureFilter.shouldIgnore(payload: event.payload, appName: event.appName) {
            return
        }
        switch event.kind {
        case .paste:
            flushTypePending()
            typeSuppressor.notePaste(event.payload)
            writeAll(copyPasteMerger.notePaste(
                appName: event.appName,
                payload: event.payload,
                at: event.date
            ))
        case .copy:
            flushTypePending()
            writeAll(copyPasteMerger.noteCopy(
                appName: event.appName,
                payload: event.payload,
                at: event.date
            ))
        case .copyPaste:
            write(event)
        case .type:
            if typeSuppressor.shouldSuppressType(event.payload) { return }
            if CompositionInsertionFilter.shouldIgnore(
                insertion: event.payload,
                chineseIMEActive: InputSourceProbe.isChineseIMEActive()
            ) {
                return
            }
            writeAll(copyPasteMerger.noteInterruptingActivity(at: event.date))
            syncIdleInterval()
            let flushes = typeBuffer.ingest(
                appName: event.appName,
                insertion: event.payload,
                at: event.date
            )
            for flush in flushes {
                writeTypeFlush(flush)
            }
        }
    }

    private func flushTypeEnter() {
        guard settings.isRecording else { return }
        writeAll(copyPasteMerger.noteInterruptingActivity())
        if let flush = typeBuffer.noteEnter() {
            writeTypeFlush(flush)
        }
    }

    private func flushTypeIfIdle() {
        guard settings.isRecording else { return }
        syncIdleInterval()
        if let flush = typeBuffer.tick() {
            writeAll(copyPasteMerger.noteInterruptingActivity(at: flush.date))
            writeTypeFlush(flush)
        }
    }

    private func flushCopyPasteIfExpired() {
        guard settings.isRecording else { return }
        writeAll(copyPasteMerger.tick())
    }

    private func flushTypePending() {
        if let flush = typeBuffer.flushPending() {
            writeAll(copyPasteMerger.noteInterruptingActivity(at: flush.date))
            writeTypeFlush(flush)
        }
    }

    private func writeTypeFlush(_ flush: TypeLineBuffer.Flush) {
        if SelfCaptureFilter.shouldIgnore(payload: flush.payload, appName: flush.appName) {
            return
        }
        let event = CaptureEvent(
            kind: .type,
            appName: flush.appName,
            payload: flush.payload,
            date: flush.date
        )
        write(event)
    }

    private func writeAll(_ events: [CaptureEvent]) {
        for event in events {
            write(event)
        }
    }

    private func write(_ event: CaptureEvent) {
        if SelfCaptureFilter.shouldIgnore(payload: event.payload, appName: event.appName) {
            return
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
