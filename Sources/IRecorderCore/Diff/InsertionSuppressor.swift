import Foundation

/// Suppresses AX `type` events that echo a recent paste into the same field.
public final class InsertionSuppressor: @unchecked Sendable {
    private let ttl: TimeInterval
    private var pending: String?
    private var expiresAt: Date?
    private let lock = NSLock()

    public init(ttl: TimeInterval = 1.5) {
        self.ttl = ttl
    }

    public func notePaste(_ payload: String) {
        lock.lock()
        defer { lock.unlock() }
        pending = payload
        expiresAt = Date().addingTimeInterval(ttl)
    }

    public func shouldSuppressType(_ payload: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let pending, let expiresAt, Date() < expiresAt else {
            self.pending = nil
            self.expiresAt = nil
            return false
        }
        if payload == pending || pending.hasPrefix(payload) || payload.hasPrefix(pending) {
            if payload == pending {
                self.pending = nil
                self.expiresAt = nil
            }
            return true
        }
        return false
    }
}
