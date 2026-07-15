import Foundation

public final class SettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults

    private enum Key {
        static let logDirectory = "logDirectoryPath"
        static let retentionDays = "retentionDays"
        static let launchAtLogin = "launchAtLogin"
        static let isRecording = "isRecording"
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

    public static var defaultLogDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iRecorder", isDirectory: true)
    }
}
