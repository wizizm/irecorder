import AppKit
import ApplicationServices
import Foundation

/// One-shot AX probe for apps like Cursor that often lack a simple focused AXValue.
enum AXFocusDumper {
    static func runAndExit() {
        fputs(dumpReport() + "\n", stdout)
        fflush(stdout)
        exit(0)
    }

    static func dumpReport() -> String {
        var lines: [String] = []
        let trusted = AXIsProcessTrusted()
        lines.append("trusted=\(trusted ? 1 : 0)")
        let front = NSWorkspace.shared.frontmostApplication
        lines.append("frontmost=\(front?.localizedName ?? "?") pid=\(front?.processIdentifier ?? -1)")
        let cursor = NSWorkspace.shared.runningApplications.first {
            $0.localizedName == "Cursor" || $0.bundleIdentifier?.contains("cursor") == true
        }
        if let cursor {
            lines.append("cursorPid=\(cursor.processIdentifier) active=\(cursor.isActive ? 1 : 0)")
        }
        guard trusted else { return lines.joined(separator: "\n") }

        // Prefer Cursor if running (CLI launch may steal frontmost); else frontmost app.
        let target = cursor ?? front
        if let pid = target?.processIdentifier {
            lines.append("probeApp=\(target?.localizedName ?? "?") pid=\(pid)")
            let appEl = AXUIElementCreateApplication(pid)
            var appFocused: CFTypeRef?
            if AXUIElementCopyAttributeValue(
                appEl,
                kAXFocusedUIElementAttribute as CFString,
                &appFocused
            ) == .success, let appFocused {
                let focused = appFocused as! AXUIElement
                lines.append(contentsOf: describe(focused, label: "appFocused", depth: 0, includeAttrs: true))
                appendContext(focused, into: &lines)
                return lines.joined(separator: "\n")
            } else {
                lines.append("appFocused=nil")
                // Fall back: scan main windows for text-bearing nodes.
                if let windows = children(of: appEl) {
                    lines.append("appTopChildren=\(windows.count)")
                    for (i, win) in windows.prefix(5).enumerated() {
                        lines.append(contentsOf: describe(win, label: "top\(i)", depth: 0, includeAttrs: false))
                        // Deep-scan each standard window for editor text.
                        let deep = findStringNodes(
                            from: win,
                            maxNodes: 400,
                            maxHits: 25,
                            minLength: 8,
                            skipMenuRoles: true
                        )
                        lines.append("window\(i)DeepHits=\(deep.count)")
                        for (j, hit) in deep.enumerated() {
                            let preview = hit.value.count <= 100 ? hit.value : String(hit.value.prefix(80)) + "…"
                            lines.append(
                                "w\(i)h\(j) role=\(hit.role) via=\(hit.attr) len=\(hit.value.count) text=\(preview.debugDescription)"
                            )
                        }
                    }
                    let hits = findStringNodes(from: appEl, maxNodes: 120, maxHits: 15)
                    lines.append("stringHits=\(hits.count)")
                    for (i, hit) in hits.enumerated() {
                        let preview = hit.value.count <= 100 ? hit.value : String(hit.value.prefix(80)) + "…"
                        lines.append("hit\(i) role=\(hit.role) via=\(hit.attr) len=\(hit.value.count) text=\(preview.debugDescription)")
                    }
                }
            }
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        ) == .success, let focusedRef else {
            lines.append("systemFocused=nil")
            return lines.joined(separator: "\n")
        }
        let focused = focusedRef as! AXUIElement
        lines.append(contentsOf: describe(focused, label: "systemFocused", depth: 0, includeAttrs: true))
        appendContext(focused, into: &lines)
        return lines.joined(separator: "\n")
    }

    private static func appendContext(_ focused: AXUIElement, into lines: inout [String]) {
        var current: AXUIElement? = focused
        for i in 1...5 {
            guard let el = current, let parent = parent(of: el) else { break }
            lines.append(contentsOf: describe(parent, label: "parent\(i)", depth: i, includeAttrs: false))
            current = parent
        }

        if let kids = children(of: focused) {
            lines.append("focusedChildCount=\(kids.count)")
            for (idx, child) in kids.prefix(15).enumerated() {
                lines.append(contentsOf: describe(child, label: "child\(idx)", depth: 1, includeAttrs: false))
                // Descend one more level — Cursor chat input nests editable nodes.
                if let grand = children(of: child) {
                    for (j, g) in grand.prefix(10).enumerated() {
                        lines.append(contentsOf: describe(g, label: "child\(idx).\(j)", depth: 2, includeAttrs: true))
                        if let gg = children(of: g) {
                            for (k, x) in gg.prefix(8).enumerated() {
                                lines.append(contentsOf: describe(x, label: "child\(idx).\(j).\(k)", depth: 3, includeAttrs: false))
                            }
                        }
                    }
                }
            }
        }

        let hits = findStringNodes(from: focused, maxNodes: 80, maxHits: 12)
        lines.append("stringHits=\(hits.count)")
        for (i, hit) in hits.enumerated() {
            let preview = hit.value.count <= 100 ? hit.value : String(hit.value.prefix(80)) + "…"
            lines.append("hit\(i) role=\(hit.role) via=\(hit.attr) len=\(hit.value.count) text=\(preview.debugDescription)")
        }
    }

    private struct StringHit {
        let role: String
        let attr: String
        let value: String
    }

