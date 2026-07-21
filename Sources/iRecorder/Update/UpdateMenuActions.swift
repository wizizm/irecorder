import AppKit
import Foundation
import IRecorderCore

enum UpdateMenuActions {
    private static var isChecking = false
    private static let installer: any AppInstalling = AppBundleInstaller()

    static func openHelp() {
        NSWorkspace.shared.open(AppProject.issuesURL)
    }

    @MainActor
    static func checkForUpdates(
        checker: UpdateChecker = AppUpdateCoordinator.makeChecker(),
        destinationApp: URL = Bundle.main.bundleURL
    ) {
        guard !isChecking else { return }
        isChecking = true
        Task { @MainActor in
            defer { isChecking = false }
            NSApp.activate(ignoringOtherApps: true)
            do {
                let outcome = try await checker.check()
                switch outcome {
                case .upToDate(let current):
                    presentAlert(
                        title: MenuL10n.text(.upToDateTitle),
                        message: MenuL10n.upToDateMessage(current: current)
                    )
                case .updateAvailable(let current, let latest, let downloadURL):
                    let alert = NSAlert()
                    alert.messageText = MenuL10n.text(.updateAvailableTitle)
                    alert.informativeText = MenuL10n.updateAvailableMessage(
                        current: current,
                        latest: latest
                    )
                    alert.addButton(withTitle: MenuL10n.text(.downloadAndInstall))
                    alert.addButton(withTitle: MenuL10n.text(.cancel))
                    guard alert.runModal() == .alertFirstButtonReturn else { return }
                    try await installer.install(from: downloadURL, replacing: destinationApp)
                    NSWorkspace.shared.open(destinationApp)
                    NSApplication.shared.terminate(nil)
                }
            } catch {
                presentAlert(
                    title: MenuL10n.text(.updateFailedTitle),
                    message: error.localizedDescription
                )
            }
        }
    }

    @MainActor
    private static func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: MenuL10n.text(.ok))
        alert.runModal()
    }
}
