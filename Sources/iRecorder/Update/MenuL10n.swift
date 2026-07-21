import Foundation
import IRecorderCore

enum MenuLanguage: Equatable {
    case english
    case chinese

    static func resolve(preferredLanguages: [String] = Locale.preferredLanguages) -> MenuLanguage {
        guard let first = preferredLanguages.first?.lowercased() else { return .english }
        return first.hasPrefix("zh") ? .chinese : .english
    }
}

enum MenuL10nKey {
    case checkForUpdates
    case help
    case upToDateTitle
    case updateAvailableTitle
    case updateFailedTitle
    case downloadAndInstall
    case cancel
    case checkingForUpdates
    case ok
}

enum MenuL10n {
    static var language: MenuLanguage { .resolve() }

    static func text(_ key: MenuL10nKey) -> String {
        switch language {
        case .chinese: return zh[key]!
        case .english: return en[key]!
        }
    }

    static func updateAvailableMessage(current: String, latest: String) -> String {
        switch language {
        case .chinese:
            return "当前版本 \(current)，最新版本 \(latest)。下载并安装后应用将重启。"
        case .english:
            return "You have \(current). Version \(latest) is available. The app will relaunch after install."
        }
    }

    static func upToDateMessage(current: String) -> String {
        switch language {
        case .chinese:
            return "当前版本 \(current) 已是最新。"
        case .english:
            return "iRecorder \(current) is the latest version."
        }
    }

    private static let en: [MenuL10nKey: String] = [
        .checkForUpdates: "Check for Updates…",
        .help: "Help",
        .upToDateTitle: "You’re Up to Date",
        .updateAvailableTitle: "Update Available",
        .updateFailedTitle: "Update Check Failed",
        .downloadAndInstall: "Download and Install",
        .cancel: "Cancel",
        .checkingForUpdates: "Checking for Updates…",
        .ok: "OK",
    ]

    private static let zh: [MenuL10nKey: String] = [
        .checkForUpdates: "检查更新…",
        .help: "帮助",
        .upToDateTitle: "已是最新版本",
        .updateAvailableTitle: "有可用更新",
        .updateFailedTitle: "检查更新失败",
        .downloadAndInstall: "下载并安装",
        .cancel: "取消",
        .checkingForUpdates: "正在检查更新…",
        .ok: "好",
    ]
}
