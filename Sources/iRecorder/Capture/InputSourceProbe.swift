import Carbon
import Foundation

enum InputSourceProbe {
    /// True when the current keyboard input source's languages include Chinese.
    static func isChineseIMEActive() -> Bool {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return false
        }
        guard let raw = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else {
            return false
        }
        let languages = Unmanaged<CFArray>.fromOpaque(raw).takeUnretainedValue() as NSArray
        for case let lang as String in languages {
            if lang.hasPrefix("zh") { return true }
        }
        return false
    }
}
