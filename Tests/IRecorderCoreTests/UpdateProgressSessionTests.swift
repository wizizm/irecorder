import Foundation
import Testing
import IRecorderCore

@MainActor
final class RecordingProgressPresenter: UpdateProgressPresenting {
    private(set) var shown: [String] = []
    private(set) var fractions: [Double?] = []
    private(set) var dismissCount = 0
    var onCancel: (() -> Void)?
    private(set) var cancelInvocations = 0

    func show(message: String) {
        shown.append(message)
    }

    func setProgress(fraction: Double?) {
        fractions.append(fraction)
    }

    func dismiss() {
        dismissCount += 1
    }

    func simulateCancel() {
        cancelInvocations += 1
        onCancel?()
    }
}

@Suite("UpdateProgressSession")
@MainActor
struct UpdateProgressSessionTests {
    @Test func showThenDismissCallsPresenterOnceEach() {
        let presenter = RecordingProgressPresenter()
        let session = UpdateProgressSession(presenter: presenter)

        session.show("checking")
        #expect(presenter.shown == ["checking"])
        #expect(presenter.dismissCount == 0)

        session.dismissIfNeeded()
        #expect(presenter.dismissCount == 1)
    }

    @Test func dismissIsIdempotentWhenNeverShown() {
        let presenter = RecordingProgressPresenter()
        let session = UpdateProgressSession(presenter: presenter)

        session.dismissIfNeeded()
        session.dismissIfNeeded()
        #expect(presenter.dismissCount == 0)
    }

    @Test func secondShowUpdatesMessageWithoutExtraDismiss() {
        let presenter = RecordingProgressPresenter()
        let session = UpdateProgressSession(presenter: presenter)

        session.show("checking")
        session.show("downloading")
        session.dismissIfNeeded()

        #expect(presenter.shown == ["checking", "downloading"])
        #expect(presenter.dismissCount == 1)
    }

    @Test func dismissAfterShowThenShowAgainRequiresSecondDismiss() {
        let presenter = RecordingProgressPresenter()
        let session = UpdateProgressSession(presenter: presenter)

        session.show("a")
        session.dismissIfNeeded()
        session.show("b")
        session.dismissIfNeeded()

        #expect(presenter.shown == ["a", "b"])
        #expect(presenter.dismissCount == 2)
    }

    @Test func cancelHandlerIsInvokedViaPresenter() {
        let presenter = RecordingProgressPresenter()
        let session = UpdateProgressSession(presenter: presenter)
        var cancelled = false
        session.onCancel = { cancelled = true }

        presenter.simulateCancel()
        #expect(cancelled)
    }

    @Test func updateDownloadProgressUpdatesLabelAndBar() {
        let presenter = RecordingProgressPresenter()
        let session = UpdateProgressSession(presenter: presenter)
        session.show("正在下载更新…")
        session.updateDownloadProgress(written: 1_048_576, total: 2_097_152, language: .chinese)

        #expect(presenter.shown.last?.contains("50%") == true)
        #expect(presenter.fractions.last == 0.5)
    }
}

@Suite("UpdateCheckErrorPolicy")
struct UpdateCheckErrorPolicyTests {
    @Test func cancellationIsSilent() {
        #expect(UpdateCheckErrorPolicy.shouldPresentFailure(for: CancellationError()) == false)
    }

    @Test func urlErrorCancelledIsSilent() {
        #expect(UpdateCheckErrorPolicy.shouldPresentFailure(for: URLError(.cancelled)) == false)
    }

    @Test func otherErrorsPresentFailure() {
        #expect(UpdateCheckErrorPolicy.shouldPresentFailure(for: UpdateCheckerError.downloadFailed))
    }
}

@Suite("UpdateNetworkRetry")
struct UpdateNetworkRetryTests {
    @Test func timedOutRetriesWithoutProxy() {
        #expect(UpdateNetworkRetry.shouldRetryWithoutProxy(URLError(.timedOut)))
    }

    @Test func cannotConnectRetriesWithoutProxy() {
        #expect(UpdateNetworkRetry.shouldRetryWithoutProxy(URLError(.cannotConnectToHost)))
        #expect(UpdateNetworkRetry.shouldRetryWithoutProxy(URLError(.networkConnectionLost)))
        #expect(UpdateNetworkRetry.shouldRetryWithoutProxy(URLError(.dnsLookupFailed)))
        #expect(UpdateNetworkRetry.shouldRetryWithoutProxy(URLError(.secureConnectionFailed)))
    }

    @Test func cancelledDoesNotRetryWithoutProxy() {
        #expect(!UpdateNetworkRetry.shouldRetryWithoutProxy(URLError(.cancelled)))
        #expect(!UpdateNetworkRetry.shouldRetryWithoutProxy(CancellationError()))
    }

    @Test func checkerErrorDoesNotRetryWithoutProxy() {
        #expect(!UpdateNetworkRetry.shouldRetryWithoutProxy(UpdateCheckerError.downloadFailed))
    }
}
