import AppKit
import Foundation
import IRecorderCore

enum UpdateMenuActions {
    private static var isChecking = false
    private static var runningTask: Task<Void, Never>?
    private static let installer: any AppInstalling = AppBundleInstaller()

    static func openHelp() {
        NSWorkspace.shared.open(AppProject.issuesURL)
    }

    @MainActor
    static func checkForUpdates(
        checker: UpdateChecker = AppUpdateCoordinator.makeChecker(),
        destinationApp: URL = Bundle.main.bundleURL,
        progressPresenter: (any UpdateProgressPresenting)? = nil
    ) {
        guard !isChecking else { return }
        isChecking = true
        let progress = UpdateProgressSession(presenter: progressPresenter ?? UpdateProgressPanel())
        progress.onCancel = {
            progress.dismissIfNeeded()
            runningTask?.cancel()
        }
        NSApp.activate(ignoringOtherApps: true)
        progress.show(MenuL10n.text(.checkingForUpdates))

        let task = Task { @MainActor in
            defer {
                progress.dismissIfNeeded()
                isChecking = false
                runningTask = nil
            }
            do {
                try Task.checkCancellation()
                let outcome = try await checker.check()
                try Task.checkCancellation()
                progress.dismissIfNeeded()
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
                    try Task.checkCancellation()
                    progress.show(MenuL10n.text(.downloadingUpdate))
                    let progressLanguage: DownloadProgressFormat.Language =
                        MenuL10n.language == .chinese ? .chinese : .english
                    try await installer.install(
                        from: downloadURL,
                        replacing: destinationApp,
                        onProgress: { written, total in
                            Task { @MainActor in
                                progress.updateDownloadProgress(
                                    written: written,
                                    total: total,
                                    language: progressLanguage
                                )
                            }
                        }
                    )
                    try Task.checkCancellation()
                    progress.dismissIfNeeded()
                    NSWorkspace.shared.open(destinationApp)
                    NSApplication.shared.terminate(nil)
                }
            } catch {
                progress.dismissIfNeeded()
                guard UpdateCheckErrorPolicy.shouldPresentFailure(for: error) else { return }
                presentAlert(
                    title: MenuL10n.text(.updateFailedTitle),
                    message: MenuL10n.failureMessage(for: error)
                )
            }
        }
        runningTask = task
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
