import Foundation
import Testing
@testable import IRecorderCore

@Test func parseSingleLineCopy() {
    let raw = "2026-07-21T10:00:00+08:00\tcopy\tSafari\thello"
    let items = LogRecordParser.parse(fileContents: raw, timeZone: TimeZone(secondsFromGMT: 8 * 3600)!)
    #expect(items.count == 1)
    #expect(items[0].kind == .copy)
    #expect(items[0].appName == "Safari")
    #expect(items[0].payload == "hello")
}

@Test func parseMultilineCopyUntilNextHeader() {
    let raw = """
    2026-07-21T10:00:00+08:00\tcopy\tNotes\tline1
    line2
    2026-07-21T10:01:00+08:00\tpaste\tSafari\tx
    """
    let items = LogRecordParser.parse(fileContents: raw, timeZone: TimeZone(secondsFromGMT: 8 * 3600)!)
    #expect(items.count == 2)
    #expect(items[0].payload == "line1\nline2")
    #expect(items[1].kind == .paste)
    #expect(items[1].payload == "x")
}

@Test func parseTypeUnescapesPayload() {
    let raw = "2026-07-21T10:00:00+08:00\ttype\tSafari\ta\\nb\\\\c"
    let items = LogRecordParser.parse(fileContents: raw, timeZone: TimeZone(secondsFromGMT: 8 * 3600)!)
    #expect(items.count == 1)
    #expect(items[0].kind == .type)
    #expect(items[0].payload == "a\nb\\c")
}

@Test func parseSkipsGarbageLines() {
    let raw = "not-a-record\n2026-07-21T10:00:00+08:00\tcopy\tA\toK\n"
    let items = LogRecordParser.parse(fileContents: raw, timeZone: TimeZone(secondsFromGMT: 8 * 3600)!)
    #expect(items.count == 1)
    #expect(items[0].payload == "oK")
}
