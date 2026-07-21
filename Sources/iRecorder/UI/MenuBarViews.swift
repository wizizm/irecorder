import AppKit
import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var appState: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button(appState.isRecording ? "暂停记录" : "继续记录") {
            appState.toggleRecording()
        }
        Divider()
        Button("打开今日日志") { appState.openTodayLog() }
        Button("粘贴历史…") { appState.showPasteHistory() }
        Button("打开日志文件夹") { appState.openLogFolder() }
        Divider()
        if !appState.accessibilityTrusted {
            Button("授予辅助功能权限…") { appState.promptAccessibility() }
        }
        Button("设置…") {
            // openSettings: first-time create; bringSettingsForward: already open but obscured.
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
            appState.bringSettingsWindowForward()
        }
        Divider()
        Button("退出") {
            NSApplication.shared.terminate(nil)
        }
    }
}

struct MenuBarLabel: View {
    @ObservedObject var appState: AppState

    /// Native status items sit near 16–18pt. Asset must be exactly 2× pixels (36×36).
    private static let pointSize: CGFloat = 18

    var body: some View {
        Group {
            if let image = Self.bundledMenuIcon() {
                Image(nsImage: image)
                    .renderingMode(.original)
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
              let source = NSImage(contentsOf: url),
              let cgImage = source.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }

        // Tag the bitmap as @2x: pixel size / point size == 2. Oversized @4x bitmaps look soft on Retina.
        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.size = NSSize(width: pointSize, height: pointSize)
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize))
        image.addRepresentation(rep)
        image.isTemplate = false
        return image
    }
}
