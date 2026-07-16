import AppKit
import Carbon
import Foundation
import IRecorderCore

/// Registers a system hot key via Carbon (works without relying on NSEvent global monitors).
final class HotKeyMonitor {
    var onTrigger: (() -> Void)?
    /// When true, ignore matches (used while the Settings shortcut recorder is active).
    var isSuspended = false

    private var spec: HotKeySpec
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private static let signature = OSType(0x69526331) // 'iRc1'
    private static let hotKeyID: UInt32 = 1

    init(spec: HotKeySpec) {
        self.spec = spec
    }

    func update(spec: HotKeySpec) {
        self.spec = spec
    }

    func start() {
        stop()
        guard spec.isEnabled else { return }
        installHandlerIfNeeded()
        var id = EventHotKeyID(signature: Self.signature, id: Self.hotKeyID)
        let status = RegisterEventHotKey(
            UInt32(spec.keyCode),
            spec.carbonModifiers,
            id,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            NSLog("iRecorder: RegisterEventHotKey failed status=%d keyCode=%u mods=%u", status, spec.keyCode, spec.carbonModifiers)
        }
    }

    func stop() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let callback: EventHandlerUPP = { _, event, userData in
            guard let userData, let event else { return noErr }
            let monitor = Unmanaged<HotKeyMonitor>.fromOpaque(userData).takeUnretainedValue()
            var hotKeyID = EventHotKeyID()
            let err = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard err == noErr,
                  hotKeyID.signature == HotKeyMonitor.signature,
                  hotKeyID.id == HotKeyMonitor.hotKeyID
            else {
                return noErr
            }
            guard !monitor.isSuspended else { return noErr }
            DispatchQueue.main.async {
                monitor.onTrigger?()
            }
            return noErr
        }
        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            userData,
            &handlerRef
        )
    }

    deinit {
        stop()
    }
}
