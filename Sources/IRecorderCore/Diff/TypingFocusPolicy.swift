import Foundation

/// Decides whether an AX focus sample should be diffed against the previous value
/// (emit typing) or treated as a new field baseline only.
public enum TypingFocusPolicy {
    public static func shouldCompareToPrevious(
        sameElement: Bool,
        previous: String,
        current: String
    ) -> Bool {
        if sameElement { return true }
        // First sample on a field: establish baseline, do not dump the whole existing value.
        if previous.isEmpty { return false }
        if current == previous { return true }
        if current.hasPrefix(previous) || previous.hasPrefix(current) { return true }

        let pre = Array(previous)
        let cur = Array(current)
        var shared = 0
        while shared < pre.count, shared < cur.count, pre[shared] == cur[shared] {
            shared += 1
        }
        let minCount = min(pre.count, cur.count)
        if shared >= 4 { return true }
        if minCount > 0, shared * 2 >= minCount { return true }
        return false
    }
}
