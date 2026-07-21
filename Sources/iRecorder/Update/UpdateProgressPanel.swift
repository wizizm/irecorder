import AppKit
import IRecorderCore

/// Floating progress panel for LSUIElement menu-bar apps (modeless so network can proceed).
final class UpdateProgressPanel: NSObject, UpdateProgressPresenting, NSWindowDelegate {
    var onCancel: (() -> Void)?

    private var panel: NSPanel?
    private var label: NSTextField?
    private var spinner: NSProgressIndicator?
    private var bar: NSProgressIndicator?
    private var cancelButton: NSButton?

    @MainActor
    func show(message: String) {
        if let panel, let label {
            label.stringValue = message
            NSApp.activate(ignoringOtherApps: true)
            panel.orderFrontRegardless()
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 132),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = ""
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.delegate = self

        let spinner = NSProgressIndicator(frame: NSRect(x: 20, y: 84, width: 20, height: 20))
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isIndeterminate = true
        spinner.startAnimation(nil)

        let label = NSTextField(labelWithString: message)
        label.frame = NSRect(x: 48, y: 78, width: 312, height: 28)
        label.font = .systemFont(ofSize: 13)
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 2

        let bar = NSProgressIndicator(frame: NSRect(x: 20, y: 52, width: 340, height: 12))
        bar.style = .bar
        bar.isIndeterminate = false
        bar.minValue = 0
        bar.maxValue = 1
        bar.doubleValue = 0
        bar.isHidden = true

        let cancel = NSButton(
            title: MenuL10n.text(.cancel),
            target: self,
            action: #selector(cancelClicked)
        )
        cancel.bezelStyle = .rounded
        cancel.frame = NSRect(x: 260, y: 14, width: 100, height: 28)
        cancel.keyEquivalent = "\u{1b}" // Esc

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 132))
        content.addSubview(spinner)
        content.addSubview(label)
        content.addSubview(bar)
        content.addSubview(cancel)
        panel.contentView = content
        panel.center()

        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)

        self.panel = panel
        self.label = label
        self.spinner = spinner
        self.bar = bar
        self.cancelButton = cancel
    }

    @MainActor
    func setProgress(fraction: Double?, barWhenNil: Bool) {
        guard let bar, let spinner else { return }
        if let fraction {
            spinner.stopAnimation(nil)
            spinner.isHidden = true
            bar.stopAnimation(nil)
            bar.isHidden = false
            bar.isIndeterminate = false
            bar.doubleValue = fraction
        } else if barWhenNil {
            spinner.stopAnimation(nil)
            spinner.isHidden = true
            bar.isHidden = false
            bar.isIndeterminate = true
            bar.startAnimation(nil)
        } else {
            bar.stopAnimation(nil)
            bar.isHidden = true
            spinner.isHidden = false
            spinner.isIndeterminate = true
            spinner.startAnimation(nil)
        }
    }

    @MainActor
    func dismiss() {
        spinner?.stopAnimation(nil)
        bar?.stopAnimation(nil)
        panel?.delegate = nil
        panel?.orderOut(nil)
        panel = nil
        label = nil
        spinner = nil
        bar = nil
        cancelButton = nil
    }

    @objc private func cancelClicked() {
        onCancel?()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        onCancel?()
        return false
    }
}
