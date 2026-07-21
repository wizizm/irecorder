import Foundation

public enum CheckForUpdatesMenuTitle {
    public enum Language: Sendable {
        case chinese
        case english
    }

    public static func format(
        version: String,
        language: Language,
        appName: String = "iRecorder"
    ) -> String {
        switch language {
        case .chinese:
            return "检查更新（\(appName) v\(version)）"
        case .english:
            return "Check for Updates (\(appName) v\(version))"
        }
    }
}
