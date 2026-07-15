import Testing
@testable import IRecorderCore

@Test func appendAtEnd() {
    #expect(TextInsertionDiff.insertedText(previous: "你", current: "你好") == "好")
}

@Test func insertInMiddle() {
    #expect(TextInsertionDiff.insertedText(previous: "你好世界", current: "你好，世界") == "，")
}

@Test func deleteOnlyReturnsNil() {
    #expect(TextInsertionDiff.insertedText(previous: "你好", current: "你") == nil)
}

@Test func identicalReturnsNil() {
    #expect(TextInsertionDiff.insertedText(previous: "a", current: "a") == nil)
}

@Test func emptyToText() {
    #expect(TextInsertionDiff.insertedText(previous: "", current: "你好世界") == "你好世界")
}
