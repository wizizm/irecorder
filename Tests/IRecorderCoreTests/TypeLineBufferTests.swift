import Foundation
import Testing
@testable import IRecorderCore

@Test func buffersUntilIdleTimeout() {
    let buffer = TypeLineBuffer(idleInterval: 2)
    let t0 = Date(timeIntervalSince1970: 1_000)
    #expect(buffer.ingest(appName: "Notes", insertion: "你", at: t0).isEmpty)
    #expect(buffer.ingest(appName: "Notes", insertion: "好", at: t0.addingTimeInterval(0.5)).isEmpty)
    #expect(buffer.tick(at: t0.addingTimeInterval(1.5)) == nil)
    let flushed = buffer.tick(at: t0.addingTimeInterval(2.6))
    #expect(flushed?.payload == "你好")
    #expect(flushed?.appName == "Notes")
}

@Test func enterFlushesImmediately() {
    let buffer = TypeLineBuffer(idleInterval: 10)
    let t0 = Date(timeIntervalSince1970: 2_000)
    #expect(buffer.ingest(appName: "X", insertion: "hello", at: t0).isEmpty)
    let flushed = buffer.noteEnter(at: t0.addingTimeInterval(0.1))
    #expect(flushed?.payload == "hello")
}

@Test func newlineInInsertionFlushes() {
    let buffer = TypeLineBuffer(idleInterval: 10)
    let t0 = Date(timeIntervalSince1970: 3_000)
    let first = buffer.ingest(appName: "X", insertion: "line1\nline2", at: t0)
    #expect(first.map(\.payload) == ["line1"])
    let second = buffer.tick(at: t0.addingTimeInterval(11))
    #expect(second?.payload == "line2")
}

@Test func appSwitchFlushesPending() {
    let buffer = TypeLineBuffer(idleInterval: 10)
    let t0 = Date(timeIntervalSince1970: 4_000)
    #expect(buffer.ingest(appName: "A", insertion: "aa", at: t0).isEmpty)
    let flushed = buffer.ingest(appName: "B", insertion: "bb", at: t0.addingTimeInterval(0.1))
    #expect(flushed.map(\.payload) == ["aa"])
    #expect(buffer.tick(at: t0.addingTimeInterval(20))?.payload == "bb")
}

@Test func emptyEnterDoesNothing() {
    let buffer = TypeLineBuffer(idleInterval: 2)
    #expect(buffer.noteEnter(at: Date()) == nil)
}
