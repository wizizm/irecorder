import Foundation
import Testing
@testable import IRecorderCore

@Test func marksMonacoNewlineOnlyTextAreaAsUnreliableOnlyForVSCodeBased() {
    #expect(ElectronEditorAXPolicy.isUnreliableEditorValue(
        role: "AXTextArea", value: "\n", vscodeBasedIDE: true
    ))
    #expect(ElectronEditorAXPolicy.isUnreliableEditorValue(
        role: "AXTextArea", value: "", vscodeBasedIDE: true
    ))
    #expect(ElectronEditorAXPolicy.isUnreliableEditorValue(
        role: "AXTextArea", value: nil, vscodeBasedIDE: true
    ))
    #expect(ElectronEditorAXPolicy.isUnreliableEditorValue(
        role: "AXTextArea", value: "a", vscodeBasedIDE: true
    ))
}

@Test func neverMarksNativeFinderFieldsUnreliableEvenWhenShort() {
    // Real Finder rename: first CJK char must still use AX + field-presence hold, not key-fallback.
    #expect(ElectronEditorAXPolicy.isUnreliableEditorValue(
        role: "AXTextField", value: "那", vscodeBasedIDE: false
    ) == false)
    #expect(ElectronEditorAXPolicy.isUnreliableEditorValue(
        role: "AXTextField", value: "\n", vscodeBasedIDE: false
    ) == false)
    #expect(ElectronEditorAXPolicy.isUnreliableEditorValue(
        role: "AXTextArea", value: "那qita地方是否还type正常呢", vscodeBasedIDE: false
    ) == false)
}

@Test func marksZWSPCompositionAsUnreliableForVSCodeBased() {
    #expect(ElectronEditorAXPolicy.isUnreliableEditorValue(
        role: "AXTextArea",
        value: "d\u{200B}但是wo\u{200B}我",
        vscodeBasedIDE: true
    ))
}

@Test func keepsNormalNativeFieldsReliable() {
    #expect(ElectronEditorAXPolicy.isUnreliableEditorValue(
        role: "AXTextField",
        value: "你好世界",
        vscodeBasedIDE: false
    ) == false)
    #expect(ElectronEditorAXPolicy.isUnreliableEditorValue(
        role: "AXTextArea",
        value: "一篇完整的已上屏正文内容",
        vscodeBasedIDE: true
    ) == false)
}

@Test func recognizesVSCodeBasedIDENames() {
    #expect(VSCodeBasedIDEPolicy.matches(appName: "Cursor", bundleID: "com.todesktop.230313mzl4w4u92"))
    #expect(VSCodeBasedIDEPolicy.matches(appName: "Code", bundleID: "com.microsoft.VSCode"))
    #expect(VSCodeBasedIDEPolicy.matches(appName: "Windsurf", bundleID: "com.exafunction.windsurf"))
    #expect(VSCodeBasedIDEPolicy.matches(appName: "访达", bundleID: "com.apple.finder") == false)
}

@Test func stripsZWSPAndDropsLatinUnderChineseIME() {
    #expect(KeyInsertionPolicy.sanitizeKeyInsertion("d\u{200B}wo") == "dwo")
    #expect(KeyInsertionPolicy.shouldAcceptForKeyFallback(
        insertion: "d\u{200B}wo",
        chineseIMEActive: true
    ) == false)
    #expect(KeyInsertionPolicy.shouldAcceptForKeyFallback(
        insertion: "但",
        chineseIMEActive: true
    ))
}

@Test func finderMixedEnglishChineseKeptViaFieldPresence() {
    // Real: 那qita地方是否还type正常呢
    let buf = CompositionHoldBuffer(holdInterval: 0.5)
    let t0 = Date()
    var out: [String] = []
    out += buf.ingest(insertion: "那", chineseIMEActive: true, fieldValue: "那", at: t0)
    out += buf.ingest(
        insertion: "qita",
        chineseIMEActive: true,
        fieldValue: "那qita",
        at: t0.addingTimeInterval(0.05)
    )
    out += buf.ingest(
        insertion: "地方是否还",
        chineseIMEActive: true,
        fieldValue: "那qita地方是否还",
        at: t0.addingTimeInterval(0.1)
    )
    out += buf.ingest(
        insertion: "type",
        chineseIMEActive: true,
        fieldValue: "那qita地方是否还type",
        at: t0.addingTimeInterval(0.15)
    )
    out += buf.ingest(
        insertion: "正常呢",
        chineseIMEActive: true,
        fieldValue: "那qita地方是否还type正常呢",
        at: t0.addingTimeInterval(0.2)
    )
    #expect(out.joined() == "那qita地方是否还type正常呢")
}

@Test func finderPhraseDropsApostrophePinyinKeepsEnglish() {
    // Real: 我再试试finder行不xing啊
    // Bug log: 我zai'shi'si再试试finderxing'bu行不xing啊
    let buf = CompositionHoldBuffer(holdInterval: 0.5)
    let t0 = Date()
    var out: [String] = []
    out += buf.ingest(
        insertion: "我",
        chineseIMEActive: true,
        fieldValue: "我",
        at: t0
    )
    out += buf.ingest(
        insertion: "zai'shi'si",
        chineseIMEActive: true,
        fieldValue: "我zai'shi'si",
        at: t0.addingTimeInterval(0.05)
    )
    // Idle must NOT emit apostrophe pinyin even while still visible in the field.
    #expect(
        buf.tick(
            at: t0.addingTimeInterval(0.6),
            fieldValue: "我zai'shi'si",
            chineseIMEActive: true
        ).isEmpty
    )
    out += buf.ingest(
        insertion: "再试试",
        chineseIMEActive: true,
        fieldValue: "我再试试",
        at: t0.addingTimeInterval(0.7)
    )
    out += buf.ingest(
        insertion: "finder",
        chineseIMEActive: true,
        fieldValue: "我再试试finder",
        at: t0.addingTimeInterval(0.75)
    )
    out += buf.ingest(
        insertion: "xing'bu",
        chineseIMEActive: true,
        fieldValue: "我再试试finderxing'bu",
        at: t0.addingTimeInterval(0.8)
    )
    out += buf.ingest(
        insertion: "行不",
        chineseIMEActive: true,
        fieldValue: "我再试试finder行不",
        at: t0.addingTimeInterval(0.85)
    )
    out += buf.ingest(
        insertion: "xing",
        chineseIMEActive: true,
        fieldValue: "我再试试finder行不xing",
        at: t0.addingTimeInterval(0.9)
    )
    out += buf.ingest(
        insertion: "啊",
        chineseIMEActive: true,
        fieldValue: "我再试试finder行不xing啊",
        at: t0.addingTimeInterval(0.95)
    )
    #expect(out.joined() == "我再试试finder行不xing啊")
}

@Test func stripsApostrophePinyinEvenWhenStillVisibleInMixedInsert() {
    let cleaned = CompositionHoldBuffer.stripVanishedLeadingLatin(
        "xing'bu行不",
        fieldValue: "我再试试finderxing'bu行不"
    )
    #expect(cleaned == "行不")
}

