import Testing
import IRecorderCore

@Suite("PasteHistorySearchControl")
struct PasteHistorySearchControlTests {
    @Test func clearBumpsGenerationSoStaleSearchIsIgnored() {
        let active = 3
        let cancelled = PasteHistorySearchControl.nextGeneration(after: active)
        #expect(cancelled == 4)
        #expect(!PasteHistorySearchControl.shouldApply(completed: active, current: cancelled))
        #expect(PasteHistorySearchControl.shouldApply(completed: cancelled, current: cancelled))
    }

    @Test func keyboardConfirmBlockedWhileSearching() {
        #expect(!PasteHistorySearchControl.allowsListInteraction(isSearching: true))
        #expect(PasteHistorySearchControl.allowsListInteraction(isSearching: false))
    }

    @Test func activeItemsEmptyWhileSearching() {
        let today = ["a"]
        let search = ["old"]
        #expect(
            PasteHistorySearchControl.activeItems(
                isSearching: true,
                isShowingSearchResults: true,
                today: today,
                search: search
            ).isEmpty
        )
        #expect(
            PasteHistorySearchControl.activeItems(
                isSearching: false,
                isShowingSearchResults: true,
                today: today,
                search: search
            ) == search
        )
        #expect(
            PasteHistorySearchControl.activeItems(
                isSearching: false,
                isShowingSearchResults: false,
                today: today,
                search: search
            ) == today
        )
    }
}
