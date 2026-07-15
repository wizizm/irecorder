import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Form {
            Section("日志") {
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
                    Text(appState.retentionDays == 0
                         ? "保留天数：永不删除"
                         : "保留天数：\(appState.retentionDays) 天")
                }
            }
            Section("权限与启动") {
                HStack {
                    Text(appState.accessibilityTrusted ? "辅助功能：已授权" : "辅助功能：未授权")
                    Spacer()
                    Button("打开设置") { appState.promptAccessibility() }
                }
                Toggle("登录时启动", isOn: Binding(
                    get: { appState.loginItemEnabled },
                    set: { appState.setLaunchAtLogin($0) }
                ))
            }
        }
        .padding()
        .frame(width: 480, height: 240)
    }
}
