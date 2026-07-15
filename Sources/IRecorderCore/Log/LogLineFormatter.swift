import Foundation

public enum LogLineFormatter {
    public static func format(event: CaptureEvent, timeZone: TimeZone = .current) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: event.date)
        let payload = event.payload
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\(timestamp)\t\(event.kind.rawValue)\t\(event.appName)\t\(payload)"
    }
}
