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
    #expect(store.clipboardTruncateMaxBytes == 100_000)
    #expect(store.typeLineIdleSeconds == 3)
    #expect(store.openTodayLogHotKey == HotKeySpec.defaultOpenTodayLog)
    #expect(store.pasteHistoryHotKey == HotKeySpec.defaultPasteHistory)
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
    store.clipboardTruncateMaxBytes = 8_000
    store.typeLineIdleSeconds = 5
    store.openTodayLogHotKey = HotKeySpec(
        keyCode: 31,
        command: true,
        shift: false,
        option: true,
        control: false,
        isEnabled: false
    )
    store.pasteHistoryHotKey = HotKeySpec(
        keyCode: 35,
        command: true,
        shift: true,
        option: false,
        control: false,
        isEnabled: true
    )
    let custom = URL(fileURLWithPath: "/tmp/irecorder-test-logs")
    store.logDirectoryURL = custom

    let again = SettingsStore(defaults: defaults)
    #expect(again.retentionDays == 7)
    #expect(again.isRecording == false)
    #expect(again.launchAtLogin == false)
    #expect(again.clipboardTruncateMaxBytes == 8_000)
    #expect(again.typeLineIdleSeconds == 5)
    #expect(again.openTodayLogHotKey == HotKeySpec(
        keyCode: 31,
        command: true,
        shift: false,
        option: true,
        control: false,
        isEnabled: false
    ))
    #expect(again.pasteHistoryHotKey == HotKeySpec(
        keyCode: 35,
        command: true,
        shift: true,
        option: false,
        control: false,
        isEnabled: true
    ))
    #expect(again.logDirectoryURL == custom)
}

@Test func openTodayLogHotKeyCorruptDataFallsBackToDefault() {
    let suite = "test.irecorder.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(Data("not-json".utf8), forKey: "openTodayLogHotKey")
    let store = SettingsStore(defaults: defaults)
    #expect(store.openTodayLogHotKey == HotKeySpec.defaultOpenTodayLog)
}

@Test func openTodayLogHotKeyWrongTypeFallsBackToDefault() {
    let suite = "test.irecorder.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set("⌘⇧L", forKey: "openTodayLogHotKey")
    let store = SettingsStore(defaults: defaults)
    #expect(store.openTodayLogHotKey == HotKeySpec.defaultOpenTodayLog)
}

@Test func settingsPasteHistoryHotKeyDefaultsDisabled() {
    let suite = "test.irecorder.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = SettingsStore(defaults: defaults)
    #expect(store.pasteHistoryHotKey == HotKeySpec.defaultPasteHistory)
    #expect(store.pasteHistoryHotKey.isEnabled == false)
}

@Test func pasteHistoryHotKeyCorruptFallsBack() {
    let suite = "test.irecorder.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(Data("bad".utf8), forKey: "pasteHistoryHotKey")
    #expect(SettingsStore(defaults: defaults).pasteHistoryHotKey == .defaultPasteHistory)
}
