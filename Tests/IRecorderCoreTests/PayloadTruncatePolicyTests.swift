import Testing
@testable import IRecorderCore

@Test func clipboardKindsUseConfiguredLimit() {
    #expect(PayloadTruncatePolicy.maxBytes(for: .copy, configured: 50_000) == 50_000)
    #expect(PayloadTruncatePolicy.maxBytes(for: .paste, configured: 50_000) == 50_000)
    #expect(PayloadTruncatePolicy.maxBytes(for: .copyPaste, configured: 50_000) == 50_000)
}

@Test func typeKindDoesNotTruncateByClipboardSetting() {
    #expect(PayloadTruncatePolicy.maxBytes(for: .type, configured: 50_000) == nil)
}

@Test func zeroConfiguredMeansNoTruncateForClipboard() {
    #expect(PayloadTruncatePolicy.maxBytes(for: .copy, configured: 0) == nil)
    #expect(PayloadTruncatePolicy.maxBytes(for: .paste, configured: 0) == nil)
}
