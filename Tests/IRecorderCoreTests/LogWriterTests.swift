import Foundation
import Testing
@testable import IRecorderCore

@Test func appendWritesDailyFile() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    let writer = LogWriter(directory: dir, calendar: cal, timeZone: cal.timeZone)
    let date = cal.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12))!
    let event = CaptureEvent(kind: .copy, appName: "Finder", payload: "hello", date: date)
    try writer.append(event)
    let name = LogFileNamer.fileName(for: date, calendar: cal)
    let text = try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
    #expect(text.contains("\tcopy\tFinder\thello"))
}

@Test func appendEscapesAndTruncates() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let writer = LogWriter(directory: dir)
    let huge = String(repeating: "x", count: 100_010)
    let event = CaptureEvent(kind: .type, appName: "App", payload: "a\nb", date: Date())
    try writer.append(event, maxPayloadBytes: nil)
    let hugeEvent = CaptureEvent(kind: .copy, appName: "App", payload: huge, date: Date())
    try writer.append(hugeEvent, maxPayloadBytes: 100_000)
    let name = LogFileNamer.fileName(for: event.date)
    let text = try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
    #expect(text.contains("a\\nb"))
    #expect(text.contains(" [truncated]"))
}

@Test func appendRespectsCustomClipboardMaxBytes() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let writer = LogWriter(directory: dir)
    let payload = String(repeating: "y", count: 500)
    let event = CaptureEvent(kind: .paste, appName: "Notes", payload: payload, date: Date())
    try writer.append(event, maxPayloadBytes: 100)
    let name = LogFileNamer.fileName(for: event.date)
    let text = try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
    #expect(text.contains(" [truncated]"))
    #expect(!text.contains(payload))
}
