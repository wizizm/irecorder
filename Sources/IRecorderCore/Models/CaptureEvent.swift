import Foundation

public enum CaptureKind: String, Sendable {
    case type
    case copy
    case paste
    case copyPaste = "copy_paste"
}

public struct CaptureEvent: Sendable, Equatable {
    public let kind: CaptureKind
    public let appName: String
    public let payload: String
    public let date: Date

    public init(kind: CaptureKind, appName: String, payload: String, date: Date = Date()) {
        self.kind = kind
        self.appName = appName
        self.payload = payload
        self.date = date
    }
}
