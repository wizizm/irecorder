import Foundation

public enum UpdateCheckOutcome: Equatable, Sendable {
    case upToDate(current: String)
    case updateAvailable(current: String, latest: String, downloadURL: URL)
}

public enum UpdateCheckerError: Error, Equatable, LocalizedError, Sendable {
    case zipAssetMissing
    case downloadFailed
    case appBundleMissingInArchive
    case installFailed

    public var errorDescription: String? {
        switch self {
        case .zipAssetMissing:
            return "Latest release has no .zip asset."
        case .downloadFailed:
            return "Could not download the update."
        case .appBundleMissingInArchive:
            return "Downloaded archive does not contain iRecorder.app."
        case .installFailed:
            return "Could not replace the installed application."
        }
    }
}

public protocol ReleaseFetching: Sendable {
    func fetchLatestReleaseData() async throws -> Data
}

public struct UpdateChecker: Sendable {
    public var localVersion: String
    public var fetcher: any ReleaseFetching

    public init(localVersion: String, fetcher: any ReleaseFetching) {
        self.localVersion = localVersion
        self.fetcher = fetcher
    }

    public func check() async throws -> UpdateCheckOutcome {
        let data = try await fetcher.fetchLatestReleaseData()
        let release = try GitHubRelease.decode(from: data)
        let latest = VersionCompare.normalize(release.tagName)
        let current = VersionCompare.normalize(localVersion)

        guard VersionCompare.isRemoteNewer(local: current, remote: latest) else {
            return .upToDate(current: current)
        }
        guard let zipURL = release.zipAssetDownloadURL else {
            throw UpdateCheckerError.zipAssetMissing
        }
        return .updateAvailable(current: current, latest: latest, downloadURL: zipURL)
    }
}
