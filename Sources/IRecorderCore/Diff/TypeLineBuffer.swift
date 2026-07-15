import Foundation

/// Accumulates typed insertions into one log line until idle timeout or Enter/newline.
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

    /// Append insertion text. Newlines flush the pending line immediately.
    @discardableResult
    public func ingest(appName: String, insertion: String, at now: Date = Date()) -> [Flush] {
        lock.lock()
        defer { lock.unlock() }
        var out: [Flush] = []
        if !buffer.isEmpty, !self.appName.isEmpty, self.appName != appName {
            out.append(takeFlushLocked(at: now))
        }
        self.appName = appName

        var piece = ""
        for ch in insertion {
            if ch == "\n" || ch == "\r" {
                if !piece.isEmpty {
                    buffer += piece
                    lastInputAt = now
                    piece = ""
                }
                if !buffer.isEmpty {
                    out.append(takeFlushLocked(at: now))
                }
                continue
            }
            piece.append(ch)
        }
        if !piece.isEmpty {
            buffer += piece
            lastInputAt = now
        }
        return out
    }

    public func noteEnter(at now: Date = Date()) -> Flush? {
        lock.lock()
        defer { lock.unlock() }
        guard !buffer.isEmpty else { return nil }
        return takeFlushLocked(at: now)
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

    private func takeFlushLocked(at now: Date) -> Flush {
        let payload = buffer
        let name = appName.isEmpty ? "Unknown" : appName
        buffer = ""
        lastInputAt = nil
        return Flush(appName: name, payload: payload, date: now)
    }
}
