import Foundation

public enum LogLineFormatter {
    public static func format(event: CaptureEvent, timeZone: TimeZone = .current) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: event.date)
        let payload = encodePayload(event.payload, kind: event.kind)
        return "\(timestamp)\t\(event.kind.rawValue)\t\(event.appName)\t\(payload)"
    }

    /// `type` stays one physical line (escape `\n`/`\t`).
    /// `copy` / `paste` / `copy_paste` keep original newlines and tabs so you can copy the payload out as-is.
    private static func encodePayload(_ payload: String, kind: CaptureKind) -> String {
        switch kind {
        case .copy, .paste, .copyPaste:
            return payload
        case .type:
            return payload
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\t", with: "\\t")
        }
    }
}
