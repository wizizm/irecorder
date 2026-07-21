import Foundation

public enum LogHistoryQuery {
    public static func todayUniqueCopies(
        directory: URL,
        date: Date = Date(),
        calendar: Calendar = .current,
        fileManager: FileManager = .default
    ) -> [PasteHistoryItem] {
        let name = LogFileNamer.fileName(for: date, calendar: calendar)
        let url = directory.appendingPathComponent(name)
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        let items = LogRecordParser.parse(fileContents: contents)
            .filter { $0.kind == .copy || $0.kind == .copyPaste }

        var newestByPayload: [String: PasteHistoryItem] = [:]
        for item in items {
            if let existing = newestByPayload[item.payload] {
                if item.date > existing.date {
                    newestByPayload[item.payload] = item
                }
            } else {
                newestByPayload[item.payload] = item
            }
        }
        return newestByPayload.values.sorted { $0.date > $1.date }
    }

    public static func search(
        directory: URL,
        query: String,
        limit: Int = 200,
        fileManager: FileManager = .default
    ) -> [PasteHistoryItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let needle = trimmed.lowercased()
        guard let names = try? fileManager.contentsOfDirectory(atPath: directory.path) else {
            return []
        }

        var matched: [PasteHistoryItem] = []
        for name in names where name.hasSuffix(".log") {
            let url = directory.appendingPathComponent(name)
            guard let contents = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for item in LogRecordParser.parse(fileContents: contents) {
                if item.payload.lowercased().contains(needle)
                    || item.appName.lowercased().contains(needle) {
                    matched.append(item)
                }
            }
        }
        return Array(matched.sorted { $0.date > $1.date }.prefix(limit))
    }
}
