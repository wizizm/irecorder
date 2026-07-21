import Foundation

public enum LogRecordParser {
    private static let headerPattern = #"^(\d{4}-\d{2}-\d{2}T[^\t]+)\t(type|copy|paste|copy_paste)\t([^\t]*)\t(.*)$"#

    public static func parse(fileContents: String, timeZone: TimeZone = .current) -> [PasteHistoryItem] {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = timeZone
        dateFormatter.formatOptions = [.withInternetDateTime]

        var lines = fileContents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        // Trailing `\n` yields a spurious empty last element; drop it so EOF isn't payload.
        if fileContents.hasSuffix("\n"), lines.last == "" {
            lines.removeLast()
        }
        var items: [PasteHistoryItem] = []
        var index = 0

        while index < lines.count {
            guard let header = parseHeader(lines[index]) else {
                index += 1
                continue
            }

            var payload = header.payloadStart
            var next = index + 1

            if header.kind != .type {
                while next < lines.count, parseHeader(lines[next]) == nil {
                    payload += "\n" + lines[next]
                    next += 1
                }
            }

            if header.kind == .type {
                payload = unescapeTypePayload(payload)
            }

            if let date = dateFormatter.date(from: header.timestamp) {
                items.append(PasteHistoryItem(
                    date: date,
                    kind: header.kind,
                    appName: header.appName,
                    payload: payload
                ))
            }

            index = header.kind == .type ? index + 1 : next
        }

        return items
    }

    private struct Header {
        let timestamp: String
        let kind: CaptureKind
        let appName: String
        let payloadStart: String
    }

    private static func parseHeader(_ line: String) -> Header? {
        guard let regex = try? NSRegularExpression(pattern: headerPattern) else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              match.numberOfRanges == 5,
              let tsRange = Range(match.range(at: 1), in: line),
              let kindRange = Range(match.range(at: 2), in: line),
              let appRange = Range(match.range(at: 3), in: line),
              let payloadRange = Range(match.range(at: 4), in: line),
              let kind = CaptureKind(rawValue: String(line[kindRange]))
        else {
            return nil
        }
        return Header(
            timestamp: String(line[tsRange]),
            kind: kind,
            appName: String(line[appRange]),
            payloadStart: String(line[payloadRange])
        )
    }

    /// Reverse of `LogLineFormatter` type escaping: `\\` first via sentinel, then `\n`/`\t`.
    private static func unescapeTypePayload(_ encoded: String) -> String {
        let sentinel = "\u{0000}"
        return encoded
            .replacingOccurrences(of: "\\\\", with: sentinel)
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\t", with: "\t")
            .replacingOccurrences(of: sentinel, with: "\\")
    }
}
