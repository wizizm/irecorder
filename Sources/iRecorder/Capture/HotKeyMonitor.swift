import AppKit
import Carbon
import Foundation
import IRecorderCore

/// Registers system hot keys via Carbon (works without relying on NSEvent global monitors).
/// Supports multiple bindings dispatched by fixed `EventHotKeyID.id` values.
final class HotKeyMonitor {
    /// When true, ignore matches (used while the Settings shortcut recorder is active).
    var isSuspended = false

    private struct Binding {
        var spec: HotKeySpec
        var onTrigger: () -> Void
        var hotKeyRef: EventHotKeyRef?
    }

    private var bindings: [UInt32: Binding] = [:]
    private var handlerRef: EventHandlerRef?

    private static let signature = OSType(0x69526331) // 'iRc1'

    func setBinding(id: UInt32, spec: HotKeySpec, onTrigger: @escaping () -> Void) {
        if let existing = bindings[id]?.hotKeyRef {
            UnregisterEventHotKey(existing)
        }
        bindings[id] = Binding(spec: spec, onTrigger: onTrigger, hotKeyRef: nil)
    }

    func removeBinding(id: UInt32) {
        if let ref = bindings[id]?.hotKeyRef {
            UnregisterEventHotKey(ref)
        }
        bindings.removeValue(forKey: id)
    }

    /// Re-register all enabled specs. Disabled bindings stay stored but unregistered.
    func start() {
        stopRegistrations()
        installHandlerIfNeeded()
        for id in bindings.keys.sorted() {
            guard var binding = bindings[id], binding.spec.isEnabled else { continue }
            let eventID = EventHotKeyID(signature: Self.signature, id: id)
            var hotKeyRef: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(binding.spec.keyCode),
                binding.spec.carbonModifiers,
                eventID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )
            if status != noErr {
                NSLog(
                    "iRecorder: RegisterEventHotKey failed status=%d id=%u keyCode=%u mods=%u",
                    status, id, binding.spec.keyCode, binding.spec.carbonModifiers
                )
            }
            binding.hotKeyRef = hotKeyRef
            bindings[id] = binding
        }
    }

    func stop() {
        stopRegistrations()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }

    private func stopRegistrations() {
        for id in Array(bindings.keys) {
            guard var binding = bindings[id] else { continue }
            if let ref = binding.hotKeyRef {
                UnregisterEventHotKey(ref)
                binding.hotKeyRef = nil
                bindings[id] = binding
            }
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
                  let binding = monitor.bindings[hotKeyID.id]
            else {
                return noErr
            }
            guard !monitor.isSuspended else { return noErr }
            DispatchQueue.main.async {
                binding.onTrigger()
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
