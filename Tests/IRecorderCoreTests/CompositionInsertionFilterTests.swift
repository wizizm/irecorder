import Testing
@testable import IRecorderCore

@Test func ignoresPinyinFragmentsWhenChineseIME() {
    #expect(CompositionInsertionFilter.shouldIgnore(insertion: "c", chineseIMEActive: true))
    #expect(CompositionInsertionFilter.shouldIgnore(insertion: "e", chineseIMEActive: true))
    #expect(CompositionInsertionFilter.shouldIgnore(insertion: "'sh", chineseIMEActive: true))
    #expect(CompositionInsertionFilter.shouldIgnore(insertion: "ji'l", chineseIMEActive: true))
    #expect(CompositionInsertionFilter.shouldIgnore(insertion: "u", chineseIMEActive: true))
}

@Test func keepsCommittedChineseWhenChineseIME() {
    #expect(CompositionInsertionFilter.shouldIgnore(insertion: "测试", chineseIMEActive: true) == false)
    #expect(CompositionInsertionFilter.shouldIgnore(insertion: "记录", chineseIMEActive: true) == false)
}

@Test func keepsLatinWhenNotChineseIME() {
    #expect(CompositionInsertionFilter.shouldIgnore(insertion: "hello", chineseIMEActive: false) == false)
    #expect(CompositionInsertionFilter.shouldIgnore(insertion: "c", chineseIMEActive: false) == false)
}

@Test func keepsMixedOrPunctuation() {
    #expect(CompositionInsertionFilter.shouldIgnore(insertion: "测s", chineseIMEActive: true) == false)
    #expect(CompositionInsertionFilter.shouldIgnore(insertion: "!", chineseIMEActive: true) == false)
    #expect(CompositionInsertionFilter.shouldIgnore(insertion: " ", chineseIMEActive: true) == false)
}
