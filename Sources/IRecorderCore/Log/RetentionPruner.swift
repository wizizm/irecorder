import Foundation

public enum RetentionPruner {
    /// Returns log file names older than `retainDays` before `today`.
    /// When `retainDays <= 0`, returns an empty list (never prune).
    public static func filesToDelete(
        names: [String],
        today: Date,
        retainDays: Int,
        calendar: Calendar = .current
    ) -> [String] {
        guard retainDays > 0 else { return [] }
        guard let cutoff = calendar.date(byAdding: .day, value: -retainDays, to: calendar.startOfDay(for: today)) else {
            return []
        }
        return names.filter { name in
            guard let fileDay = LogFileNamer.date(fromFileName: name, calendar: calendar) else {
                return false
            }
            return fileDay < cutoff
        }
    }
}
