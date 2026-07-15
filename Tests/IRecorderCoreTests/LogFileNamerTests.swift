import Foundation
import Testing
@testable import IRecorderCore

@Test func dailyFileName() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
    let date = cal.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 23, minute: 59))!
    #expect(LogFileNamer.fileName(for: date, calendar: cal) == "2026-07-15.log")
}
