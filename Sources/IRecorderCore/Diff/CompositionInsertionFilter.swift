public enum CompositionInsertionFilter {
    /// While a Chinese IME is active, skip Latin/apostrophe-only inserts (pinyin composition),
    /// keep committed CJK and other real text.
    public static func shouldIgnore(insertion: String, chineseIMEActive: Bool) -> Bool {
        guard chineseIMEActive, !insertion.isEmpty else { return false }
        return insertion.unicodeScalars.allSatisfy(isPinyinCompositionScalar)
    }

    private static func isPinyinCompositionScalar(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 0x41...0x5A, 0x61...0x7A: // A-Z a-z
            return true
        case 0x27, 0x60, 0x2D, 0x3B: // ' ` - ;
            return true
        default:
            return false
        }
    }
}
