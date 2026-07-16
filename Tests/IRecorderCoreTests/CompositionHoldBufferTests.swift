import Foundation
import Testing
@testable import IRecorderCore

@Test func keepsEnglishThatRemainsInFieldBeforeCJK() {
    // Real: 你是不是type了… — "type" stays in the field when 了 commits.
    let buf = CompositionHoldBuffer(holdInterval: 0.5)
    let t0 = Date()
    #expect(
        buf.ingest(
            insertion: "type",
            chineseIMEActive: true,
            fieldValue: "你是不是type",
            at: t0
        ).isEmpty
    )
    #expect(
        buf.ingest(
            insertion: "了",
            chineseIMEActive: true,
            fieldValue: "你是不是type了",
            at: t0.addingTimeInterval(0.1)
        ) == ["type", "了"]
    )
}

@Test func dropsPinyinReplacedByCJKInField() {
    // Real: …了zhege智汇… — "zhege" is gone after 智 commits.
    let buf = CompositionHoldBuffer(holdInterval: 0.5)
    let t0 = Date()
    #expect(
        buf.ingest(
            insertion: "zhege",
            chineseIMEActive: true,
            fieldValue: "你是不是type了zhege",
            at: t0
        ).isEmpty
    )
    #expect(
        buf.ingest(
            insertion: "智",
            chineseIMEActive: true,
            fieldValue: "你是不是type了智汇就不行了",
            at: t0.addingTimeInterval(0.1)
        ) == ["智"]
    )
}

@Test func fullPhraseTypeKeptZhegeDropped() {
    let buf = CompositionHoldBuffer(holdInterval: 0.5)
    let t0 = Date()
    var out: [String] = []
    out += buf.ingest(
        insertion: "你是不是",
        chineseIMEActive: true,
        fieldValue: "你是不是",
        at: t0
    )
    out += buf.ingest(
        insertion: "type",
        chineseIMEActive: true,
        fieldValue: "你是不是type",
        at: t0.addingTimeInterval(0.05)
    )
    out += buf.ingest(
        insertion: "了",
        chineseIMEActive: true,
        fieldValue: "你是不是type了",
        at: t0.addingTimeInterval(0.1)
    )
    out += buf.ingest(
        insertion: "zhege",
        chineseIMEActive: true,
        fieldValue: "你是不是type了zhege",
        at: t0.addingTimeInterval(0.15)
    )
    out += buf.ingest(
        insertion: "智汇就不行了",
        chineseIMEActive: true,
        fieldValue: "你是不是type了智汇就不行了",
        at: t0.addingTimeInterval(0.2)
    )
    #expect(out.joined() == "你是不是type了智汇就不行了")
}

@Test func passesLatinWhenIMEInactive() {
    let buf = CompositionHoldBuffer(holdInterval: 0.5)
    #expect(
        buf.ingest(
            insertion: "type",
            chineseIMEActive: false,
            fieldValue: "type"
        ) == ["type"]
    )
}

@Test func flushesHeldEnglishAfterPauseOnlyWhenIMEInactive() {
    // Under Chinese IME, idle must not emit — unfinished pinyin is still in the field
    // (Finder bug: tai / zheyang / te leaked before CJK replaced them).
    let buf = CompositionHoldBuffer(holdInterval: 0.4)
    let t0 = Date()
    #expect(
        buf.ingest(
            insertion: "type",
            chineseIMEActive: true,
            fieldValue: "x type",
            at: t0
        ).isEmpty
    )
    #expect(
        buf.tick(
            at: t0.addingTimeInterval(0.5),
            fieldValue: "x type",
            chineseIMEActive: true
        ).isEmpty
    )
    // After switching to ABC (or any non-Chinese IME), idle may flush remaining English.
    #expect(
        buf.tick(
            at: t0.addingTimeInterval(0.5),
            fieldValue: "x type",
            chineseIMEActive: false
        ) == ["type"]
    )
}

