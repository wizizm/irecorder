import Testing
@testable import IRecorderCore

@Test func hotKeyDefaultIsCommandShiftLEnabled() {
    let key = HotKeySpec.defaultOpenTodayLog
    #expect(key.isEnabled)
    #expect(key.keyCode == 37) // L
    #expect(key.command && key.shift && !key.option && !key.control)
    #expect(key.displayString == "⇧⌘L")
}

@Test func pasteHistoryHotKeyDefaultIsDisabled() {
    #expect(HotKeySpec.defaultPasteHistory.isEnabled == false)
}

@Test func defaultPasteHistorySharesChordWithOpenToday() {
    #expect(HotKeySpec.defaultPasteHistory.sharesChord(with: .defaultOpenTodayLog))
}

@Test func sharesChordIgnoresEnabledFlag() {
    let a = HotKeySpec(keyCode: 9, command: true, shift: false, option: false, control: false, isEnabled: true)
    let b = HotKeySpec(keyCode: 9, command: true, shift: false, option: false, control: false, isEnabled: false)
    #expect(a.sharesChord(with: b))
}

@Test func sharesChordRequiresSameKeyAndModifiers() {
    let base = HotKeySpec(keyCode: 37, command: true, shift: true, option: false, control: false, isEnabled: true)
    #expect(!base.sharesChord(with: HotKeySpec(
        keyCode: 37, command: true, shift: false, option: false, control: false, isEnabled: true
    )))
    #expect(!base.sharesChord(with: HotKeySpec(
        keyCode: 9, command: true, shift: true, option: false, control: false, isEnabled: true
    )))
}

@Test func hotKeyMatchesExactModifiersAndKey() {
    let key = HotKeySpec(keyCode: 37, command: true, shift: true, option: false, control: false, isEnabled: true)
    #expect(key.matches(keyCode: 37, command: true, shift: true, option: false, control: false))
    #expect(!key.matches(keyCode: 37, command: true, shift: false, option: false, control: false))
    #expect(!key.matches(keyCode: 31, command: true, shift: true, option: false, control: false))
}

@Test func disabledHotKeyNeverMatches() {
    let key = HotKeySpec(keyCode: 37, command: true, shift: true, option: false, control: false, isEnabled: false)
    #expect(!key.matches(keyCode: 37, command: true, shift: true, option: false, control: false))
}

@Test func hotKeyDisplayIncludesOptionControl() {
    let key = HotKeySpec(keyCode: 31, command: true, shift: false, option: true, control: true, isEnabled: true)
    #expect(key.displayString == "⌃⌥⌘O")
}

@Test func hotKeyCarbonModifiersMatchCarbonConstants() {
    // Carbon: cmdKey=256, shiftKey=512, optionKey=2048, controlKey=4096
    let key = HotKeySpec(keyCode: 37, command: true, shift: true, option: false, control: false, isEnabled: true)
    #expect(key.carbonModifiers == 256 + 512)
    let all = HotKeySpec(keyCode: 1, command: true, shift: true, option: true, control: true, isEnabled: true)
    #expect(all.carbonModifiers == 256 + 512 + 2048 + 4096)
}

@Test func hotKeyDisplayFallsBackForUnknownKeyCode() {
    let key = HotKeySpec(keyCode: 999, command: true, shift: false, option: false, control: false, isEnabled: true)
    #expect(key.displayString == "⌘Key999")
}
