import AppKit
import ApplicationServices
import Foundation

func axString(_ el: AXUIElement, _ attr: String) -> String? {
    var ref: CFTypeRef?
    guard AXUIElementCopyAttributeValue(el, attr as CFString, &ref) == .success, let ref else { return nil }
    if CFGetTypeID(ref) == CFStringGetTypeID() { return (ref as! CFString) as String }
    if let s = ref as? String { return s }
    if let a = ref as? NSAttributedString { return a.string }
    return String(describing: ref)
}

func axNames(_ el: AXUIElement) -> [String] {
    var ref: CFArray?
    guard AXUIElementCopyAttributeNames(el, &ref) == .success, let arr = ref as? [String] else { return [] }
    return arr
}

func dump(_ el: AXUIElement, label: String, depth: Int = 0) {
    let pad = String(repeating: "  ", count: depth)
    let role = axString(el, kAXRoleAttribute as String) ?? "?"
    let sub = axString(el, kAXSubroleAttribute as String) ?? ""
    let title = axString(el, kAXTitleAttribute as String) ?? ""
    let desc = axString(el, kAXDescriptionAttribute as String) ?? ""
    let value = axString(el, kAXValueAttribute as String)
    let selected = axString(el, "AXSelectedText")
    let valueLen = value?.count ?? -1
    let selLen = selected?.count ?? -1
    print("\(pad)\(label) role=\(role) sub=\(sub) title=\(title.prefix(40)) desc=\(desc.prefix(40)) valueLen=\(valueLen) selLen=\(selLen)")
    if let value, valueLen > 0, valueLen <= 120 {
        print("\(pad)  value=\(value.debugDescription)")
    } else if let value, valueLen > 120 {
        print("\(pad)  valuePrefix=\(value.prefix(80).debugDescription)…")
    }
    if let selected, selLen > 0, selLen <= 80 {
        print("\(pad)  selected=\(selected.debugDescription)")
    }
    if depth == 0 {
        let names = axNames(el).sorted()
        print("\(pad)  attrs=\(names.joined(separator: ","))")
    }
}

guard AXIsProcessTrusted() else {
    fputs("AX not trusted for this process\n", stderr)
    exit(1)
}

let app = NSWorkspace.shared.frontmostApplication
print("frontmost=\(app?.localizedName ?? "?") pid=\(app?.processIdentifier ?? -1)")

let system = AXUIElementCreateSystemWide()
var focusedRef: CFTypeRef?
guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
      let focusedRef else {
    fputs("no focused element\n", stderr)
    exit(2)
}
let focused = focusedRef as! AXUIElement
dump(focused, label: "focused")

// Parent chain
var current: AXUIElement? = focused
for i in 1...6 {
    var pref: CFTypeRef?
    guard let el = current,
          AXUIElementCopyAttributeValue(el, kAXParentAttribute as CFString, &pref) == .success,
          let pref else { break }
    let parent = pref as! AXUIElement
    dump(parent, label: "parent\(i)", depth: i)
    current = parent
}

// Children of focused (shallow)
var childrenRef: CFTypeRef?
if AXUIElementCopyAttributeValue(focused, kAXChildrenAttribute as CFString, &childrenRef) == .success,
   let children = childrenRef as? [AXUIElement] {
    print("focused children count=\(children.count)")
    for (i, child) in children.prefix(12).enumerated() {
        dump(child, label: "child\(i)", depth: 1)
    }
}

// Also try AXText / AXValueDescription style attrs if present
for attr in ["AXText", "AXValueDescription", "AXDocument", "AXContents", "AXSharedTextUIElement"] {
    if let s = axString(focused, attr) {
        let shown = s.count <= 100 ? s.debugDescription : String(s.prefix(80)).debugDescription + "…"
        print("extra \(attr)=\(shown)")
    }
}
