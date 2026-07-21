import Foundation

public enum AppProject {
    public static let githubOwner = "wizizm"
    public static let githubRepo = "irecorder"

    public static var issuesURL: URL {
        URL(string: "https://github.com/\(githubOwner)/\(githubRepo)/issues")!
    }

    public static var latestReleaseAPIURL: URL {
        URL(string: "https://api.github.com/repos/\(githubOwner)/\(githubRepo)/releases/latest")!
    }
}
