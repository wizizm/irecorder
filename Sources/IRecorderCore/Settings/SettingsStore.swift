import Foundation

public final class SettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults

    private enum Key {
        static let logDirectory = "logDirectoryPath"
        static let retentionDays = "retentionDays"
        static let launchAtLogin = "launchAtLogin"
        static let isRecording = "isRecording"
        static let clipboardTruncateMaxBytes = "clipboardTruncateMaxBytes"
        static let typeLineIdleSeconds = "typeLineIdleSeconds"
        static let openTodayLogHotKey = "openTodayLogHotKey"
        static let pasteHistoryHotKey = "pasteHistoryHotKey"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var logDirectoryURL: URL {
        get {
            if let path = defaults.string(forKey: Key.logDirectory), !path.isEmpty {
                return URL(fileURLWithPath: path)
            }
            return Self.defaultLogDirectory
        }
        set {
            defaults.set(newValue.path, forKey: Key.logDirectory)
        }
    }

    public var retentionDays: Int {
        get {
            if defaults.object(forKey: Key.retentionDays) == nil { return 30 }
            return defaults.integer(forKey: Key.retentionDays)
        }
        set { defaults.set(newValue, forKey: Key.retentionDays) }
    }

    public var launchAtLogin: Bool {
        get {
            if defaults.object(forKey: Key.launchAtLogin) == nil { return true }
            return defaults.bool(forKey: Key.launchAtLogin)
        }
        set { defaults.set(newValue, forKey: Key.launchAtLogin) }
    }

    public var isRecording: Bool {
        get {
            if defaults.object(forKey: Key.isRecording) == nil { return true }
            return defaults.bool(forKey: Key.isRecording)
        }
        set { defaults.set(newValue, forKey: Key.isRecording) }
    }

    /// Max UTF-8 bytes kept for copy/paste payloads. `0` = no truncation. Default 100_000.
    public var clipboardTruncateMaxBytes: Int {
        get {
            if defaults.object(forKey: Key.clipboardTruncateMaxBytes) == nil {
                return PayloadTruncator.defaultMaxBytes
            }
            return max(0, defaults.integer(forKey: Key.clipboardTruncateMaxBytes))
        }
        set { defaults.set(max(0, newValue), forKey: Key.clipboardTruncateMaxBytes) }
    }

    /// Seconds of typing idle before a `type` line is flushed. Default 3. Minimum 1.
    public var typeLineIdleSeconds: Int {
        get {
            if defaults.object(forKey: Key.typeLineIdleSeconds) == nil { return 3 }
            return max(1, defaults.integer(forKey: Key.typeLineIdleSeconds))
        }
        set { defaults.set(max(1, newValue), forKey: Key.typeLineIdleSeconds) }
    }

    /// Global shortcut to open today's log file. Default ⇧⌘L.
    public var openTodayLogHotKey: HotKeySpec {
        get {
            guard let data = defaults.data(forKey: Key.openTodayLogHotKey),
                  let decoded = try? JSONDecoder().decode(HotKeySpec.self, from: data)
            else {
                return .defaultOpenTodayLog
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Key.openTodayLogHotKey)
            }
        }
    }

    /// Global shortcut for paste history. Default disabled.
    public var pasteHistoryHotKey: HotKeySpec {
        get {
            guard let data = defaults.data(forKey: Key.pasteHistoryHotKey),
                  let decoded = try? JSONDecoder().decode(HotKeySpec.self, from: data)
            else {
                return .defaultPasteHistory
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Key.pasteHistoryHotKey)
            }
        }
    }

    public static var defaultLogDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iRecorder", isDirectory: true)
    }
}
