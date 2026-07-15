import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Button(appState.isRecording ? "暂停记录" : "继续记录") {
            appState.toggleRecording()
        }
        Divider()
        Button("打开今日日志") { appState.openTodayLog() }
        Button("打开日志文件夹") { appState.openLogFolder() }
        Divider()
        if !appState.accessibilityTrusted {
            Button("授予辅助功能权限…") { appState.promptAccessibility() }
        }
        SettingsLink {
            Text("设置…")
        }
        Divider()
        Button("退出") {
            NSApplication.shared.terminate(nil)
        }
    }
}

struct MenuBarLabel: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Image(systemName: appState.isRecording ? "dot.circle.fill" : "pause.circle")
            .symbolRenderingMode(.hierarchical)
            .accessibilityLabel(appState.isRecording ? "iRecorder 记录中" : "iRecorder 已暂停")
    }
}
