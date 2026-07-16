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
    /// Full AX field value after this insert (type from AX only). Used to tell English from pinyin.
    public let fieldValue: String?

    public init(
        kind: CaptureKind,
        appName: String,
        payload: String,
        date: Date = Date(),
        fieldValue: String? = nil
    ) {
        self.kind = kind
        self.appName = appName
        self.payload = payload
        self.date = date
        self.fieldValue = fieldValue
    }
}
