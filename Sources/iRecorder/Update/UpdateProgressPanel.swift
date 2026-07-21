import AppKit
import IRecorderCore

/// Floating indeterminate progress panel for LSUIElement menu-bar apps (modeless so network can proceed).
final class UpdateProgressPanel: NSObject, UpdateProgressPresenting, NSWindowDelegate {
    var onCancel: (() -> Void)?

    private var panel: NSPanel?
    private var label: NSTextField?
    private var spinner: NSProgressIndicator?
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
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 120),
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

        let spinner = NSProgressIndicator(frame: NSRect(x: 20, y: 68, width: 24, height: 24))
        spinner.style = .spinning
        spinner.controlSize = .regular
        spinner.isIndeterminate = true
        spinner.startAnimation(nil)

        let label = NSTextField(labelWithString: message)
        label.frame = NSRect(x: 56, y: 62, width: 260, height: 32)
        label.font = .systemFont(ofSize: 13)
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 2

        let cancel = NSButton(
            title: MenuL10n.text(.cancel),
            target: self,
            action: #selector(cancelClicked)
        )
        cancel.bezelStyle = .rounded
        cancel.frame = NSRect(x: 220, y: 16, width: 100, height: 28)
        cancel.keyEquivalent = "\u{1b}" // Esc

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 120))
        content.addSubview(spinner)
        content.addSubview(label)
        content.addSubview(cancel)
        panel.contentView = content
        panel.center()

        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)

        self.panel = panel
        self.label = label
        self.spinner = spinner
        self.cancelButton = cancel
    }

    @MainActor
    func dismiss() {
        spinner?.stopAnimation(nil)
        panel?.delegate = nil
        panel?.orderOut(nil)
        panel = nil
        label = nil
        spinner = nil
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
