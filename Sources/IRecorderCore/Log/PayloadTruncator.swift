public enum PayloadTruncator {
    public static let defaultMaxBytes = 100_000

    public static func truncate(_ s: String, maxBytes: Int = defaultMaxBytes) -> String {
        guard s.utf8.count > maxBytes else { return s }
        var result = ""
        result.reserveCapacity(maxBytes)
        for ch in s {
            let next = result + String(ch)
            if next.utf8.count > maxBytes { break }
            result = next
        }
        return result + " [truncated]"
    }
}
