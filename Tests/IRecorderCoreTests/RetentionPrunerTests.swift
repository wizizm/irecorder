import Foundation
import Testing
@testable import IRecorderCore

@Test func pruneOlderThanRetention() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    let today = cal.date(from: DateComponents(year: 2026, month: 7, day: 15))!
    let names = ["2026-07-15.log", "2026-06-01.log", "not-a-log.txt", "2026-07-14.log"]
    let doomed = RetentionPruner.filesToDelete(names: names, today: today, retainDays: 1, calendar: cal)
    #expect(Set(doomed) == Set(["2026-06-01.log"]))
}

@Test func retainDaysZeroDeletesNothing() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    let today = cal.date(from: DateComponents(year: 2026, month: 7, day: 15))!
    let doomed = RetentionPruner.filesToDelete(
        names: ["2020-01-01.log"],
        today: today,
        retainDays: 0,
        calendar: cal
    )
    #expect(doomed.isEmpty)
}
