import Foundation

/// Turns a raw keyDown into an on-screen insertion for apps that do not expose AXValue (e.g. Cursor).
public enum KeyInsertionPolicy {
    /// Return / keypad Enter / Tab / Esc / Backspace / ForwardDelete / arrows
    private static let nonInsertKeyCodes: Set<UInt16> = [
        36, 76, 48, 53, 51, 117, 123, 124, 125, 126,
    ]

    public static func insertion(
        characters: String?,
        command: Bool,
        option: Bool,
        control: Bool,
        keyCode: UInt16
    ) -> String? {
        if command || option || control { return nil }
        if nonInsertKeyCodes.contains(keyCode) { return nil }
        guard let characters, !characters.isEmpty else { return nil }

        var out = ""
        for ch in characters {
            guard let scalar = ch.unicodeScalars.first else { continue }
            // Skip control chars; keep space and printable (incl. CJK).
            if scalar.value < 0x20 { continue }
            if scalar.value == 0x7F { continue }
            out.append(ch)
        }
        return out.isEmpty ? nil : out
    }

    /// Strip IME/screen-reader zero-width markers before key-fallback decisions.
    public static func sanitizeKeyInsertion(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{200B}", with: "")
            .replacingOccurrences(of: "\u{FEFF}", with: "")
    }

    /// Return / keypad Enter without modifiers — used to trigger Cursor chat post-send capture.
    public static func isPlainReturn(
        keyCode: UInt16,
        command: Bool,
        option: Bool,
        control: Bool,
        shift: Bool
    ) -> Bool {
        if command || option || control || shift { return false }
        return keyCode == 36 || keyCode == 76
    }

    /// Cmd+Enter — also used by some VS Code chat panels to send.
    public static func isCommandReturn(
        keyCode: UInt16,
        command: Bool,
        option: Bool,
        control: Bool
    ) -> Bool {
        if !command || option || control { return false }
        return keyCode == 36 || keyCode == 76
    }

    /// Key-fallback:
    /// - VS Code–based + Chinese IME: accept nothing (chat Chinese captured after send only).
    /// - Other apps + Chinese IME: drop Latin/pinyin; keep CJK / punctuation.
    /// - ABC / non-Chinese IME: keep printable text.
    public static func shouldAcceptForKeyFallback(
        insertion: String,
        chineseIMEActive: Bool,
        vscodeBasedIDE: Bool = false
    ) -> Bool {
        let cleaned = sanitizeKeyInsertion(insertion)
        guard !cleaned.isEmpty else { return false }
        if vscodeBasedIDE, chineseIMEActive { return false }
        if chineseIMEActive, CompositionHoldBuffer.isLatinCompositionOnly(cleaned) {
            return false
        }
        return true
    }
}
