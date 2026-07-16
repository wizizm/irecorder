import Foundation

/// Monaco/Electron editors often expose a textarea that does **not** hold real document text
/// (newline-only, last composed char, or IME ZWSP markers). Treat those as "no AX coverage".
///
/// **Only** for VS Code–based IDEs. Native apps (Finder / 企业微信 / Notes) must keep normal AX
/// diffs even when the field briefly has 0–1 characters.
public enum ElectronEditorAXPolicy {
    public static func isUnreliableEditorValue(
        role: String?,
        value: String?,
        vscodeBasedIDE: Bool
    ) -> Bool {
        guard vscodeBasedIDE else { return false }

        let r = (role ?? "").lowercased()
        let looksEditable =
            r.contains("textarea")
            || r.contains("textfield")
            || r.contains("text")
            || r == "axgroup"
            || r.contains("group")
        guard looksEditable else { return false }

        guard let value else { return true }
        if value.contains("\u{200B}") { return true } // IME / screen-reader composition marker
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        // Monaco without screen-reader mode often keeps only the last character in the textarea.
        if trimmed.count <= 1 { return true }
        return false
    }
}
