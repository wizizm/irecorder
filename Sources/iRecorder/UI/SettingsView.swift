import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var retentionText = ""
    @State private var truncateKBText = ""

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
                HStack {
                    Text("保留天数")
                    Spacer()
                    TextField("0=永不删除", text: $retentionText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                        .onSubmit { commitRetention() }
                    Text("天")
                        .foregroundStyle(.secondary)
                }
                Text("填 0 表示永不自动删除")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("复制/粘贴截断")
                    Spacer()
                    TextField("0=不截断", text: $truncateKBText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                        .onSubmit { commitTruncate() }
                    Text("KB")
                        .foregroundStyle(.secondary)
                }
                Text("填 0 表示不截断")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .frame(width: 560, height: 380)
        .onAppear {
            retentionText = String(appState.retentionDays)
            truncateKBText = String(appState.clipboardTruncateMaxKB)
        }
        .onDisappear {
            commitRetention()
            commitTruncate()
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
