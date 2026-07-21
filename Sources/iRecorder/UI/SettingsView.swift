import AppKit
import IRecorderCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var retentionText = ""
    @State private var truncateKBText = ""
    @State private var isRecordingHotKey = false
    @State private var isRecordingPasteHistoryHotKey = false

    private let labelWidth: CGFloat = 120

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            groupTitle("日志")

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("日志目录")
                    Spacer(minLength: 8)
                    Button("选择…") { appState.chooseLogDirectory() }
                }
                Text(appState.logDirectoryPath)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(2)
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            numberRow(
                title: "保留天数",
                text: $retentionText,
                unit: "天",
                hint: "填 0 表示永不自动删除",
                onCommit: commitRetention
            )

            numberRow(
                title: "复制/粘贴截断",
                text: $truncateKBText,
                unit: "KB",
                hint: "填 0 表示不截断",
                onCommit: commitTruncate
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text("打字换行等待")
                        .frame(width: labelWidth, alignment: .leading)
                    Stepper(value: Binding(
                        get: { appState.typeLineIdleSeconds },
                        set: { appState.updateTypeLineIdleSeconds($0) }
                    ), in: 1...60) {
                        Text("\(appState.typeLineIdleSeconds) 秒")
                            .frame(minWidth: 40, alignment: .leading)
                    }
                }
                Text("无键盘输入达上述秒数后写一行（Enter 不换行，避免中文上屏误分）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text("打开今日日志")
                        .frame(width: labelWidth, alignment: .leading)
                    Toggle("", isOn: Binding(
                        get: { appState.openTodayLogHotKey.isEnabled },
                        set: { enabled in
                            if enabled {
                                if appState.openTodayLogHotKey.sharesChord(with: appState.pasteHistoryHotKey),
                                   appState.pasteHistoryHotKey.isEnabled {
                                    beginOpenTodayLogHotKeyCapture()
                                    return
                                }
                                var key = appState.openTodayLogHotKey
                                key.isEnabled = true
                                appState.updateOpenTodayLogHotKey(key)
                            } else {
                                var key = appState.openTodayLogHotKey
                                key.isEnabled = false
                                appState.updateOpenTodayLogHotKey(key)
                            }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                    Button(isRecordingHotKey ? "按下快捷键…" : appState.openTodayLogHotKey.displayString) {
                        if isRecordingHotKey {
                            isRecordingHotKey = false
                            syncHotKeySuspend()
                        } else {
                            beginOpenTodayLogHotKeyCapture()
                        }
                    }
                    .frame(minWidth: 88)
                    Button("恢复默认") {
                        isRecordingHotKey = false
                        syncHotKeySuspend()
                        appState.updateOpenTodayLogHotKey(.defaultOpenTodayLog)
                    }
                }
                Text("全局快捷键打开今日日志（需辅助功能权限）；默认 ⇧⌘L")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text("粘贴历史")
                        .frame(width: labelWidth, alignment: .leading)
                    Toggle("", isOn: Binding(
                        get: { appState.pasteHistoryHotKey.isEnabled },
                        set: { enabled in
                            if enabled {
                                // Default placeholder shares ⌘⇧L with open-today — force a unique chord first.
                                if appState.pasteHistoryHotKey.sharesChord(with: appState.openTodayLogHotKey) {
                                    beginPasteHistoryHotKeyCapture()
                                    return
                                }
                                var key = appState.pasteHistoryHotKey
                                key.isEnabled = true
                                appState.updatePasteHistoryHotKey(key)
                            } else {
                                var key = appState.pasteHistoryHotKey
                                key.isEnabled = false
                                appState.updatePasteHistoryHotKey(key)
                            }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                    Button(isRecordingPasteHistoryHotKey ? "按下快捷键…" : appState.pasteHistoryHotKey.displayString) {
                        if isRecordingPasteHistoryHotKey {
                            isRecordingPasteHistoryHotKey = false
                            syncHotKeySuspend()
                        } else {
                            beginPasteHistoryHotKeyCapture()
                        }
                    }
                    .frame(minWidth: 88)
                    Button("清除") {
                        isRecordingPasteHistoryHotKey = false
                        syncHotKeySuspend()
                        appState.updatePasteHistoryHotKey(.defaultPasteHistory)
                    }
                }
                Text("全局快捷键打开粘贴历史（默认关闭；启用时若与打开今日日志冲突会先录制新快捷键）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .onExitCommand {
                if isRecordingHotKey || isRecordingPasteHistoryHotKey {
                    isRecordingHotKey = false
                    isRecordingPasteHistoryHotKey = false
                    appState.setHotKeyRecordingSuspended(false)
                }
            }

            Divider().padding(.vertical, 4)

            groupTitle("权限与启动")

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.accessibilityTrusted ? "辅助功能：已授权" : "辅助功能：未生效（打字无法记录）")
                        .foregroundStyle(appState.accessibilityTrusted ? Color.primary : Color.red)
                    if !appState.accessibilityTrusted {
                        Text("请勾选「/Applications/iRecorder.app」，不要选 .build 里的旧进程。勾选后必须点「退出并重开」。复制不依赖此权限，所以复制仍可能正常。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 6) {
                    Button("打开设置") { appState.promptAccessibility() }
                    if !appState.accessibilityTrusted {
                        Button("退出并重开") { appState.relaunchToApplyAccessibility() }
                    }
                }
            }

            Toggle("登录时启动", isOn: Binding(
                get: { appState.loginItemEnabled },
                set: { appState.setLaunchAtLogin($0) }
            ))
        }
        .padding(20)
        .frame(width: 400, height: 620)
        .background(
            ZStack {
                HotKeyCaptureView(isActive: $isRecordingHotKey) { spec in
                    if spec.sharesChord(with: appState.pasteHistoryHotKey), appState.pasteHistoryHotKey.isEnabled {
                        DispatchQueue.main.async { isRecordingHotKey = true }
                        return
                    }
                    appState.updateOpenTodayLogHotKey(spec)
                    isRecordingHotKey = false
                    syncHotKeySuspend()
                }
                HotKeyCaptureView(isActive: $isRecordingPasteHistoryHotKey) { spec in
                    if spec.sharesChord(with: appState.openTodayLogHotKey) {
                        DispatchQueue.main.async { isRecordingPasteHistoryHotKey = true }
                        return
                    }
                    appState.updatePasteHistoryHotKey(spec)
                    isRecordingPasteHistoryHotKey = false
                    syncHotKeySuspend()
                }
            }
        )
        .onAppear {
            retentionText = String(appState.retentionDays)
            truncateKBText = String(appState.clipboardTruncateMaxKB)
            appState.refreshAccessibility()
        }
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
            appState.refreshAccessibility()
        }
        .onDisappear {
            commitRetention()
            commitTruncate()
            isRecordingHotKey = false
            isRecordingPasteHistoryHotKey = false
            appState.setHotKeyRecordingSuspended(false)
        }
        .onChange(of: isRecordingHotKey) { _, recording in
            if recording { isRecordingPasteHistoryHotKey = false }
            syncHotKeySuspend()
        }
        .onChange(of: isRecordingPasteHistoryHotKey) { _, recording in
            if recording { isRecordingHotKey = false }
            syncHotKeySuspend()
        }
    }

    private func beginOpenTodayLogHotKeyCapture() {
        isRecordingPasteHistoryHotKey = false
        isRecordingHotKey = true
        appState.setHotKeyRecordingSuspended(true)
    }

    private func beginPasteHistoryHotKeyCapture() {
        isRecordingHotKey = false
        isRecordingPasteHistoryHotKey = true
        appState.setHotKeyRecordingSuspended(true)
    }

    private func syncHotKeySuspend() {
        appState.setHotKeyRecordingSuspended(isRecordingHotKey || isRecordingPasteHistoryHotKey)
    }

    private func groupTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private func numberRow(
        title: String,
        text: Binding<String>,
        unit: String,
        hint: String,
        onCommit: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text(title)
                    .frame(width: labelWidth, alignment: .leading)
                TextField("", text: text)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 72)
                    .multilineTextAlignment(.trailing)
                    .onSubmit(onCommit)
                Text(unit)
                    .foregroundStyle(.secondary)
            }
            Text(hint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func commitRetention() {
        let trimmed = retentionText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value = Int(trimmed), value >= 0 {
            appState.updateRetentionDays(value)
        }
        retentionText = String(appState.retentionDays)
    }

    private func commitTruncate() {
        let trimmed = truncateKBText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value = Int(trimmed), value >= 0 {
            appState.updateClipboardTruncateMaxKB(value)
        }
        truncateKBText = String(appState.clipboardTruncateMaxKB)
    }
}
