import Foundation

/// Holds Latin under Chinese IME until the field reveals whether it was English or pinyin.
///
/// Presence checks use **Latin tokens** (maximal a–z runs), not raw `String.contains`.
/// Otherwise `"h"` matches inside `"zhong"` and `"te"` is kept while `"test"` was intended.
public final class CompositionHoldBuffer {
    public var holdInterval: TimeInterval

    private var held = ""
    private var lastActivity: Date?

    public init(holdInterval: TimeInterval = 0.45) {
        self.holdInterval = holdInterval
    }

    public func ingest(
        insertion: String,
        chineseIMEActive: Bool,
        fieldValue: String?,
        at: Date = Date()
    ) -> [String] {
        guard !insertion.isEmpty else { return [] }

        if !chineseIMEActive {
            var out: [String] = []
            out += resolveHeld(fieldValue: fieldValue)
            out.append(insertion)
            lastActivity = at
            return out
        }

        if Self.isLatinCompositionOnly(insertion) {
            held += insertion
            lastActivity = at
            return []
        }

        var out: [String] = []
        out += resolveHeld(fieldValue: fieldValue)
        let cleaned = Self.stripVanishedLeadingLatin(insertion, fieldValue: fieldValue)
        if !cleaned.isEmpty {
            out.append(cleaned)
        }
        lastActivity = at
        return out
    }

    /// Idle resolve. Under Chinese IME, never flush — unfinished pinyin is still visible in the
    /// field and would be mistaken for English (Finder: `zheyang`/`te`/`tai` leaks).
    /// English under Chinese IME is emitted when CJK arrives (field-presence) or when IME turns off.
    public func tick(
        at: Date = Date(),
        fieldValue: String?,
        chineseIMEActive: Bool
    ) -> [String] {
        guard !held.isEmpty,
              let last = lastActivity,
              at.timeIntervalSince(last) >= holdInterval else {
            return []
        }
        if chineseIMEActive { return [] }
        return resolveHeld(fieldValue: fieldValue)
    }

    public func flushPending(fieldValue: String?) -> [String] {
        resolveHeld(fieldValue: fieldValue)
    }

    private func resolveHeld(fieldValue: String?) -> [String] {
        guard !held.isEmpty else { return [] }
        let candidate = held
        held = ""
        lastActivity = nil

        if let fieldValue {
            if candidate.contains("'") || candidate.contains("`") {
                // Full apostrophe composition still visible → pinyin in progress, drop.
                if Self.latinTokens(in: fieldValue).contains(candidate) {
                    return []
                }
                // Composition replaced: keep English prefix before the first apostrophe
                // (e.g. held "finderxing'bu" → before "finderxing" → field keeps "finder").
                if let cut = candidate.firstIndex(of: "'") ?? candidate.firstIndex(of: "`") {
                    let before = String(candidate[..<cut])
                    if let kept = Self.longestTokenAlignedPrefix(before, in: fieldValue), !kept.isEmpty {
                        return [kept]
                    }
                    if let promoted = Self.promoteHeldToFieldToken(before, in: fieldValue) {
                        return [promoted]
                    }
                }
                return []
            }
            // Exact Latin token match for longest held prefix (haishi + buxing → haishi).
            if let kept = Self.longestTokenAlignedPrefix(candidate, in: fieldValue), !kept.isEmpty {
                return [kept]
            }
            // AX missed some letters: held "te" while field token is already "test".
            if let promoted = Self.promoteHeldToFieldToken(candidate, in: fieldValue) {
                return [promoted]
            }
            return []
        }
        // No AX field (Cursor key-fallback): held Latin is pinyin noise — drop it.
        return []
    }

    /// Maximal runs of pinyin/Latin composition characters in `field`.
    static func latinTokens(in field: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        for ch in field {
            guard let scalar = ch.unicodeScalars.first, isPinyinCompositionScalar(scalar) else {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                continue
            }
            current.append(ch)
        }
        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }

    /// Longest prefix of `candidate` that equals a full Latin token in `field`.
    static func longestTokenAlignedPrefix(_ candidate: String, in field: String) -> String? {
        guard !candidate.isEmpty else { return nil }
        let tokens = Set(latinTokens(in: field))
        var end = candidate.endIndex
        while end > candidate.startIndex {
            let prefix = String(candidate[..<end])
            if tokens.contains(prefix) { return prefix }
            end = candidate.index(before: end)
        }
        return nil
    }

    /// When AX skipped letters, held may be a proper prefix of a longer field token (`te`→`test`).
    /// Require `held.count >= 2` so a pinyin scrap `h` does not promote into `zhong`.
    static func promoteHeldToFieldToken(_ held: String, in field: String) -> String? {
        guard held.count >= 2 else { return nil }
        for token in latinTokens(in: field) where token.count > held.count && token.hasPrefix(held) {
            return token
        }
        return nil
    }

    /// Longest prefix of `candidate` that appears as a substring of `field`.
    /// Prefer `longestTokenAlignedPrefix` for IME decisions; kept for direct unit use.
    static func longestContainedPrefix(_ candidate: String, in field: String) -> String? {
        guard !candidate.isEmpty else { return nil }
        var end = candidate.endIndex
        while end > candidate.startIndex {
            let prefix = String(candidate[..<end])
            if field.contains(prefix) { return prefix }
            end = candidate.index(before: end)
        }
        return nil
    }

    /// Leading Latin in a mixed insert that is no longer a real English token was pinyin.
    /// Leading Latin with apostrophe is always pinyin, even if still briefly visible.
    static func stripVanishedLeadingLatin(_ insertion: String, fieldValue: String?) -> String {
        guard !insertion.isEmpty else { return insertion }
        var end = insertion.startIndex
        while end < insertion.endIndex {
            guard let scalar = insertion[end].unicodeScalars.first,
                  isPinyinCompositionScalar(scalar) else { break }
            end = insertion.index(after: end)
        }
        guard end > insertion.startIndex, end < insertion.endIndex else { return insertion }
        let leading = String(insertion[..<end])
        let rest = String(insertion[end...])
        if leading.contains("'") || leading.contains("`") {
            return rest
        }
        // Mixed Latin+CJK: keep leading only when it is a real English token (type了),
        // never when it only matches inside another token (h inside zhong) or is a 1-letter scrap.
        if !isLatinCompositionOnly(rest) {
            guard let fieldValue else { return rest }
            let tokens = latinTokens(in: fieldValue)
            if tokens.contains(leading), leading.count >= 2 {
                return insertion
            }
            return rest
        }
        guard let fieldValue else { return insertion }
        if Set(latinTokens(in: fieldValue)).contains(leading) { return insertion }
        return rest
    }

    static func isLatinCompositionOnly(_ text: String) -> Bool {
        !text.isEmpty && text.unicodeScalars.allSatisfy(isPinyinCompositionScalar)
    }

    private static func isPinyinCompositionScalar(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 0x41...0x5A, 0x61...0x7A: return true // A-Z a-z
        case 0x27, 0x60, 0x2D, 0x3B: return true // ' ` - ;
        default: return false
        }
    }
}
