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
    private var idlePoller: Poller?
    private var didStart = false
    private var activity: NSObjectProtocol?
    private let log = Logger(subsystem: "com.linwenjie.iRecorder", category: "capture")

    init(settings: SettingsStore) {
        self.settings = settings
        self.writer = LogWriter(directory: settings.logDirectoryURL)
        self.typeBuffer = TypeLineBuffer(idleInterval: TimeInterval(settings.typeLineIdleSeconds))
    }

    func start() {
        if didStart {
            reloadWriter()
            syncIdleInterval()
            _ = AXWatcher.isTrusted(prompt: false)
            return
        }
        didStart = true

        // Menu-bar apps are App-Nap / auto-termination candidates; that freezes timers and
        // looks like "nothing is logged". Keep us awake while recording.
        ProcessInfo.processInfo.disableAutomaticTermination("iRecorder is capturing")
        ProcessInfo.processInfo.disableSuddenTermination()
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep, .latencyCritical],
            reason: "iRecorder text capture"
        )

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
        startIdlePoller()
        writeSessionStarted()
        // Never prompt here — opening the AX dialog on every launch is annoying.
        // User can grant via Settings / menu "授予辅助功能权限…".
        _ = AXWatcher.isTrusted(prompt: false)
        log.error("capture started dir=\(self.settings.logDirectoryURL.path, privacy: .public)")
    }

    func stop() {
        idlePoller?.stop()
        idlePoller = nil
        flushTypePending()
        writeAll(copyPasteMerger.flushPending())
        ax.stop()
        clipboard.stop()
        paste.stop()
        returnKey.stop()
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
        ProcessInfo.processInfo.enableAutomaticTermination("iRecorder is capturing")
        ProcessInfo.processInfo.enableSuddenTermination()
        didStart = false
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

    private func startIdlePoller() {
        idlePoller?.stop()
        let poller = Poller(interval: 0.25) { [weak self] in
            self?.flushTypeIfIdle()
            self?.flushCopyPasteIfExpired()
        }
        poller.start()
        idlePoller = poller
    }

    private func writeSessionStarted() {
        // Bypass SelfCaptureFilter so we can prove capture/write path is alive.
        let event = CaptureEvent(
            kind: .type,
            appName: "System",
            payload: "session_started",
            date: Date()
        )
        do {
            try writer.append(event, maxPayloadBytes: nil)
            log.error("wrote session_started")
        } catch {
            log.error("session_started write failed: \(error.localizedDescription, privacy: .public)")
        }
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
            scheduleCopyPasteExpiry()
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

    private func scheduleCopyPasteExpiry() {
        let delay = copyPasteMerger.mergeWindow + 0.05
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.flushCopyPasteIfExpired()
        }
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
            log.error("wrote \(event.kind.rawValue, privacy: .public) app=\(event.appName, privacy: .public) bytes=\(event.payload.utf8.count)")
        } catch {
            log.error("append failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
