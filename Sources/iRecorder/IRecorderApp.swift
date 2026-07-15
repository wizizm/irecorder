import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private var didBootstrap = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        bootstrapCapture()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        bootstrapCapture()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        appState.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.coordinator.stop()
    }

    func bootstrapCapture() {
        guard !didBootstrap else {
            appState.start()
            return
        }
        didBootstrap = true
        appState.startPromptingAccessibilityIfNeeded()
    }
}

@main
struct IRecorderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(appState: appDelegate.appState)
                .onAppear { appDelegate.bootstrapCapture() }
        } label: {
            MenuBarLabel(appState: appDelegate.appState)
                .task { appDelegate.bootstrapCapture() }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(appState: appDelegate.appState)
                .frame(width: 400, height: 480)
        }
    }
}
