import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var retentionText = ""
    @State private var truncateKBText = ""

    private let labelWidth: CGFloat = 130

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                groupTitle("日志")

                HStack(alignment: .top, spacing: 12) {
                    Text("日志目录")
                        .frame(width: labelWidth, alignment: .leading)
                    Text(appState.logDirectoryPath)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(3)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("选择…") { appState.chooseLogDirectory() }
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

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("打字换行等待")
                        .frame(width: labelWidth, alignment: .leading)
                    Stepper(value: Binding(
                        get: { appState.typeLineIdleSeconds },
                        set: { appState.updateTypeLineIdleSeconds($0) }
                    ), in: 1...60) {
                        Text("\(appState.typeLineIdleSeconds) 秒")
                            .frame(minWidth: 48, alignment: .leading)
                    }
                }
                hintText("无键盘输入达上述秒数后写一行；按 Enter 立即换行")

                Divider()

                groupTitle("权限与启动")

                HStack(spacing: 12) {
                    Text(appState.accessibilityTrusted ? "辅助功能：已授权" : "辅助功能：未授权")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("打开设置") { appState.promptAccessibility() }
                }

                Toggle("登录时启动", isOn: Binding(
                    get: { appState.loginItemEnabled },
                    set: { appState.setLaunchAtLogin($0) }
                ))
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 520, idealWidth: 560, minHeight: 420)
        .onAppear {
            retentionText = String(appState.retentionDays)
            truncateKBText = String(appState.clipboardTruncateMaxKB)
        }
        .onDisappear {
            commitRetention()
            commitTruncate()
        }
    }

    private func groupTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
    }

    private func hintText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.leading, labelWidth + 12)
    }

    private func numberRow(
        title: String,
        text: Binding<String>,
        unit: String,
        hint: String,
        onCommit: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(title)
                    .frame(width: labelWidth, alignment: .leading)
                TextField("", text: text)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 88)
                    .multilineTextAlignment(.trailing)
                    .onSubmit(onCommit)
                Text(unit)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            hintText(hint)
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
