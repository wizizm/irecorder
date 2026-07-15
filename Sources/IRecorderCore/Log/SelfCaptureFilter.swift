import Foundation

/// Drops self-feedback: re-logging our own log lines (esp. Console watching the file)
/// which causes runaway `\` escaping and multi-MB log blowups.
public enum SelfCaptureFilter {
    public static func shouldIgnore(payload: String, appName: String) -> Bool {
        if appName == "iRecorder" { return true }
        return looksLikeOwnLogPayload(payload)
    }

    private static func looksLikeOwnLogPayload(_ payload: String) -> Bool {
        // Escaped feedback: \\ttype\\t or denser \\\\ piles from recursive re-logging
        if payload.contains("\\ttype\\t")
            || payload.contains("\\tcopy\\t")
            || payload.contains("\\tpaste\\t")
            || payload.contains("\\\\ttype")
            || payload.contains("\\\\tcopy")
            || payload.contains("\\\\tpaste") {
            return true
        }

        // Raw multi-line clipboard / AX value that is our log content itself
        guard payload.range(
            of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}"#,
            options: .regularExpression
        ) != nil else {
            return false
        }
        return payload.contains("\ttype\t")
            || payload.contains("\tcopy\t")
            || payload.contains("\tpaste\t")
    }
}
