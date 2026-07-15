import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        appState.start()
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
        } label: {
            MenuBarLabel(appState: appDelegate.appState)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(appState: appDelegate.appState)
        }
    }
}