@Test func finderPhraseDropsPlainPinyinEmittedOnlyOnCJK() {
    // Real bug log: 你zheyang样让我te得好累 / tai太t累人te了啊
    // Idle used to emit zheyang/te while still composing; then CJK also logged.
    // AX insert is the replaced span (zheyang→这样), not a single leftover CJK char.
    let buf = CompositionHoldBuffer(holdInterval: 0.4)
    let t0 = Date()
    var out: [String] = []
    out += buf.ingest(
        insertion: "你",
        chineseIMEActive: true,
        fieldValue: "你",
        at: t0
    )
    out += buf.ingest(
        insertion: "zheyang",
        chineseIMEActive: true,
        fieldValue: "你zheyang",
        at: t0.addingTimeInterval(0.05)
    )
    #expect(
        buf.tick(
            at: t0.addingTimeInterval(0.5),
            fieldValue: "你zheyang",
            chineseIMEActive: true
        ).isEmpty
    )
    out += buf.ingest(
        insertion: "这样",
        chineseIMEActive: true,
        fieldValue: "你这样",
        at: t0.addingTimeInterval(0.55)
    )
    out += buf.ingest(
        insertion: "让我",
        chineseIMEActive: true,
        fieldValue: "你这样让我",
        at: t0.addingTimeInterval(0.6)
    )
    out += buf.ingest(
        insertion: "te",
        chineseIMEActive: true,
        fieldValue: "你这样让我te",
        at: t0.addingTimeInterval(0.65)
    )
    #expect(
        buf.tick(
            at: t0.addingTimeInterval(1.1),
            fieldValue: "你这样让我te",
            chineseIMEActive: true
        ).isEmpty
    )
    out += buf.ingest(
        insertion: "特得好累",
        chineseIMEActive: true,
        fieldValue: "你这样让我特得好累",
        at: t0.addingTimeInterval(1.15)
    )
    #expect(out.joined() == "你这样让我特得好累")
}

@Test func stripsVanishedPinyinWhenCJKArrivesInSameInsert() {
    let buf = CompositionHoldBuffer(holdInterval: 0.5)
    #expect(
        buf.ingest(
            insertion: "zhege智汇",
            chineseIMEActive: true,
            fieldValue: "你是不是type了智汇"
        ) == ["智汇"]
    )
}

@Test func idleTickDropsHeldWhenGoneFromFieldOnlyIfIMEInactive() {
    let buf = CompositionHoldBuffer(holdInterval: 0.4)
    let t0 = Date()
    #expect(
        buf.ingest(
            insertion: "zhege",
            chineseIMEActive: true,
            fieldValue: "…zhege",
            at: t0
        ).isEmpty
    )
    // Still Chinese IME: idle must not resolve (even if field already changed).
    #expect(
        buf.tick(
            at: t0.addingTimeInterval(0.5),
            fieldValue: "…智汇",
            chineseIMEActive: true
        ).isEmpty
    )
    // IME off + idle: resolve and drop because gone from field.
    #expect(
        buf.tick(
            at: t0.addingTimeInterval(0.5),
            fieldValue: "…智汇",
            chineseIMEActive: false
        ).isEmpty
    )
}

@Test func keepsEnglishPrefixWhenPinyinSuffixAppendedThenCJK() {
    // Real bug: held became "haishibuxing"; whole string missing from field → dropped "haishi" too.
    let buf = CompositionHoldBuffer(holdInterval: 0.5)
    let t0 = Date()
    #expect(
        buf.ingest(
            insertion: "haishi",
            chineseIMEActive: true,
            fieldValue: "好像haishi",
            at: t0
        ).isEmpty
    )
    #expect(
        buf.ingest(
            insertion: "buxing",
            chineseIMEActive: true,
            fieldValue: "好像haishibuxing",
            at: t0.addingTimeInterval(0.05)
        ).isEmpty
    )
    #expect(
        buf.ingest(
            insertion: "不行",
            chineseIMEActive: true,
            fieldValue: "好像haishi不行",
            at: t0.addingTimeInterval(0.1)
        ) == ["haishi", "不行"]
    )
}

@Test func phraseHaishiAndTypeKept() {
    // Real: 好像haishi不行type啊 → must keep both English words.
    let buf = CompositionHoldBuffer(holdInterval: 0.5)
    let t0 = Date()
    var out: [String] = []
    out += buf.ingest(
        insertion: "好像",
        chineseIMEActive: true,
        fieldValue: "好像",
        at: t0
    )
    out += buf.ingest(
        insertion: "haishi",
        chineseIMEActive: true,
        fieldValue: "好像haishi",
        at: t0.addingTimeInterval(0.05)
    )
    out += buf.ingest(
        insertion: "buxing",
        chineseIMEActive: true,
        fieldValue: "好像haishibuxing",
        at: t0.addingTimeInterval(0.1)
    )
    out += buf.ingest(
        insertion: "不行",
        chineseIMEActive: true,
        fieldValue: "好像haishi不行",
        at: t0.addingTimeInterval(0.15)
    )
    out += buf.ingest(
        insertion: "type",
        chineseIMEActive: true,
        fieldValue: "好像haishi不行type",
        at: t0.addingTimeInterval(0.2)
    )
    out += buf.ingest(
        insertion: "啊",
        chineseIMEActive: true,
        fieldValue: "好像haishi不行type啊",
        at: t0.addingTimeInterval(0.25)
    )
    #expect(out.joined() == "好像haishi不行type啊")
}

