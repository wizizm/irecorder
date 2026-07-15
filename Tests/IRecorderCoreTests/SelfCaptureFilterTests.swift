import Testing
@testable import IRecorderCore

@Test func ignoresOwnApp() {
    #expect(SelfCaptureFilter.shouldIgnore(payload: "hi", appName: "iRecorder") == true)
}

@Test func ignoresRawLogLinePayload() {
    let payload = "2026-07-15T17:14:17+08:00\ttype\t企业微信\tc\n2026-07-15T17:14:18+08:00\ttype\t企业微信\te"
    #expect(SelfCaptureFilter.shouldIgnore(payload: payload, appName: "控制台") == true)
}

@Test func ignoresEscapedLogFeedback() {
    let payload = "2026-07-15T17:14:52+08:00\\tcopy\\t控制台\\t2026-07-15T17:14:17+08:00\\\\ttype\\\\t企业微信"
    #expect(SelfCaptureFilter.shouldIgnore(payload: payload, appName: "控制台") == true)
}

@Test func allowsNormalShortText() {
    #expect(SelfCaptureFilter.shouldIgnore(payload: "一小段文字", appName: "企业微信") == false)
    #expect(SelfCaptureFilter.shouldIgnore(payload: "hello\nworld", appName: "Notes") == false)
}
