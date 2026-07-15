public enum SecureRoleClassifier {
    public static func isSecure(role: String?, subrole: String?) -> Bool {
        if let role, looksSecure(role) { return true }
        if let subrole, looksSecure(subrole) { return true }
        return false
    }

    private static func looksSecure(_ value: String) -> Bool {
        let lowered = value.lowercased()
        return lowered.contains("secure") || lowered.contains("password")
    }
}
