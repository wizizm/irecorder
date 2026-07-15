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

    /// Match neighboring menu bar icons (~18–22pt visual height).
    private static let pointSize: CGFloat = 20

    var body: some View {
        Group {
            if let image = Self.bundledMenuIcon() {
                Image(nsImage: image)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Self.pointSize, height: Self.pointSize)
                    .opacity(appState.isRecording ? 1.0 : 0.45)
            } else {
                Image(systemName: appState.isRecording ? "dot.circle.fill" : "pause.circle")
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .frame(width: Self.pointSize, height: Self.pointSize)
        .accessibilityLabel(appState.isRecording ? "iRecorder 记录中" : "iRecorder 已暂停")
    }

    private static func bundledMenuIcon() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        // Critical: AppKit draws status items by NSImage.size (points), not pixel count.
        image.size = NSSize(width: pointSize, height: pointSize)
        image.isTemplate = false
        return image
    }
}
