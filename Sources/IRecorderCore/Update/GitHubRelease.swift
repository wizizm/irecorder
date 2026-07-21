import Foundation

public struct GitHubRelease: Equatable, Sendable {
    public let tagName: String
    public let assets: [Asset]

    public struct Asset: Equatable, Sendable {
        public let name: String
        public let browserDownloadURL: URL
    }

    public var zipAssetDownloadURL: URL? {
        if let preferred = assets.first(where: { $0.name == "iRecorder.app.zip" }) {
            return preferred.browserDownloadURL
        }
        return assets.first { $0.name.lowercased().hasSuffix(".zip") }?.browserDownloadURL
    }

    public static func decode(from data: Data) throws -> GitHubRelease {
        try JSONDecoder().decode(Payload.self, from: data).asRelease
    }

    private struct Payload: Decodable {
        let tagName: String
        let assets: [AssetPayload]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case assets
        }

        var asRelease: GitHubRelease {
            GitHubRelease(
                tagName: tagName,
                assets: assets.compactMap { asset in
                    guard let url = URL(string: asset.browserDownloadURL) else { return nil }
                    return Asset(name: asset.name, browserDownloadURL: url)
                }
            )
        }
    }

    private struct AssetPayload: Decodable {
        let name: String
        let browserDownloadURL: String

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }
}
