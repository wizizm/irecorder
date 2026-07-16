public enum CompositionInsertionFilter {
    /// True when insertion is Latin/apostrophe-only under Chinese IME (composition candidate).
    /// Prefer `CompositionHoldBuffer` for AX capture; this remains for unit checks / key policy.
    public static func shouldIgnore(insertion: String, chineseIMEActive: Bool) -> Bool {
        guard chineseIMEActive, !insertion.isEmpty else { return false }
        return CompositionHoldBuffer.isLatinCompositionOnly(insertion)
    }
}
