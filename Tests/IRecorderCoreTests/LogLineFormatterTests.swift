import Foundation
import Testing
@testable import IRecorderCore

private func fixedDate() -> (date: Date, tz: TimeZone) {
    var cal = Calendar(identifier: .gregorian)
    let tz = TimeZone(secondsFromGMT: 8 * 3600)!
    cal.timeZone = tz
    let date = cal.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 16, minute: 12, second: 3))!
    return (date, tz)
}

@Test func typeEscapesNewlineAndTab() {
    let (date, tz) = fixedDate()
    let event = CaptureEvent(kind: .type, appName: "Safari", payload: "a\nb\tc", date: date)
    let line = LogLineFormatter.format(event: event, timeZone: tz)
    #expect(line == "2026-07-15T16:12:03+08:00\ttype\tSafari\ta\\nb\\tc")
}

@Test func copyPasteKeepsOriginalNewlinesAndTabs() {
    let (date, tz) = fixedDate()
    let payload = "line1\nline2\tindented"
    for kind in [CaptureKind.copy, .paste, .copyPaste] {
        let event = CaptureEvent(kind: kind, appName: "Notes", payload: payload, date: date)
        let line = LogLineFormatter.format(event: event, timeZone: tz)
        #expect(line == "2026-07-15T16:12:03+08:00\t\(kind.rawValue)\tNotes\tline1\nline2\tindented")
        #expect(!line.contains("\\n"))
        #expect(line.contains("\n"))
    }
}
