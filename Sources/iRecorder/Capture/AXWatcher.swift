import AppKit
import ApplicationServices
import Foundation
import IRecorderCore

/// Polls the focused AX element for committed text insertions.
/// ponytail: 250ms poll instead of full AXObserver graph; ceiling ~latency; upgrade to AXObserver if needed.
final class AXWatcher {
    var onEvent: ((CaptureEvent) -> Void)?

    private var timer: Timer?
    private var lastValue = ""
    private var lastElement: AXUIElement?
    private var wasSecure = false

    func start() {
        stop()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
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
