import Foundation
import Testing
@testable import IRecorderCore

@Test func suppressorIgnoresMatchingTypeAfterPaste() {
    let s = InsertionSuppressor(ttl: 2)
    s.notePaste("你好世界")
    #expect(s.shouldSuppressType("你好世界") == true)
}

@Test func suppressorExpires() {
    let s = InsertionSuppressor(ttl: 0.01)
    s.notePaste("x")
    Thread.sleep(forTimeInterval: 0.05)
    #expect(s.shouldSuppressType("x") == false)
}

@Test func suppressorAllowsUnrelatedType() {
    let s = InsertionSuppressor(ttl: 2)
    s.notePaste("paste")
    #expect(s.shouldSuppressType("typed") == false)
}
