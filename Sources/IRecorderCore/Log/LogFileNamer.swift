import Foundation

public enum LogFileNamer {
    public static func fileName(for date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d.log", y, m, d)
    }

    /// Parses `YYYY-MM-DD.log` into a start-of-day date, or nil if not matching.
    public static func date(fromFileName name: String, calendar: Calendar = .current) -> Date? {
        guard name.hasSuffix(".log") else { return nil }
        let stamp = String(name.dropLast(4))
        let parts = stamp.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]),
              let m = Int(parts[1]),
              let d = Int(parts[2]) else { return nil }
        return calendar.date(from: DateComponents(year: y, month: m, day: d))
    }
}
