import Foundation

/// Keyboard shortcut stored without AppKit (keyCode + modifier flags).
public struct HotKeySpec: Equatable, Codable, Sendable {
    public var keyCode: UInt16
    public var command: Bool
    public var shift: Bool
    public var option: Bool
    public var control: Bool
    public var isEnabled: Bool

    public init(
        keyCode: UInt16,
        command: Bool,
        shift: Bool,
        option: Bool,
        control: Bool,
        isEnabled: Bool
    ) {
        self.keyCode = keyCode
        self.command = command
        self.shift = shift
        self.option = option
        self.control = control
        self.isEnabled = isEnabled
    }

    /// Default: ⌘⇧L — open today's log.
    public static let defaultOpenTodayLog = HotKeySpec(
        keyCode: 37,
        command: true,
        shift: true,
        option: false,
        control: false,
        isEnabled: true
    )

    /// Default paste-history hotkey placeholder (⌘⇧L); disabled until user enables.
    public static let defaultPasteHistory = HotKeySpec(
        keyCode: 37,
        command: true,
        shift: true,
        option: false,
        control: false,
        isEnabled: false
    )

    public func matches(
        keyCode: UInt16,
        command: Bool,
        shift: Bool,
        option: Bool,
        control: Bool
    ) -> Bool {
        guard isEnabled else { return false }
        return self.keyCode == keyCode
            && self.command == command
            && self.shift == shift
            && self.option == option
            && self.control == control
    }

    /// Same keyCode + modifiers (ignores `isEnabled`). Used to avoid dual Carbon registration.
    public func sharesChord(with other: HotKeySpec) -> Bool {
        keyCode == other.keyCode
            && command == other.command
            && shift == other.shift
            && option == other.option
            && control == other.control
    }

    /// Carbon `RegisterEventHotKey` modifier mask (cmd/shift/option/control).
    public var carbonModifiers: UInt32 {
        var mask: UInt32 = 0
        if command { mask |= 256 }   // cmdKey
        if shift { mask |= 512 }     // shiftKey
        if option { mask |= 2048 }   // optionKey
        if control { mask |= 4096 }  // controlKey
        return mask
    }

    /// macOS-style glyphs, modifiers in ⌃⌥⇧⌘ order then key letter.
    public var displayString: String {
        var parts = ""
        if control { parts += "⌃" }
        if option { parts += "⌥" }
        if shift { parts += "⇧" }
        if command { parts += "⌘" }
        parts += Self.keyLabel(for: keyCode)
        return parts
    }

    private static func keyLabel(for keyCode: UInt16) -> String {
        let map: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L",
            38: "J", 40: "K", 45: "N", 46: "M",
            18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7",
            28: "8", 25: "9", 29: "0",
            36: "↩", 48: "⇥", 49: "␣", 51: "⌫", 53: "⎋",
            123: "←", 124: "→", 125: "↓", 126: "↑",
        ]
        return map[keyCode] ?? "Key\(keyCode)"
    }
}
