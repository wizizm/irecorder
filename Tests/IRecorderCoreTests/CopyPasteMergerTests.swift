import Foundation
import Testing
@testable import IRecorderCore

@Test func mergesCopyThenSamePasteQuickly() {
    let merger = CopyPasteMerger(mergeWindow: 3)
    let t0 = Date(timeIntervalSince1970: 5_000)
    #expect(merger.noteCopy(appName: "Safari", payload: "hello", at: t0).isEmpty)
    let out = merger.notePaste(appName: "Notes", payload: "hello", at: t0.addingTimeInterval(0.5))
    #expect(out.count == 1)
    #expect(out[0].kind == .copyPaste)
    #expect(out[0].payload == "hello")
    #expect(out[0].appName == "Safari→Notes")
}

@Test func pasteWithoutPendingCopyStaysPaste() {
    let merger = CopyPasteMerger(mergeWindow: 3)
    let out = merger.notePaste(appName: "Notes", payload: "alone", at: Date())
    #expect(out.map(\.kind) == [.paste])
}

@Test func typingBetweenBreaksMerge() {
    let merger = CopyPasteMerger(mergeWindow: 3)
    let t0 = Date(timeIntervalSince1970: 6_000)
    #expect(merger.noteCopy(appName: "A", payload: "x", at: t0).isEmpty)
    let interrupted = merger.noteInterruptingActivity(at: t0.addingTimeInterval(0.2))
    #expect(interrupted.map(\.kind) == [.copy])
    let paste = merger.notePaste(appName: "B", payload: "x", at: t0.addingTimeInterval(0.4))
    #expect(paste.map(\.kind) == [.paste])
}

@Test func differentPasteFlushesCopyThenPaste() {
    let merger = CopyPasteMerger(mergeWindow: 3)
    let t0 = Date(timeIntervalSince1970: 7_000)
    #expect(merger.noteCopy(appName: "A", payload: "x", at: t0).isEmpty)
    let out = merger.notePaste(appName: "A", payload: "y", at: t0.addingTimeInterval(0.2))
    #expect(out.map(\.kind) == [.copy, .paste])
    #expect(out.map(\.payload) == ["x", "y"])
}

@Test func mergeWindowExpiryFlushesCopy() {
    let merger = CopyPasteMerger(mergeWindow: 1)
    let t0 = Date(timeIntervalSince1970: 8_000)
    #expect(merger.noteCopy(appName: "A", payload: "x", at: t0).isEmpty)
    #expect(merger.tick(at: t0.addingTimeInterval(0.5)).isEmpty)
    let expired = merger.tick(at: t0.addingTimeInterval(1.1))
    #expect(expired.map(\.kind) == [.copy])
}
