import AppKit
import ApplicationServices
import Foundation
import IRecorderCore

/// Polls the focused AX element for committed text insertions.
final class AXWatcher {
    var onEvent: ((CaptureEvent) -> Void)?
    /// Shared with `KeyInsertionWatcher` so key-fallback only runs when AX has no string value.
    let focusCoverage = AXFocusCoverage()
    /// Latest focused AX string (for idle hold-buffer resolution).
    private(set) var latestFieldValue: String?

    private var poller: Poller?
    private var lastValue = ""
    private var lastElement: AXUIElement?
    private var wasSecure = false
    private var lastUntrustedLogAt: Date?
    private var lastDiagAt: Date?

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
        guard AXIsProcessTrusted() else {
            focusCoverage.focusedExposesStringValue = false
            focusCoverage.focusedIsSecure = false
            let now = Date()
            if lastUntrustedLogAt.map({ now.timeIntervalSince($0) > 30 }) ?? true {
                lastUntrustedLogAt = now
                NSLog("iRecorder: AXIsProcessTrusted=false — typing not captured until Accessibility is granted and app relaunched")
            }
            return
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        ) == .success,
            let focusedRef else {
            focusCoverage.focusedExposesStringValue = false
            focusCoverage.focusedIsSecure = false
            resetFocus()
            return
        }
        let element = (focusedRef as! AXUIElement)

        let role = stringAttribute(element, kAXRoleAttribute as String)
        let subrole = stringAttribute(element, kAXSubroleAttribute as String)
        if SecureRoleClassifier.isSecure(role: role, subrole: subrole) {
            wasSecure = true
            focusCoverage.focusedIsSecure = true
            focusCoverage.focusedExposesStringValue = false
            resetFocus()
            return
        }
        focusCoverage.focusedIsSecure = false

        guard let value = axStringValue(element) else {
            // No AX string (typical Cursor / Electron editor) → key-character fallback may run.
            // Clear stale field so hold-buffer idle resolve does not use a previous app's text.
            focusCoverage.focusedExposesStringValue = false
            latestFieldValue = nil
            diagnose(role: role, valueLen: -1, sameElement: false, compared: false, inserted: 0)
            return
        }

        let front = NSWorkspace.shared.frontmostApplication
        let vscodeBased = VSCodeBasedIDEPolicy.matches(
            appName: front?.localizedName ?? "",
            bundleID: front?.bundleIdentifier
        )

        // Branch B (VS Code–based only): Monaco textarea with "\n" / last char / ZWSP is not real text.
        // Native apps (Finder etc.) always stay on Branch A: AX diffs + field-presence hold.
        if ElectronEditorAXPolicy.isUnreliableEditorValue(
            role: role,
            value: value,
            vscodeBasedIDE: vscodeBased
        ) {
            focusCoverage.focusedExposesStringValue = false
            latestFieldValue = nil
            lastElement = element
            lastValue = value
            wasSecure = false
            diagnose(role: role, valueLen: value.count, sameElement: false, compared: false, inserted: 0)
            return
        }

        // Empty non-editable AXValue must not block the key fallback.
        focusCoverage.focusedExposesStringValue = isEditableRole(role) || !value.isEmpty

        let sameElement = lastElement.map { CFEqual($0, element) } ?? false
        let shouldCompare = !wasSecure && TypingFocusPolicy.shouldCompareToPrevious(
            sameElement: sameElement,
            previous: lastValue,
            current: value
        )

        var insertedCount = 0
        if shouldCompare,
           let inserted = TextInsertionDiff.insertedText(previous: lastValue, current: value),
           !inserted.isEmpty {
            // Skip ZWSP-laden IME composition scraps on VS Code–based editors only.
            let cleaned = inserted.replacingOccurrences(of: "\u{200B}", with: "")
            let scrap = ElectronEditorAXPolicy.isUnreliableEditorValue(
                role: role,
                value: inserted,
                vscodeBasedIDE: vscodeBased
            )
            if !cleaned.isEmpty, !scrap {
                insertedCount = inserted.count
                let app = front?.localizedName ?? "Unknown"
                onEvent?(CaptureEvent(
                    kind: .type,
                    appName: app,
                    payload: cleaned,
                    fieldValue: value
                ))
            }
        }

        diagnose(
            role: role,
            valueLen: value.count,
            sameElement: sameElement,
            compared: shouldCompare,
            inserted: insertedCount
        )

        lastElement = element
        lastValue = value
        latestFieldValue = value
        wasSecure = false
    }

    private func resetFocus() {
        lastElement = nil
        lastValue = ""
        latestFieldValue = nil
    }

    private func diagnose(role: String?, valueLen: Int, sameElement: Bool, compared: Bool, inserted: Int) {
        let now = Date()
        guard lastDiagAt.map({ now.timeIntervalSince($0) > 15 }) ?? true else { return }
        // Only log when something interesting happens (value present or insert).
        guard valueLen != 0 || inserted > 0 else { return }
        lastDiagAt = now
        NSLog(
            "iRecorder AX: role=%@ valueLen=%d sameEl=%d compare=%d inserted=%d",
            role ?? "nil",
            valueLen,
            sameElement ? 1 : 0,
            compared ? 1 : 0,
            inserted
        )
    }

    /// AXValue may be CFString / NSString / NSAttributedString depending on the app.
    private func axStringValue(_ element: AXUIElement) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &ref
        ) == .success,
            let ref else { return nil }

        let typeID = CFGetTypeID(ref)
        if typeID == CFStringGetTypeID() {
            return (ref as! CFString) as String
        }
        if let string = ref as? String {
            return string
        }
        if let attributed = ref as? NSAttributedString {
            return attributed.string
        }
        return nil
    }

    private func isEditableRole(_ role: String?) -> Bool {
        guard let role else { return false }
        let r = role.lowercased()
        return r.contains("text") || r.contains("combo") || r.contains("search")
    }

    private func stringAttribute(_ element: AXUIElement, _ name: String) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &ref) == .success,
              let ref else { return nil }
        let typeID = CFGetTypeID(ref)
        if typeID == CFStringGetTypeID() {
            return (ref as! CFString) as String
        }
        return ref as? String
    }
}
