import Foundation

/// Holds Latin under Chinese IME until the field reveals whether it was English or pinyin.
///
/// Rule: if held Latin is still a substring of the current AX field value when CJK (or idle)
/// arrives, emit it as English; if it vanished (IME replaced it), drop it as pinyin.
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

    public func tick(at: Date = Date(), fieldValue: String?) -> [String] {
        guard !held.isEmpty,
              let last = lastActivity,
              at.timeIntervalSince(last) >= holdInterval else {
            return []
        }
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
            // English may be followed by more pinyin in the same hold ("haishi"+"buxing").
            // Keep the longest prefix still present in the field; drop the replaced suffix.
            if let kept = Self.longestContainedPrefix(candidate, in: fieldValue), !kept.isEmpty {
                return [kept]
            }
            return []
        }
        // No AX field (key fallback): keep Latin unless it looks like IME composition (apostrophe).
        if candidate.contains("'") || candidate.contains("`") {
            return []
        }
        return [candidate]
    }

    /// Longest prefix of `candidate` that appears as a substring of `field`.
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

    /// Leading Latin in a mixed insert that is no longer in the field was pinyin replaced in-frame.
    static func stripVanishedLeadingLatin(_ insertion: String, fieldValue: String?) -> String {
        guard let fieldValue, !insertion.isEmpty else { return insertion }
        var end = insertion.startIndex
        while end < insertion.endIndex {
            guard let scalar = insertion[end].unicodeScalars.first,
                  isPinyinCompositionScalar(scalar) else { break }
            end = insertion.index(after: end)
        }
        guard end > insertion.startIndex, end < insertion.endIndex else { return insertion }
        let leading = String(insertion[..<end])
        let rest = String(insertion[end...])
        if fieldValue.contains(leading) { return insertion }
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
