import Foundation

/// Keyboard navigation helpers for zero-based list selection (↑/↓).
public enum ListKeyboardSelection {
    public static func moveDown(from current: Int?, count: Int) -> Int? {
        guard count > 0 else { return nil }
        guard let current else { return 0 }
        return min(current + 1, count - 1)
    }

    public static func moveUp(from current: Int?, count: Int) -> Int? {
        guard count > 0 else { return nil }
        guard let current else { return count - 1 }
        return max(current - 1, 0)
    }

    /// Cycle segmented-control index (← / →). Wraps at ends.
    public static func moveTab(from current: Int, count: Int, forward: Bool) -> Int {
        guard count > 0 else { return current }
        let clamped = min(max(current, 0), count - 1)
        if forward {
            return (clamped + 1) % count
        }
        return (clamped - 1 + count) % count
    }
}
