import Foundation

public struct PasteHistoryItem: Equatable, Sendable {
    public let date: Date
    public let kind: CaptureKind
    public let appName: String
    public let payload: String

    public init(date: Date, kind: CaptureKind, appName: String, payload: String) {
        self.date = date
        self.kind = kind
        self.appName = appName
        self.payload = payload
    }
}
