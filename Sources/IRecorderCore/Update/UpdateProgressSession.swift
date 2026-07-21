import Foundation

@MainActor
public protocol UpdateProgressPresenting: AnyObject {
    var onCancel: (() -> Void)? { get set }
    func show(message: String)
    /// `nil` + `barWhenNil: false` → spinner; `nil` + `barWhenNil: true` → indeterminate bar; else determinate bar.
    func setProgress(fraction: Double?, barWhenNil: Bool)
    func dismiss()
}

extension UpdateProgressPresenting {
    public func setProgress(fraction: Double?) {
        setProgress(fraction: fraction, barWhenNil: false)
    }
}

/// Tracks whether a progress UI is visible so dismiss is safe/idempotent.
@MainActor
public final class UpdateProgressSession {
    private let presenter: UpdateProgressPresenting
    private var isShowing = false
    private var lastPrefix = ""

    public var onCancel: (() -> Void)? {
        didSet { presenter.onCancel = onCancel }
    }

    public init(presenter: UpdateProgressPresenting) {
        self.presenter = presenter
    }

    public func show(_ message: String) {
        lastPrefix = message
        presenter.onCancel = onCancel
        presenter.show(message: message)
        presenter.setProgress(fraction: nil, barWhenNil: false)
        isShowing = true
    }

    public func updateDownloadProgress(
        written: Int64,
        total: Int64?,
        language: DownloadProgressFormat.Language
    ) {
        let text = DownloadProgressFormat.message(
            prefix: lastPrefix.isEmpty ? "" : lastPrefix,
            written: written,
            total: total,
            language: language
        )
        presenter.show(message: text.trimmingCharacters(in: .whitespaces))
        // Always show a bar while downloading — indeterminate if Content-Length missing.
        presenter.setProgress(
            fraction: DownloadProgressFormat.fraction(written: written, total: total),
            barWhenNil: true
        )
        isShowing = true
    }

    public func dismissIfNeeded() {
        guard isShowing else { return }
        presenter.dismiss()
        isShowing = false
    }
}

public enum UpdateCheckErrorPolicy {
    /// User cancelled the progress UI — do not show a failure alert.
    public static func shouldPresentFailure(for error: Error) -> Bool {
        if error is CancellationError { return false }
        if let urlError = error as? URLError, urlError.code == .cancelled { return false }
        return true
    }
}

/// After primary (direct) session fails with a connectivity-ish error, try the fallback session.
public enum UpdateNetworkRetry {
    public static func shouldRetryWithoutProxy(_ error: Error) -> Bool {
        if error is CancellationError { return false }
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed,
             .secureConnectionFailed:
            return true
        default:
            return false
        }
    }
}
