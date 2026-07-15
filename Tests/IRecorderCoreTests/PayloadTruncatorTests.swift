import Testing
@testable import IRecorderCore

@Test func truncateOver100KB() {
    let s = String(repeating: "啊", count: 60_000)
    let out = PayloadTruncator.truncate(s)
    #expect(out.hasSuffix(" [truncated]"))
    #expect(out.utf8.count <= 100_000 + " [truncated]".utf8.count)
}

@Test func shortPayloadUnchanged() {
    #expect(PayloadTruncator.truncate("你好") == "你好")
}
