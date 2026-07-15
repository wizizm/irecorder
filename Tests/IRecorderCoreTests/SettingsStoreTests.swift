import Foundation
import Testing
@testable import IRecorderCore

@Test func settingsDefaults() {
    let suite = "test.irecorder.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = SettingsStore(defaults: defaults)
    #expect(store.retentionDays == 30)
    #expect(store.launchAtLogin == true)
    #expect(store.isRecording == true)
    #expect(store.logDirectoryURL.path.hasSuffix("Documents/iRecorder"))
}

@Test func settingsPersist() {
    let suite = "test.irecorder.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = SettingsStore(defaults: defaults)
    store.retentionDays = 7
    store.isRecording = false
    store.launchAtLogin = false
    let custom = URL(fileURLWithPath: "/tmp/irecorder-test-logs")
    store.logDirectoryURL = custom

    let again = SettingsStore(defaults: defaults)
    #expect(again.retentionDays == 7)
    #expect(again.isRecording == false)
    #expect(again.launchAtLogin == false)
    #expect(again.logDirectoryURL == custom)
}
