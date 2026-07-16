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

    /// Key-fallback (Cursor): accept printable inserts; Chinese IME Latin is held/resolved
    /// by `CompositionHoldBuffer` (no field value → keep Latin without apostrophe).
    public static func shouldAcceptForKeyFallback(
        insertion: String,
        chineseIMEActive: Bool
    ) -> Bool {
        _ = chineseIMEActive
        return !insertion.isEmpty
    }
}
