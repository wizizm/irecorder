import AppKit
import ApplicationServices
import Foundation
import IRecorderCore

/// After Enter/⌘Enter in VS Code–based IDEs (no reliable AXValue), pick up newly appeared
/// chat bubble text from the AX tree (Cursor / VS Code / Windsurf chat panels).
final class CursorChatAXProbe {
    var onEvent: ((CaptureEvent) -> Void)?

    private let seen = SeenStringDiff()
    private var primed = false
    private var scanWorkItems: [DispatchWorkItem] = []

    func start() {}

    func stop() {
        cancelPendingScans()
    }

    /// Call when Return (or ⌘Return) is pressed while a VS Code–based IDE is frontmost
    /// and AX string capture is inactive/unreliable. Chinese IME only — avoids double-logging ABC.
    func notePlainReturn(chineseIMEActive: Bool) {
        guard chineseIMEActive else { return }
        guard isVSCodeBasedFrontmost() else { return }
        ensureBaseline()
        cancelPendingScans()
        for delay in [0.25, 0.6, 1.2, 2.0] as [TimeInterval] {
            let work = DispatchWorkItem { [weak self] in
                self?.scanForNewMessages()
            }
            scanWorkItems.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }

    func tickPrimeIfNeeded() {
        guard isVSCodeBasedFrontmost() else { return }
        ensureBaseline()
    }

    private func ensureBaseline() {
        guard !primed else { return }
        seen.replaceBaseline(collectCandidateTexts())
        primed = true
    }

    private func cancelPendingScans() {
        for item in scanWorkItems { item.cancel() }
        scanWorkItems.removeAll()
    }

    private func scanForNewMessages() {
        guard isVSCodeBasedFrontmost() else { return }
        let texts = collectCandidateTexts()
        let fresh = seen.ingest(texts).filter(CursorChatTextPolicy.isCaptureCandidate)
        // Earliest new candidate near focus (user bubble). Avoid max-by-length (AI replies are longer).
        guard let message = fresh.first else { return }
        cancelPendingScans()
        let app = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Cursor"
        onEvent?(CaptureEvent(kind: .type, appName: app, payload: message))
    }

    private func isVSCodeBasedFrontmost() -> Bool {
        let app = NSWorkspace.shared.frontmostApplication
        return VSCodeBasedIDEPolicy.matches(
            appName: app?.localizedName ?? "",
            bundleID: app?.bundleIdentifier
        )
    }

    private func targetApplication() -> NSRunningApplication? {
        let front = NSWorkspace.shared.frontmostApplication
        if let front, VSCodeBasedIDEPolicy.matches(
            appName: front.localizedName ?? "",
            bundleID: front.bundleIdentifier
        ) {
            return front
        }
        return NSWorkspace.shared.runningApplications.first {
            VSCodeBasedIDEPolicy.matches(
                appName: $0.localizedName ?? "",
                bundleID: $0.bundleIdentifier
            )
        }
    }

    private func collectCandidateTexts() -> [String] {
        guard let app = targetApplication() else { return [] }
        let appEl = AXUIElementCreateApplication(app.processIdentifier)

        var out: [String] = []
        var queue: [AXUIElement] = []

        // Prefer walking from the focused element (chat panel) before the whole app chrome.
        var focusedRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            appEl,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        ) == .success, let focusedRef {
            queue.append(focusedRef as! AXUIElement)
        }
        queue.append(appEl)

        var seenNodes = 0
        while !queue.isEmpty, seenNodes < 800, out.count < 120 {
            let el = queue.removeFirst()
            seenNodes += 1
            let role = stringAttr(el, kAXRoleAttribute as String)?.lowercased() ?? ""
            if role.contains("menubar") || role.contains("menu") { continue }

            if let value = stringAttr(el, kAXValueAttribute as String),
               role.contains("statictext") || role.contains("text"),
               CursorChatTextPolicy.isCaptureCandidate(value) {
                out.append(value)
            } else if let value = stringAttr(el, kAXValueAttribute as String),
                      CursorChatTextPolicy.isCaptureCandidate(value),
                      value.count >= 4 {
                out.append(value)
            }

            if let kids = children(of: el) {
                queue.append(contentsOf: kids.prefix(50))
            }
        }
        return out
    }

    private func children(of el: AXUIElement) -> [AXUIElement]? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &ref) == .success,
              let arr = ref as? [AXUIElement] else { return nil }
        return arr
    }

    private func stringAttr(_ el: AXUIElement, _ name: String) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, name as CFString, &ref) == .success, let ref else {
            return nil
        }
        if CFGetTypeID(ref) == CFStringGetTypeID() { return (ref as! CFString) as String }
        if let s = ref as? String { return s }
        if let a = ref as? NSAttributedString { return a.string }
        return nil
    }
}
