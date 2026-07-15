import Foundation
import Testing
@testable import IRecorderCore

@Test func captureKindRawValuesMatchLogTokens() {
    #expect(CaptureKind.type.rawValue == "type")
    #expect(CaptureKind.copy.rawValue == "copy")
    #expect(CaptureKind.paste.rawValue == "paste")
}
