import Foundation

/// Accumulates typed insertions into one log line until idle timeout (or app switch).
/// Enter / embedded newlines do **not** flush — Enter is commonly used to confirm IME candidates.
public final class TypeLineBuffer: @unchecked Sendable {
    public struct Flush: Equatable, Sendable {
        public let appName: String
        public let payload: String
        public let date: Date

        public init(appName: String, payload: String, date: Date) {
            self.appName = appName
            self.payload = payload
            self.date = date
        }
    }

    public var idleInterval: TimeInterval

    private var buffer = ""
    private var appName = ""
    private var lastInputAt: Date?
    private let lock = NSLock()

    public init(idleInterval: TimeInterval = 3) {
        self.idleInterval = max(0.5, idleInterval)
    }

    /// Append insertion text. Newlines are kept in the buffer; only idle / app-switch flushes.
    @discardableResult
    public func ingest(appName: String, insertion: String, at now: Date = Date()) -> [Flush] {
        lock.lock()
        defer { lock.unlock() }
        var out: [Flush] = []
        if !buffer.isEmpty, !self.appName.isEmpty, self.appName != appName {
            out.append(takeFlushLocked(at: now))
        }
        self.appName = appName

        guard !insertion.isEmpty else { return out }
        buffer += insertion
        lastInputAt = now
        return out
    }

    /// Kept for callers; Enter no longer ends a type line (IME confirm uses Enter).
    public func noteEnter(at now: Date = Date()) -> Flush? {
        _ = now
        return nil
    }

    public func tick(at now: Date = Date()) -> Flush? {
        lock.lock()
        defer { lock.unlock() }
        guard !buffer.isEmpty, let last = lastInputAt else { return nil }
        if now.timeIntervalSince(last) >= idleInterval {
            return takeFlushLocked(at: now)
        }
        return nil
    }

    public func flushPending(at now: Date = Date()) -> Flush? {
        lock.lock()
        defer { lock.unlock() }
        guard !buffer.isEmpty else { return nil }
        return takeFlushLocked(at: now)
    }

    /// Drop buffered text without emitting (e.g. Cursor chat bubble supersedes key noise).
    public func discardPending() {
        lock.lock()
        defer { lock.unlock() }
        buffer = ""
        lastInputAt = nil
    }

    private func takeFlushLocked(at now: Date) -> Flush {
        let payload = buffer
        let name = appName.isEmpty ? "Unknown" : appName
        buffer = ""
        lastInputAt = nil
        return Flush(appName: name, payload: payload, date: now)
    }
}
