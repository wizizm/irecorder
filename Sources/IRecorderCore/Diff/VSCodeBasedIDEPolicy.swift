import Foundation

/// VS Code–based / Electron IDEs that need Cursor-like capture (unreliable AX textarea + chat bubbles).
public enum VSCodeBasedIDEPolicy {
    private static let nameHints: Set<String> = [
        "Cursor", "Code", "Code - Insiders", "VSCodium", "Windsurf", "Trae", "Antigravity",
    ]

    private static let bundleHints = [
        "cursor",
        "vscode",
        "vscodium",
        "windsurf",
        "exafunction",
        "trae",
    ]

    public static func matches(appName: String, bundleID: String?) -> Bool {
        if nameHints.contains(appName) { return true }
        let bid = (bundleID ?? "").lowercased()
        return bundleHints.contains { bid.contains($0) }
    }
}