@Test func nilFieldDropsLatinKeepsCJK() {
    // Key-fallback has no AX field: under Chinese IME, held Latin is pinyin noise — drop it.
    let buf = CompositionHoldBuffer(holdInterval: 0.5)
    let t0 = Date()
    #expect(
        buf.ingest(insertion: "type", chineseIMEActive: true, fieldValue: nil, at: t0).isEmpty
    )
    #expect(
        buf.ingest(
            insertion: "了",
            chineseIMEActive: true,
            fieldValue: nil,
            at: t0.addingTimeInterval(0.1)
        ) == ["了"]
    )

    let buf2 = CompositionHoldBuffer(holdInterval: 0.5)
    #expect(
        buf2.ingest(insertion: "zhi'shi", chineseIMEActive: true, fieldValue: nil, at: t0).isEmpty
    )
    #expect(
        buf2.ingest(
            insertion: "知识",
            chineseIMEActive: true,
            fieldValue: nil,
            at: t0.addingTimeInterval(0.1)
        ) == ["知识"]
    )
}

@Test func finderMixedKeepsTestAndZhongDropsPinyinH() {
    // Real: 继续test我的zhong英文混合吧
    // Bug log: 继续te我的zhong英文h混合吧
    // Root: field.contains("h") / contains("te") matched inside "zhong" / failed to promote "te"→"test".
    let buf = CompositionHoldBuffer(holdInterval: 0.5)
    let t0 = Date()
    var out: [String] = []
    out += buf.ingest(
        insertion: "继续",
        chineseIMEActive: true,
        fieldValue: "继续",
        at: t0
    )
    // AX missed "st" inserts; held only "te" while field already has full token "test".
    out += buf.ingest(
        insertion: "te",
        chineseIMEActive: true,
        fieldValue: "继续te",
        at: t0.addingTimeInterval(0.05)
    )
    out += buf.ingest(
        insertion: "我的",
        chineseIMEActive: true,
        fieldValue: "继续test我的",
        at: t0.addingTimeInterval(0.1)
    )
    out += buf.ingest(
        insertion: "zhong",
        chineseIMEActive: true,
        fieldValue: "继续test我的zhong",
        at: t0.addingTimeInterval(0.15)
    )
    out += buf.ingest(
        insertion: "英文",
        chineseIMEActive: true,
        fieldValue: "继续test我的zhong英文",
        at: t0.addingTimeInterval(0.2)
    )
    // Pinyin scrap "h" for 混 must not match the "h" inside token "zhong".
    out += buf.ingest(
        insertion: "h",
        chineseIMEActive: true,
        fieldValue: "继续test我的zhong英文h",
        at: t0.addingTimeInterval(0.25)
    )
    out += buf.ingest(
        insertion: "混合吧",
        chineseIMEActive: true,
        fieldValue: "继续test我的zhong英文混合吧",
        at: t0.addingTimeInterval(0.3)
    )
    #expect(out.joined() == "继续test我的zhong英文混合吧")
}

@Test func stripLeadingLatinIgnoresMatchInsideOtherToken() {
    // "h" is inside "zhong" — must not keep leading pinyin scrap.
    let cleaned = CompositionHoldBuffer.stripVanishedLeadingLatin(
        "h混合吧",
        fieldValue: "继续test我的zhong英文h混合吧"
    )
    #expect(cleaned == "混合吧")
}

@Test func promotePartialHeldToFullFieldToken() {
    let buf = CompositionHoldBuffer(holdInterval: 0.5)
    let t0 = Date()
    #expect(
        buf.ingest(
            insertion: "te",
            chineseIMEActive: true,
            fieldValue: "继续te",
            at: t0
        ).isEmpty
    )
    #expect(
        buf.ingest(
            insertion: "我的",
            chineseIMEActive: true,
            fieldValue: "继续test我的",
            at: t0.addingTimeInterval(0.1)
        ) == ["test", "我的"]
    )
}
