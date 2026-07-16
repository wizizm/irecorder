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

@Test func flushesHeldEnglishAfterPause() {
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
    #expect(buf.tick(at: t0.addingTimeInterval(0.5), fieldValue: "x type") == ["type"])
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

@Test func idleTickDropsHeldWhenGoneFromField() {
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
    #expect(buf.tick(at: t0.addingTimeInterval(0.5), fieldValue: "…智汇").isEmpty)
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

@Test func nilFieldKeepsLatinDropsApostropheComposition() {
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
        ) == ["type", "了"]
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
