public enum TextInsertionDiff {
    /// Returns newly inserted text between `previous` and `current`, or nil if none.
    public static func insertedText(previous: String, current: String) -> String? {
        if previous == current { return nil }
        let p = Array(previous)
        let c = Array(current)
        var i = 0
        while i < p.count && i < c.count && p[i] == c[i] {
            i += 1
        }
        var j = 0
        while j < (p.count - i) && j < (c.count - i) && p[p.count - 1 - j] == c[c.count - 1 - j] {
            j += 1
        }
        let inserted = String(c[i..<(c.count - j)])
        if inserted.isEmpty { return nil }
        return inserted
    }
}
