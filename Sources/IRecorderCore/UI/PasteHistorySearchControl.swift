import Foundation

/// Pure helpers for paste-history panel search session (generation + list mode).
public enum PasteHistorySearchControl {
    public static func nextGeneration(after current: Int) -> Int {
        current &+ 1
    }

    public static func shouldApply(completed: Int, current: Int) -> Bool {
        completed == current
    }

    public static func allowsListInteraction(isSearching: Bool) -> Bool {
        !isSearching
    }

    public static func activeItems<T>(
        isSearching: Bool,
        isShowingSearchResults: Bool,
        today: [T],
        search: [T]
    ) -> [T] {
        if isSearching { return [] }
        return isShowingSearchResults ? search : today
    }
}
