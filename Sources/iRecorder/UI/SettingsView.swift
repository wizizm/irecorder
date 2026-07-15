import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Form {
            Section {
                HStack {
                    Text(appState.logDirectoryPath)
                        .lineLimit(2)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Button("选择…") { appState.chooseLogDirectory() }
                }
                Stepper(value: Binding(
                    get: { appState.retentionDays },
                    set: { appState.updateRetentionDays($0) }
                ), in: 0...3650) {
                    Text(retentionLabel)
                }
                Stepper(value: Binding(
                    get: { appState.clipboardTruncateMaxKB },
                    set: { appState.updateClipboardTruncateMaxKB($0) }
                ), in: 0...10_000) {
                    Text(truncateLabel)
                }
                Stepper(value: Binding(
                    get: { appState.typeLineIdleSeconds },
                    set: { appState.updateTypeLineIdleSeconds($0) }
                ), in: 1...60) {
                    Text("打字换行等待：\(appState.typeLineIdleSeconds) 秒")
                }
                Text("无键盘输入达上述秒数后写一行；按 Enter 立即换行")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("日志")
            }

            Section {
                HStack {
                    Text(appState.accessibilityTrusted ? "辅助功能：已授权" : "辅助功能：未授权")
                    Spacer()
                    Button("打开设置") { appState.promptAccessibility() }
                }
                Toggle("登录时启动", isOn: Binding(
                    get: { appState.loginItemEnabled },
                    set: { appState.setLaunchAtLogin($0) }
                ))
            } header: {
                Text("权限与启动")
            }
        }
        .padding()
        .frame(width: 560, height: 340)
    }

    private var retentionLabel: String {
        appState.retentionDays == 0
            ? "保留天数：永不删除"
            : "保留天数：\(appState.retentionDays) 天"
    }

    private var truncateLabel: String {
        appState.clipboardTruncateMaxKB == 0
            ? "复制/粘贴截断：不截断"
            : "复制/粘贴截断：\(appState.clipboardTruncateMaxKB) KB"
    }
}
