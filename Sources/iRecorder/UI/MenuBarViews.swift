import AppKit
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
        Group {
            if let image = Self.bundledMenuIcon() {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .opacity(appState.isRecording ? 1.0 : 0.45)
            } else {
                Image(systemName: appState.isRecording ? "dot.circle.fill" : "pause.circle")
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .accessibilityLabel(appState.isRecording ? "iRecorder 记录中" : "iRecorder 已暂停")
    }

    private static func bundledMenuIcon() -> NSImage? {
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = false
            return image
        }
        return nil
    }
}
