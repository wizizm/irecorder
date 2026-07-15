import AppKit
import ApplicationServices
import Foundation
import IRecorderCore

/// Polls the focused AX element for committed text insertions.
final class AXWatcher {
    var onEvent: ((CaptureEvent) -> Void)?

    private var poller: Poller?
    private var lastValue = ""
    private var lastElement: AXUIElement?
    private var wasSecure = false

    func start() {
        stop()
        let poller = Poller(interval: 0.25) { [weak self] in
            self?.tick()
        }
        poller.start()
        self.poller = poller
    }

    func stop() {
        poller?.stop()
        poller = nil
    }

    static func isTrusted(prompt: Bool) -> Bool {
        if prompt {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
        return AXIsProcessTrusted()
    }

    private func tick() {
        guard AXIsProcessTrusted() else { return }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        ) == .success,
            let focusedRef else {
            resetFocus()
            return
        }
        let element = (focusedRef as! AXUIElement)

        let role = stringAttribute(element, kAXRoleAttribute as String)
        let subrole = stringAttribute(element, kAXSubroleAttribute as String)
        if SecureRoleClassifier.isSecure(role: role, subrole: subrole) {
            wasSecure = true
            resetFocus()
            return
        }

        guard let value = stringAttribute(element, kAXValueAttribute as String) else {
            return
        }

        if let last = lastElement, CFEqual(last, element), !wasSecure {
            if let inserted = TextInsertionDiff.insertedText(previous: lastValue, current: value),
               !inserted.isEmpty {
                let app = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
                onEvent?(CaptureEvent(kind: .type, appName: app, payload: inserted))
            }
            lastValue = value
        } else {
            lastElement = element
            lastValue = value
            wasSecure = false
        }
    }

    private func resetFocus() {
        lastElement = nil
        lastValue = ""
    }

    private func stringAttribute(_ element: AXUIElement, _ name: String) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &ref) == .success,
              let ref else { return nil }
        return ref as? String
    }
}
