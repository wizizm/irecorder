import Foundation
import Testing
@testable import IRecorderCore

@Test func todayUniqueCopiesKeepsNewestPayload() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
    let day = cal.date(from: DateComponents(year: 2026, month: 7, day: 21))!
    let name = LogFileNamer.fileName(for: day, calendar: cal)
    let body = """
    2026-07-21T09:00:00+08:00\tcopy\tA\tdupe
    2026-07-21T10:00:00+08:00\tcopy_paste\tB\tdupe
    2026-07-21T11:00:00+08:00\tpaste\tC\tignored
    2026-07-21T12:00:00+08:00\tcopy\tD\tother
    """
    try body.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    let items = LogHistoryQuery.todayUniqueCopies(directory: dir, date: day, calendar: cal)
    #expect(items.map(\.payload) == ["other", "dupe"])
    #expect(items[1].appName == "B")
}

@Test func searchMatchesCaseInsensitiveAcrossFilesWithLimit() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    try "2026-07-20T10:00:00+08:00\ttype\tSafari\tHelloWorld\n"
        .write(to: dir.appendingPathComponent("2026-07-20.log"), atomically: true, encoding: .utf8)
    try "2026-07-21T10:00:00+08:00\tcopy\tNotes\thello there\n"
        .write(to: dir.appendingPathComponent("2026-07-21.log"), atomically: true, encoding: .utf8)
    let all = LogHistoryQuery.search(directory: dir, query: "hello", limit: 200)
    #expect(all.count == 2)
    let capped = LogHistoryQuery.search(directory: dir, query: "hello", limit: 1)
    #expect(capped.count == 1)
    #expect(LogHistoryQuery.search(directory: dir, query: "   ").isEmpty)
}
