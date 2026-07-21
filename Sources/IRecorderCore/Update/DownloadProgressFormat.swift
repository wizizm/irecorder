import Foundation

public enum DownloadProgressFormat {
    public enum Language: Sendable {
        case chinese
        case english
    }

    public static func fraction(written: Int64, total: Int64?) -> Double? {
        guard let total, total > 0 else { return nil }
        return min(1, max(0, Double(written) / Double(total)))
    }

    public static func message(
        prefix: String,
        written: Int64,
        total: Int64?,
        language: Language
    ) -> String {
        _ = language
        let writtenText = byteString(written)
        if let total, total > 0 {
            let totalText = byteString(total)
            let percent = Int((fraction(written: written, total: total) ?? 0) * 100)
            return "\(prefix) \(writtenText) / \(totalText) (\(percent)%)"
        }
        return "\(prefix) \(writtenText)"
    }

    /// Compact IEC-ish sizes so UI stays short (MB preferred for update zips).
    private static func byteString(_ bytes: Int64) -> String {
        if bytes >= 1_048_576 {
            return String(format: "%.1f MB", Double(bytes) / 1_048_576)
        }
        if bytes >= 1024 {
            return String(format: "%.0f KB", Double(bytes) / 1024)
        }
        return "\(bytes) B"
    }
}
