import Foundation

/// Merges a copy followed quickly by paste of the same text into one `copy_paste` line.
/// Any interrupting activity (e.g. typing) flushes a pending copy as a normal `copy`.
public final class CopyPasteMerger: @unchecked Sendable {
    public var mergeWindow: TimeInterval

    private struct Pending {
        let appName: String
        let payload: String
        let date: Date
    }

    private var pending: Pending?
    private let lock = NSLock()

    public init(mergeWindow: TimeInterval = 3) {
        self.mergeWindow = max(0.5, mergeWindow)
    }

    /// Hold the copy briefly expecting a same-text paste.
    public func noteCopy(appName: String, payload: String, at now: Date = Date()) -> [CaptureEvent] {
        lock.lock()
        defer { lock.unlock() }
        var out: [CaptureEvent] = []
        if let pending {
            out.append(asCopy(pending))
        }
        self.pending = Pending(appName: appName, payload: payload, date: now)
        return out
    }

    public func notePaste(appName: String, payload: String, at now: Date = Date()) -> [CaptureEvent] {
        lock.lock()
        defer { lock.unlock() }
        if let pending,
           pending.payload == payload,
           now.timeIntervalSince(pending.date) <= mergeWindow {
            let app = Self.mergedAppName(copyApp: pending.appName, pasteApp: appName)
            self.pending = nil
            return [
                CaptureEvent(kind: .copyPaste, appName: app, payload: payload, date: now),
            ]
        }
        var out: [CaptureEvent] = []
        if let pending {
            out.append(asCopy(pending))
            self.pending = nil
        }
        out.append(CaptureEvent(kind: .paste, appName: appName, payload: payload, date: now))
        return out
    }

    /// Call when typing (or other recorded text) happens between copy and paste.
    public func noteInterruptingActivity(at now: Date = Date()) -> [CaptureEvent] {
        lock.lock()
        defer { lock.unlock() }
        return takePendingCopyLocked()
    }

    public func tick(at now: Date = Date()) -> [CaptureEvent] {
        lock.lock()
        defer { lock.unlock() }
        guard let pending else { return [] }
        if now.timeIntervalSince(pending.date) >= mergeWindow {
            return takePendingCopyLocked()
        }
        return []
    }

    public func flushPending(at now: Date = Date()) -> [CaptureEvent] {
        lock.lock()
        defer { lock.unlock() }
        return takePendingCopyLocked()
    }

    private func takePendingCopyLocked() -> [CaptureEvent] {
        guard let pending else { return [] }
        self.pending = nil
        return [asCopy(pending)]
    }

    private func asCopy(_ pending: Pending) -> CaptureEvent {
        CaptureEvent(kind: .copy, appName: pending.appName, payload: pending.payload, date: pending.date)
    }

    private static func mergedAppName(copyApp: String, pasteApp: String) -> String {
        copyApp == pasteApp ? pasteApp : "\(copyApp)→\(pasteApp)"
    }
}
