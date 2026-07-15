import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var retentionText = ""
    @State private var truncateKBText = ""

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
                Text("无键盘输入达上述秒数后写一行；按 Enter 立即换行")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().padding(.vertical, 4)

            groupTitle("权限与启动")

            HStack {
                Text(appState.accessibilityTrusted ? "辅助功能：已授权" : "辅助功能：未授权")
                Spacer(minLength: 8)
                Button("打开设置") { appState.promptAccessibility() }
            }

            Toggle("登录时启动", isOn: Binding(
                get: { appState.loginItemEnabled },
                set: { appState.setLaunchAtLogin($0) }
            ))
        }
        .padding(20)
        .frame(width: 400, height: 480)
        .onAppear {
            retentionText = String(appState.retentionDays)
            truncateKBText = String(appState.clipboardTruncateMaxKB)
            appState.refreshAccessibility()
        }
        .onDisappear {
            commitRetention()
            commitTruncate()
        }
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
