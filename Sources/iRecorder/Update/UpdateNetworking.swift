import Foundation
import IRecorderCore

protocol AppInstalling {
    func install(from downloadURL: URL, replacing destinationApp: URL) async throws
}

protocol ZipDownloading {
    func download(from remote: URL, to local: URL) async throws
}

struct URLSessionReleaseFetcher: ReleaseFetching {
    var url: URL = AppProject.latestReleaseAPIURL
    var session: URLSession = .shared

    func fetchLatestReleaseData() async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("iRecorder", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw UpdateCheckerError.downloadFailed
        }
        return data
    }
}

struct URLSessionZipDownloader: ZipDownloading {
    var session: URLSession = .shared

    func download(from remote: URL, to local: URL) async throws {
        let (tempURL, response) = try await session.download(from: remote)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw UpdateCheckerError.downloadFailed
        }
        if FileManager.default.fileExists(atPath: local.path) {
            try FileManager.default.removeItem(at: local)
        }
        try FileManager.default.moveItem(at: tempURL, to: local)
    }
}

struct AppBundleInstaller: AppInstalling {
    var fileManager: FileManager = .default
    var downloader: any ZipDownloading = URLSessionZipDownloader()

    func install(from downloadURL: URL, replacing destinationApp: URL) async throws {
        let work = fileManager.temporaryDirectory
            .appendingPathComponent("iRecorder-update-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: work) }

        let zipPath = work.appendingPathComponent("download.zip")
        try await downloader.download(from: downloadURL, to: zipPath)

        let extractDir = work.appendingPathComponent("extract", isDirectory: true)
        try fileManager.createDirectory(at: extractDir, withIntermediateDirectories: true)
        try await unzipOffMainActor(zipPath, into: extractDir)

        guard let newApp = findAppBundle(in: extractDir) else {
            throw UpdateCheckerError.appBundleMissingInArchive
        }

        let parent = destinationApp.deletingLastPathComponent()
        let staging = parent.appendingPathComponent("iRecorder.app.updating")
        let backup = parent.appendingPathComponent("iRecorder.app.bak")

        if fileManager.fileExists(atPath: staging.path) {
            try fileManager.removeItem(at: staging)
        }
        if fileManager.fileExists(atPath: backup.path) {
            try fileManager.removeItem(at: backup)
        }

        try fileManager.copyItem(at: newApp, to: staging)

        let hadExisting = fileManager.fileExists(atPath: destinationApp.path)
        if hadExisting {
            try fileManager.moveItem(at: destinationApp, to: backup)
        }

        do {
            try fileManager.moveItem(at: staging, to: destinationApp)
        } catch {
            if hadExisting, fileManager.fileExists(atPath: backup.path) {
                try? fileManager.removeItem(at: destinationApp)
                try? fileManager.moveItem(at: backup, to: destinationApp)
            }
            try? fileManager.removeItem(at: staging)
            throw UpdateCheckerError.installFailed
        }

        if fileManager.fileExists(atPath: backup.path) {
            try? fileManager.removeItem(at: backup)
        }
    }

    private func unzipOffMainActor(_ zip: URL, into destination: URL) async throws {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-x", "-k", zip.path, destination.path]
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw UpdateCheckerError.downloadFailed
            }
        }.value
    }

    private func findAppBundle(in root: URL) -> URL? {
        let preferred = root.appendingPathComponent("iRecorder.app", isDirectory: true)
        if fileManager.fileExists(atPath: preferred.path) {
            return preferred
        }
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        for case let url as URL in enumerator where url.pathExtension == "app" {
            if url.lastPathComponent == "iRecorder.app" {
                return url
            }
        }
        // ponytail: only accept iRecorder.app — arbitrary .app in zip is too risky
        return nil
    }
}

enum AppUpdateCoordinator {
    static func localVersion(bundle: Bundle = .main) -> String {
        (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
    }

    static func makeChecker(bundle: Bundle = .main) -> UpdateChecker {
        UpdateChecker(
            localVersion: localVersion(bundle: bundle),
            fetcher: URLSessionReleaseFetcher()
        )
    }
}
