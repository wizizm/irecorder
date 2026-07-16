import Testing
@testable import IRecorderCore

@Test func ignoresLatinOnlyWhenChineseIME() {
    // v1.0.0 behavior: under Chinese IME, skip pure Latin (pinyin noise and Latin keys).
    #expect(CompositionInsertionFilter.shouldIgnore(insertion: "c", chineseIMEActive: true))
    #expect(CompositionInsertionFilter.shouldIgnore(insertion: "ce'shi", chineseIMEActive: true))
    #expect(CompositionInsertionFilter.shouldIgnore(insertion: "turan", chineseIMEActive: true))
    #expect(CompositionInsertionFilter.shouldIgnore(insertion: "test", chineseIMEActive: true))
    #expect(CompositionInsertionFilter.shouldIgnore(insertion: "aaa", chineseIMEActive: true))
}

@Test func keepsCJKAndMixedWhenChineseIME() {
    #expect(CompositionInsertionFilter.shouldIgnore(insertion: "测试", chineseIMEActive: true) == false)
    #expect(CompositionInsertionFilter.shouldIgnore(insertion: "测试abc", chineseIMEActive: true) == false)
    #expect(CompositionInsertionFilter.shouldIgnore(insertion: "你是不是turan降智了test啊", chineseIMEActive: true) == false)
}

@Test func keepsLatinWhenNotChineseIME() {
    #expect(CompositionInsertionFilter.shouldIgnore(insertion: "turan", chineseIMEActive: false) == false)
    #expect(CompositionInsertionFilter.shouldIgnore(insertion: "test", chineseIMEActive: false) == false)
    #expect(CompositionInsertionFilter.shouldIgnore(insertion: "c", chineseIMEActive: false) == false)
}

@Test func keepsPunctuationAndSpaceWhenChineseIME() {
    #expect(CompositionInsertionFilter.shouldIgnore(insertion: "!", chineseIMEActive: true) == false)
    #expect(CompositionInsertionFilter.shouldIgnore(insertion: " ", chineseIMEActive: true) == false)
    #expect(CompositionInsertionFilter.shouldIgnore(insertion: "？", chineseIMEActive: true) == false)
}
