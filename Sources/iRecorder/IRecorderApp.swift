import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private var didLaunch = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !didLaunch else { return }
        didLaunch = true
        appState.startPromptingAccessibilityIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.coordinator.stop()
    }
}

@main
struct IRecorderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(appState: appDelegate.appState)
                .onAppear { appDelegate.appState.start() }
        } label: {
            MenuBarLabel(appState: appDelegate.appState)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(appState: appDelegate.appState)
        }
    }
}
