import Foundation
import Testing
@testable import IRecorderCore

@Test func escapesNewlineAndTab() {
    var cal = Calendar(identifier: .gregorian)
    let tz = TimeZone(secondsFromGMT: 8 * 3600)!
    cal.timeZone = tz
    let date = cal.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 16, minute: 12, second: 3))!
    let event = CaptureEvent(kind: .type, appName: "Safari", payload: "a\nb\tc", date: date)
    let line = LogLineFormatter.format(event: event, timeZone: tz)
    #expect(line == "2026-07-15T16:12:03+08:00\ttype\tSafari\ta\\nb\\tc")
}
