import Foundation

/// Tracks previously seen strings and returns newly appeared ones (stable first-seen order).
public final class SeenStringDiff {
    private var seen: Set<String> = []

    public init() {}

    public func replaceBaseline(_ texts: [String]) {
        seen = Set(texts)
    }

    public func ingest(_ texts: [String]) -> [String] {
        var out: [String] = []
        var local = Set<String>()
        for text in texts {
            if local.contains(text) { continue }
            local.insert(text)
            if seen.insert(text).inserted {
                out.append(text)
            }
        }
        return out
    }
}
