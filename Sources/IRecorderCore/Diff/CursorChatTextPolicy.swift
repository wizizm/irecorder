import Foundation

/// Filters Cursor/Electron chat chrome vs real message text for post-send AX capture.
public enum CursorChatTextPolicy {
    private static let chromeExact: Set<String> = [
        "Fork chat",
        "Copy message",
        "Navigation actions",
        "Cursor Tab",
        "Apple",
        "Cursor",
        "File",
        "Edit",
        "Selection",
        "View",
        "Go",
        "Run",
        "Terminal",
        "Window",
        "Help",
    ]

    private static let chromePrefixes = [
        "Message sent ",
        "Workspace: ",
        "Sign in ",
        "account ",
        "git-commit ",
        "repo-forked ",
        "broadcast ",
        "tasklist ",
        "server ",
        "database ",
        "cloud ",
        "Formatting: ",
        "check-all ",
        "编辑器语言状态",
        "行 ",
        "警告:",
        "Git Graph",
    ]

    public static func isCaptureCandidate(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return false }
        // Chat bubbles are usually one short message; huge concatenations are chrome aggregates.
        guard trimmed.count <= 800 else { return false }
        if chromeExact.contains(trimmed) { return false }
        for prefix in chromePrefixes {
            if trimmed.hasPrefix(prefix) { return false }
        }
        // Status / toolbar / multi-widget noise.
        if trimmed.contains("Click to ") { return false }
        if trimmed.contains("Sign in to ") { return false }
        if trimmed.contains("Message sent ") { return false }
        if trimmed.contains("Fork chat") { return false }
        if trimmed.contains("Copy message") { return false }
        if trimmed.hasPrefix("x！") { return false }
        if trimmed.contains("\u{200B}") { return false }
        // VoiceOver / AX scraps often space every CJK token: "这样 改了 之后 其他"
        if looksLikeSpacedCJKNoise(trimmed) { return false }
        return true
    }

    /// True when spaces are dense relative to CJK (accessibility tree fragments, not a normal sentence).
    static func looksLikeSpacedCJKNoise(_ text: String) -> Bool {
        let cjk = text.unicodeScalars.filter { (0x4E00...0x9FFF).contains($0.value) }.count
        guard cjk >= 4 else { return false }
        // Double spaces are common in AX scraps, rare in normal chat sentences.
        if text.contains("  ") { return true }
        let tokens = text.split { $0 == " " || $0 == "\u{00A0}" }.filter { !$0.isEmpty }
        // Many short tokens: "这样 改了 之后 其他 地方 输入"
        if tokens.count >= 5 {
            let short = tokens.filter { $0.count <= 2 }.count
            if short * 2 >= tokens.count { return true }
        }
        return false
    }
}
