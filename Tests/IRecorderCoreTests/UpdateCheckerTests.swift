import Foundation
import Testing
@testable import IRecorderCore

@Test func versionCompareRemoteNewerMajor() {
    #expect(VersionCompare.isRemoteNewer(local: "1.0", remote: "2.0"))
}

@Test func versionCompareEqualNotNewer() {
    #expect(!VersionCompare.isRemoteNewer(local: "1.2.3", remote: "1.2.3"))
}

@Test func versionCompareStripsLeadingV() {
    #expect(VersionCompare.isRemoteNewer(local: "1.0.0", remote: "v1.1.0"))
    #expect(!VersionCompare.isRemoteNewer(local: "1.1.0", remote: "v1.1.0"))
}

@Test func versionComparePatchAndUnequalSegments() {
    #expect(VersionCompare.isRemoteNewer(local: "1.0.0", remote: "1.0.1"))
    #expect(!VersionCompare.isRemoteNewer(local: "1.0.1", remote: "1.0.0"))
    #expect(VersionCompare.isRemoteNewer(local: "1.0", remote: "1.0.1"))
    #expect(!VersionCompare.isRemoteNewer(local: "1.0.1", remote: "1.0"))
}

@Test func githubReleasePrefersIRecorderZip() throws {
    let json = """
    {
      "tag_name": "v1.2.0",
      "assets": [
        { "name": "README.md", "browser_download_url": "https://example.com/README.md" },
        { "name": "iRecorder.app.zip", "browser_download_url": "https://example.com/iRecorder.app.zip" }
      ]
    }
    """.data(using: .utf8)!
    let release = try GitHubRelease.decode(from: json)
    #expect(release.tagName == "v1.2.0")
    #expect(release.zipAssetDownloadURL?.absoluteString == "https://example.com/iRecorder.app.zip")
}

@Test func githubReleaseFallsBackToAnyZip() throws {
    let json = """
    {
      "tag_name": "v1.0.0",
      "assets": [
        { "name": "notes.txt", "browser_download_url": "https://example.com/notes.txt" },
        { "name": "build.ZIP", "browser_download_url": "https://example.com/build.ZIP" }
      ]
    }
    """.data(using: .utf8)!
    let release = try GitHubRelease.decode(from: json)
    #expect(release.zipAssetDownloadURL?.absoluteString == "https://example.com/build.ZIP")
}

@Test func githubReleaseZipNilWhenMissing() throws {
    let json = """
    {
      "tag_name": "v1.0.0",
      "assets": [
        { "name": "notes.txt", "browser_download_url": "https://example.com/notes.txt" }
      ]
    }
    """.data(using: .utf8)!
    let release = try GitHubRelease.decode(from: json)
    #expect(release.zipAssetDownloadURL == nil)
}

@Test func updateCheckerReportsUpToDate() async throws {
    let fetcher = MockReleaseFetcher(result: .success(makeReleaseJSON(tag: "v1.0.0", zipURL: "https://example.com/a.zip")))
    let checker = UpdateChecker(localVersion: "1.0.0", fetcher: fetcher)
    #expect(try await checker.check() == .upToDate(current: "1.0.0"))
}

@Test func updateCheckerReportsAvailable() async throws {
    let fetcher = MockReleaseFetcher(result: .success(makeReleaseJSON(tag: "v1.1.0", zipURL: "https://example.com/iRecorder.app.zip")))
    let checker = UpdateChecker(localVersion: "1.0.0", fetcher: fetcher)
    #expect(
        try await checker.check() == .updateAvailable(
            current: "1.0.0",
            latest: "1.1.0",
            downloadURL: URL(string: "https://example.com/iRecorder.app.zip")!
        )
    )
}

@Test func updateCheckerThrowsWhenZipMissing() async {
    let fetcher = MockReleaseFetcher(result: .success(makeReleaseJSON(tag: "v2.0.0", zipURL: nil)))
    let checker = UpdateChecker(localVersion: "1.0.0", fetcher: fetcher)
    await #expect(throws: UpdateCheckerError.zipAssetMissing) {
        _ = try await checker.check()
    }
}

@Test func appProjectURLsPointAtIRecorder() {
    #expect(AppProject.githubOwner == "wizizm")
    #expect(AppProject.githubRepo == "irecorder")
    #expect(AppProject.issuesURL.absoluteString == "https://github.com/wizizm/irecorder/issues")
    #expect(
        AppProject.latestReleaseAPIURL.absoluteString
            == "https://api.github.com/repos/wizizm/irecorder/releases/latest"
    )
}

private struct MockReleaseFetcher: ReleaseFetching {
    let result: Result<Data, Error>
    func fetchLatestReleaseData() async throws -> Data {
        try result.get()
    }
}

private func makeReleaseJSON(tag: String, zipURL: String?) -> Data {
    var assets = ""
    if let zipURL {
        assets = """
        { "name": "iRecorder.app.zip", "browser_download_url": "\(zipURL)" }
        """
    }
    let json = """
    { "tag_name": "\(tag)", "assets": [\(assets)] }
    """
    return Data(json.utf8)
}