    private static func findStringNodes(
        from root: AXUIElement,
        maxNodes: Int,
        maxHits: Int,
        minLength: Int = 2,
        skipMenuRoles: Bool = false
    ) -> [StringHit] {
        var hits: [StringHit] = []
        var queue: [AXUIElement] = [root]
        var seen = 0
        while !queue.isEmpty, seen < maxNodes, hits.count < maxHits {
            let el = queue.removeFirst()
            seen += 1
            let role = stringAttribute(el, kAXRoleAttribute as String) ?? "?"
            let roleLower = role.lowercased()
            if skipMenuRoles,
               roleLower.contains("menu") || roleLower.contains("menubar") || roleLower == "axbutton" {
                continue
            }
            for attr in [
                kAXValueAttribute as String,
                "AXSelectedText",
                "AXText",
                kAXDescriptionAttribute as String,
            ] {
                if let value = stringValue(el, attr), value.count >= minLength {
                    hits.append(StringHit(role: role, attr: attr, value: value))
                    break
                }
            }
            if let kids = children(of: el) {
                queue.append(contentsOf: kids.prefix(40))
            }
        }
        return hits
    }

    private static func describe(
        _ el: AXUIElement,
        label: String,
        depth: Int,
        includeAttrs: Bool
    ) -> [String] {
        let pad = String(repeating: "  ", count: depth)
        let role = stringAttribute(el, kAXRoleAttribute as String) ?? "?"
        let sub = stringAttribute(el, kAXSubroleAttribute as String) ?? ""
        let value = stringValue(el, kAXValueAttribute as String)
        let selected = stringValue(el, "AXSelectedText")
        let text = stringValue(el, "AXText")
        var lines = [
            "\(pad)\(label) role=\(role) sub=\(sub) valueLen=\(value?.count ?? -1) selLen=\(selected?.count ?? -1) axTextLen=\(text?.count ?? -1)"
        ]
        if let n = numberAttribute(el, kAXNumberOfCharactersAttribute as String) {
            lines.append("\(pad)  numberOfCharacters=\(n)")
        }
        if let placeholder = stringValue(el, kAXPlaceholderValueAttribute as String), !placeholder.isEmpty {
            lines.append("\(pad)  placeholder=\(placeholder.debugDescription)")
        }
        if let dom = stringValue(el, "AXDOMClassList"), !dom.isEmpty {
            lines.append("\(pad)  domClass=\(dom.prefix(120).debugDescription)")
        }
        if let desc = stringValue(el, kAXDescriptionAttribute as String), !desc.isEmpty {
            lines.append("\(pad)  desc=\(desc.prefix(100).debugDescription)")
        }
        if includeAttrs {
            lines.append("\(pad)  attrs=\(attributeNames(el).joined(separator: ","))")
        }
        if let value, !value.isEmpty {
            let preview = value.count <= 120 ? value : String(value.prefix(80)) + "…"
            lines.append("\(pad)  value=\(preview.debugDescription)")
        }
        if let selected, !selected.isEmpty {
            let preview = selected.count <= 80 ? selected : String(selected.prefix(60)) + "…"
            lines.append("\(pad)  selected=\(preview.debugDescription)")
        }
        if let ranged = parameterizedString(el) {
            let preview = ranged.count <= 120 ? ranged : String(ranged.prefix(80)) + "…"
            lines.append("\(pad)  rangeText=\(preview.debugDescription)")
        }
        return lines
    }

    /// Chromium contenteditable often exposes text via parameterized range APIs, not AXValue.
    private static func parameterizedString(_ el: AXUIElement) -> String? {
        var countRef: CFTypeRef?
        var length = 0
        if AXUIElementCopyAttributeValue(el, kAXNumberOfCharactersAttribute as CFString, &countRef) == .success,
           let n = countRef as? NSNumber {
            length = n.intValue
        }
        if length <= 0 { length = 4000 }

        var range = CFRange(location: 0, length: length)
        guard let axRange = AXValueCreate(.cfRange, &range) else { return nil }

        for attr in [
            kAXStringForRangeParameterizedAttribute as String,
            kAXAttributedStringForRangeParameterizedAttribute as String,
        ] {
            var ref: CFTypeRef?
            let err = AXUIElementCopyParameterizedAttributeValue(
                el,
                attr as CFString,
                axRange,
                &ref
            )
            guard err == .success, let ref else { continue }
            if CFGetTypeID(ref) == CFStringGetTypeID() {
                let s = (ref as! CFString) as String
                if !s.isEmpty { return s }
            }
            if let s = ref as? String, !s.isEmpty { return s }
            if let a = ref as? NSAttributedString, !a.string.isEmpty { return a.string }
        }
        return nil
    }

    private static func parent(of el: AXUIElement) -> AXUIElement? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXParentAttribute as CFString, &ref) == .success,
              let ref else { return nil }
        return (ref as! AXUIElement)
    }

    private static func children(of el: AXUIElement) -> [AXUIElement]? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &ref) == .success,
              let arr = ref as? [AXUIElement] else { return nil }
        return arr
    }

    private static func attributeNames(_ el: AXUIElement) -> [String] {
        var ref: CFArray?
        guard AXUIElementCopyAttributeNames(el, &ref) == .success, let arr = ref as? [String] else {
            return []
        }
        return arr.sorted()
    }

    private static func numberAttribute(_ el: AXUIElement, _ name: String) -> Int? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, name as CFString, &ref) == .success,
              let n = ref as? NSNumber else { return nil }
        return n.intValue
    }

    private static func stringAttribute(_ el: AXUIElement, _ name: String) -> String? {
        stringValue(el, name)
    }

    private static func stringValue(_ el: AXUIElement, _ name: String) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, name as CFString, &ref) == .success, let ref else {
            return nil
        }
        let typeID = CFGetTypeID(ref)
        if typeID == CFStringGetTypeID() { return (ref as! CFString) as String }
        if let s = ref as? String { return s }
        if let a = ref as? NSAttributedString { return a.string }
        return nil
    }
}
