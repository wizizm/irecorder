import Testing
@testable import IRecorderCore

@Test func keyFallbackDropsLatinUnderChineseIME() {
    #expect(KeyInsertionPolicy.shouldAcceptForKeyFallback(
        insertion: "zhonwen",
        chineseIMEActive: true,
        vscodeBasedIDE: false
    ) == false)
    #expect(KeyInsertionPolicy.shouldAcceptForKeyFallback(
        insertion: "type",
        chineseIMEActive: true,
        vscodeBasedIDE: false
    ) == false)
    #expect(KeyInsertionPolicy.shouldAcceptForKeyFallback(
        insertion: "测",
        chineseIMEActive: true,
        vscodeBasedIDE: false
    ))
    #expect(KeyInsertionPolicy.shouldAcceptForKeyFallback(
        insertion: "，",
        chineseIMEActive: true,
        vscodeBasedIDE: false
    ))
}

@Test func keyFallbackKeepsLatinWhenIMEInactive() {
    #expect(KeyInsertionPolicy.shouldAcceptForKeyFallback(
        insertion: "type",
        chineseIMEActive: false,
        vscodeBasedIDE: false
    ))
    #expect(KeyInsertionPolicy.shouldAcceptForKeyFallback(
        insertion: "type",
        chineseIMEActive: false,
        vscodeBasedIDE: true
    ))
}

@Test func vscodeChineseIMEIgnoresAllKeyInsertions() {
    // Cursor branch: Chinese goes through post-send bubble only — keys would fight the probe.
    #expect(KeyInsertionPolicy.shouldAcceptForKeyFallback(
        insertion: "测",
        chineseIMEActive: true,
        vscodeBasedIDE: true
    ) == false)
    #expect(KeyInsertionPolicy.shouldAcceptForKeyFallback(
        insertion: "a",
        chineseIMEActive: true,
        vscodeBasedIDE: true
    ) == false)
}

@Test func detectsPlainReturnForChatSend() {
    #expect(KeyInsertionPolicy.isPlainReturn(
        keyCode: 36, command: false, option: false, control: false, shift: false
    ))
    #expect(KeyInsertionPolicy.isPlainReturn(
        keyCode: 76, command: false, option: false, control: false, shift: false
    ))
    #expect(KeyInsertionPolicy.isPlainReturn(
        keyCode: 36, command: true, option: false, control: false, shift: false
    ) == false)
}
