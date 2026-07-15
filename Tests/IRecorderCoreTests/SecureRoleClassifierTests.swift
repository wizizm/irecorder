import Testing
@testable import IRecorderCore

@Test func secureTextFieldRole() {
    #expect(SecureRoleClassifier.isSecure(role: "AXSecureTextField", subrole: nil) == true)
}

@Test func passwordSubrole() {
    #expect(SecureRoleClassifier.isSecure(role: "AXTextField", subrole: "AXSecureTextField") == true)
}

@Test func normalTextField() {
    #expect(SecureRoleClassifier.isSecure(role: "AXTextField", subrole: nil) == false)
}
