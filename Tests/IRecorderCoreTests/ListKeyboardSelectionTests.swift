import Foundation
import Testing
@testable import IRecorderCore

@Test func listKeyboardMoveDownFromNilSelectsFirst() {
    #expect(ListKeyboardSelection.moveDown(from: nil, count: 3) == 0)
    #expect(ListKeyboardSelection.moveDown(from: nil, count: 0) == nil)
}

@Test func listKeyboardMoveDownAdvancesAndClamps() {
    #expect(ListKeyboardSelection.moveDown(from: 0, count: 3) == 1)
    #expect(ListKeyboardSelection.moveDown(from: 2, count: 3) == 2)
}

@Test func listKeyboardMoveUpFromNilSelectsLast() {
    #expect(ListKeyboardSelection.moveUp(from: nil, count: 3) == 2)
    #expect(ListKeyboardSelection.moveUp(from: nil, count: 0) == nil)
}

@Test func listKeyboardMoveUpRetreatsAndClamps() {
    #expect(ListKeyboardSelection.moveUp(from: 2, count: 3) == 1)
    #expect(ListKeyboardSelection.moveUp(from: 0, count: 3) == 0)
}
