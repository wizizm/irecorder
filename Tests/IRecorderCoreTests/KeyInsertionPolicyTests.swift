import Testing
@testable import IRecorderCore

@Test func recordsPrintableLatinAndCJK() {
    #expect(KeyInsertionPolicy.insertion(
        characters: "a",
        command: false, option: false, control: false,
        keyCode: 0
    ) == "a")
    #expect(KeyInsertionPolicy.insertion(
        characters: "测",
        command: false, option: false, control: false,
        keyCode: 0
    ) == "测")
    #expect(KeyInsertionPolicy.insertion(
        characters: " ",
        command: false, option: false, control: false,
        keyCode: 49
    ) == " ")
}

@Test func skipsShortcutsWithCommandOptionControl() {
    #expect(KeyInsertionPolicy.insertion(
        characters: "v",
        command: true, option: false, control: false,
        keyCode: 9
    ) == nil)
    #expect(KeyInsertionPolicy.insertion(
        characters: "c",
        command: false, option: true, control: false,
        keyCode: 8
    ) == nil)
}

@Test func skipsNavigationAndEditKeys() {
    #expect(KeyInsertionPolicy.insertion(
        characters: "\r",
        command: false, option: false, control: false,
        keyCode: 36
    ) == nil)
    #expect(KeyInsertionPolicy.insertion(
        characters: "\u{7F}",
        command: false, option: false, control: false,
        keyCode: 51
    ) == nil)
    #expect(KeyInsertionPolicy.insertion(
        characters: "",
        command: false, option: false, control: false,
        keyCode: 123
    ) == nil)
}
