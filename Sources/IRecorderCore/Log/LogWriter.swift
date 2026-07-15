import Foundation

public final class LogWriter: @unchecked Sendable {
    private let directory: URL
    private let calendar: Calendar
    private let fileManager: FileManager
    private let timeZone: TimeZone

    public init(
        directory: URL,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current,
        fileManager: FileManager = .default
    ) {
        self.directory = directory
        self.calendar = calendar
        self.timeZone = timeZone
        self.fileManager = fileManager
    }

    public func append(_ event: CaptureEvent, maxPayloadBytes: Int? = PayloadTruncator.defaultMaxBytes) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let payload: String
        if let maxPayloadBytes {
            payload = PayloadTruncator.truncate(event.payload, maxBytes: maxPayloadBytes)
        } else {
            payload = event.payload
        }
        let truncated = CaptureEvent(
            kind: event.kind,
            appName: event.appName,
            payload: payload,
            date: event.date
        )
        let line = LogLineFormatter.format(event: truncated, timeZone: timeZone) + "\n"
        let fileURL = directory.appendingPathComponent(LogFileNamer.fileName(for: event.date, calendar: calendar))
        if !fileManager.fileExists(atPath: fileURL.path) {
            try Data(line.utf8).write(to: fileURL, options: .atomic)
            return
        }
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(line.utf8))
    }

    public func prune(retainDays: Int, today: Date = Date()) throws {
        let names = try fileManager.contentsOfDirectory(atPath: directory.path)
        let doomed = RetentionPruner.filesToDelete(
            names: names,
            today: today,
            retainDays: retainDays,
            calendar: calendar
        )
        for name in doomed {
            try fileManager.removeItem(at: directory.appendingPathComponent(name))
        }
    }
}
