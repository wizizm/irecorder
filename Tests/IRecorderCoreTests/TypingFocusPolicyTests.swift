import Testing
@testable import IRecorderCore

@Test func sameElementAlwaysCompares() {
    #expect(TypingFocusPolicy.shouldCompareToPrevious(
        sameElement: true,
        previous: "ab",
        current: "abc"
    ))
}

@Test func newFocusWithEmptyPreviousIsBaselineOnly() {
    #expect(!TypingFocusPolicy.shouldCompareToPrevious(
        sameElement: false,
        previous: "",
        current: "hello"
    ))
}

@Test func elementIdentityFlapStillComparesWhenTextContinues() {
    #expect(TypingFocusPolicy.shouldCompareToPrevious(
        sameElement: false,
        previous: "你好",
        current: "你好世界"
    ))
    #expect(TypingFocusPolicy.shouldCompareToPrevious(
        sameElement: false,
        previous: "hello world",
        current: "hello"
    ))
}

@Test func unrelatedNewFieldDoesNotCompare() {
    #expect(!TypingFocusPolicy.shouldCompareToPrevious(
        sameElement: false,
        previous: "完全不同的一段",
        current: "another field"
    ))
}
