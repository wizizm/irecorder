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
}
