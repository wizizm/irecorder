import AppKit
import IRecorderCore
import SwiftUI

// MARK: - SwiftUI content

struct PasteHistoryView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case today = "今日"
        case search = "搜索"
        var id: String { rawValue }
    }

    let logDirectory: URL
    let accessibilityTrusted: Bool
    let onSelect: (PasteHistoryItem) -> Void
    let onDismiss: () -> Void

    @State private var tab: Tab = .today
    @State private var todayItems: [PasteHistoryItem] = []
    @State private var searchQuery = ""
    @State private var searchItems: [PasteHistoryItem] = []
    @State private var searchGeneration = 0
    @State private var todayGeneration = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            if tab == .search {
                TextField("搜索内容或应用名…", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }

            listContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !accessibilityTrusted {
                Text("粘贴到其他 App 需要辅助功能权限")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
        .frame(minWidth: 420, minHeight: 360)
        .onAppear { reloadToday() }
        .onChange(of: tab) { _, newTab in
            if newTab == .today {
                reloadToday()
            }
        }
        .onChange(of: searchQuery) { _, newValue in
            scheduleSearch(newValue)
        }
        .onExitCommand { onDismiss() }
    }

    @ViewBuilder
    private var listContent: some View {
        switch tab {
        case .today:
            if todayItems.isEmpty {
                emptyHint("今日暂无复制记录")
            } else {
                itemList(todayItems, showKind: false)
            }
        case .search:
            let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                emptyHint("输入关键词搜索历史")
            } else if searchItems.isEmpty {
                emptyHint("未找到匹配记录")
            } else {
                itemList(searchItems, showKind: true)
            }
        }
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func itemList(_ items: [PasteHistoryItem], showKind: Bool) -> some View {
        List(items.indices, id: \.self) { index in
            let item = items[index]
            Button {
                onSelect(item)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(Self.shortTime(item.date))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .leading)
                    if showKind {
                        Text(Self.kindBadge(item.kind))
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    Text(item.appName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: 72, alignment: .leading)
                    Text(Self.preview(item.payload))
                        .font(.body)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .listStyle(.inset)
    }

    private func reloadToday() {
        todayGeneration += 1
        let generation = todayGeneration
        let directory = logDirectory
        DispatchQueue.global(qos: .userInitiated).async {
            let items = LogHistoryQuery.todayUniqueCopies(directory: directory)
            DispatchQueue.main.async {
                guard generation == todayGeneration else { return }
                todayItems = items
            }
        }
    }

    private func scheduleSearch(_ query: String) {
        searchGeneration += 1
        let generation = searchGeneration
        let directory = logDirectory
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            searchItems = []
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard generation == searchGeneration else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                let items = LogHistoryQuery.search(directory: directory, query: query)
                DispatchQueue.main.async {
                    guard generation == searchGeneration else { return }
                    searchItems = items
                }
            }
        }
    }

    private static let shortTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f
    }()

    static func shortTime(_ date: Date) -> String {
        shortTimeFormatter.string(from: date)
    }

    static func preview(_ payload: String, maxChars: Int = 120) -> String {
        let firstLine = payload.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            .first.map(String.init) ?? payload
        if firstLine.count <= maxChars { return firstLine }
        return String(firstLine.prefix(maxChars)) + "…"
    }

    static func kindBadge(_ kind: CaptureKind) -> String {
        kind.rawValue
    }
}

// MARK: - NSPanel controller

@MainActor
final class PasteHistoryPanelController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var onSelect: ((PasteHistoryItem) -> Void)?
    private var onDismiss: (() -> Void)?
    private var isDismissing = false
    private var escapeMonitor: Any?

    func show(
        logDirectory: URL,
        onSelect: @escaping (PasteHistoryItem) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        // Re-entrant: drop existing panel without firing previous onDismiss
        hide()

        self.onSelect = onSelect
        self.onDismiss = onDismiss
        isDismissing = false

        let trusted = AXWatcher.isTrusted(prompt: false)
        let root = PasteHistoryView(
            logDirectory: logDirectory,
            accessibilityTrusted: trusted,
            onSelect: { [weak self] item in
                self?.handleSelect(item)
            },
            onDismiss: { [weak self] in
                self?.dismissOnly()
            }
        )

        let hosting = NSHostingController(rootView: root)
        let size = NSSize(width: 480, height: 420)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "粘贴历史"
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.contentViewController = hosting
        panel.delegate = self
        panel.setContentSize(size)
        placeUpperCenter(panel)
        panel.orderFrontRegardless()
        // nonactivatingPanel + orderFrontRegardless does not key the panel,
        // so SwiftUI onExitCommand never runs — make key and monitor Esc.
        panel.makeKey()
        installEscapeMonitor()
        self.panel = panel
    }

    func hide() {
        removeEscapeMonitor()
        isDismissing = true
        panel?.orderOut(nil)
        panel = nil
        onSelect = nil
        onDismiss = nil
        isDismissing = false
    }

    private func installEscapeMonitor() {
        removeEscapeMonitor()
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            self?.dismissOnly()
            return nil
        }
    }

    private func removeEscapeMonitor() {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
    }

    private func handleSelect(_ item: PasteHistoryItem) {
        let select = onSelect
        hide()
        select?(item)
    }

    private func dismissOnly() {
        let dismiss = onDismiss
        hide()
        dismiss?()
    }

    private func placeUpperCenter(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else {
            panel.center()
            return
        }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let topMargin: CGFloat = 72
        var frame = NSRect(
            x: visible.midX - size.width / 2,
            y: visible.maxY - size.height - topMargin,
            width: size.width,
            height: size.height
        )
        frame = WindowFrameClamp.ensureVisible(frame: frame, screenVisible: visible)
        panel.setFrame(frame, display: true)
    }

    // MARK: NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        dismissOnly()
        return false
    }

    func windowWillClose(_ notification: Notification) {
        guard !isDismissing else { return }
        removeEscapeMonitor()
        let dismiss = onDismiss
        panel = nil
        onSelect = nil
        onDismiss = nil
        dismiss?()
    }
}
