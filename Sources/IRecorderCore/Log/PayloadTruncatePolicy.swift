public enum PayloadTruncatePolicy {
    /// Bytes limit for truncating an event payload.
    /// - `nil` means do not truncate.
    /// - `configured <= 0` means unlimited for copy/paste.
    /// - `type` never uses the clipboard truncate setting.
    public static func maxBytes(for kind: CaptureKind, configured: Int) -> Int? {
        switch kind {
        case .type:
            return nil
        case .copy, .paste, .copyPaste:
            return configured > 0 ? configured : nil
        }
    }
}
