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
    @State private var selectedIndex: Int?
    @FocusState private var searchFieldFocused: Bool

    private var activeItems: [PasteHistoryItem] {
        switch tab {
        case .today: return todayItems
        case .search: return searchItems
        }
    }

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
                    .focused($searchFieldFocused)
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
        .background(
            PasteHistoryKeyMonitor(
                isSearchFieldFocused: searchFieldFocused,
                onDown: {
                    if searchFieldFocused {
                        searchFieldFocused = false
                        selectedIndex = ListKeyboardSelection.moveDown(
                            from: nil,
                            count: activeItems.count
                        )
                    } else {
                        moveSelection(down: true)
                    }
                },
                onUp: {
                    if searchFieldFocused { return }
                    if tab == .search, selectedIndex == 0 || selectedIndex == nil {
                        searchFieldFocused = true
                        selectedIndex = nil
                    } else {
                        moveSelection(down: false)
                    }
                },
                onReturn: {
                    if searchFieldFocused { return }
                    confirmSelection()
                },
                onLeft: {
                    if searchFieldFocused { return }
                    moveTab(forward: false)
                },
                onRight: {
                    if searchFieldFocused { return }
                    moveTab(forward: true)
                }
            )
        )
        .onAppear { reloadToday() }
        .onChange(of: tab) { _, newTab in
            selectedIndex = nil
            if newTab == .today {
                searchFieldFocused = false
                reloadToday()
            } else {
                DispatchQueue.main.async {
                    searchFieldFocused = true
                }
            }
        }
        .onChange(of: searchQuery) { _, newValue in
            selectedIndex = nil
            scheduleSearch(newValue)
        }
        .onChange(of: todayItems) { _, items in
            if tab == .today {
                selectedIndex = items.isEmpty ? nil : min(selectedIndex ?? 0, items.count - 1)
            }
        }
        .onChange(of: searchItems) { _, items in
            if tab == .search, !searchFieldFocused {
                selectedIndex = items.isEmpty ? nil : min(selectedIndex ?? 0, items.count - 1)
            }
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
        ScrollViewReader { proxy in
            List(selection: $selectedIndex) {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]
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
                        Text(Self.preview(item.payload))
                            .font(.body)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                    .tag(index)
                    .id(index)
                    .onTapGesture { onSelect(item) }
                }
            }
            .listStyle(.inset)
            .onChange(of: selectedIndex) { _, index in
                guard let index, items.indices.contains(index) else { return }
                withAnimation(.easeInOut(duration: 0.12)) {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
        }
    }

    private func moveSelection(down: Bool) {
        let count = activeItems.count
        selectedIndex = down
            ? ListKeyboardSelection.moveDown(from: selectedIndex, count: count)
            : ListKeyboardSelection.moveUp(from: selectedIndex, count: count)
    }

    private func moveTab(forward: Bool) {
        let tabs = Tab.allCases
        guard let current = tabs.firstIndex(of: tab) else { return }
        let next = ListKeyboardSelection.moveTab(from: current, count: tabs.count, forward: forward)
        tab = tabs[next]
    }

    private func confirmSelection() {
        guard let selectedIndex, activeItems.indices.contains(selectedIndex) else { return }
        onSelect(activeItems[selectedIndex])
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

/// Local keyDown monitor so ↑/↓/←/→/↩ work in a nonactivating floating panel.
private struct PasteHistoryKeyMonitor: NSViewRepresentable {
    var isSearchFieldFocused: Bool
    var onDown: () -> Void
    var onUp: () -> Void
    var onReturn: () -> Void
    var onLeft: () -> Void
    var onRight: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.attach(
            isSearchFieldFocused: isSearchFieldFocused,
            onDown: onDown,
            onUp: onUp,
            onReturn: onReturn,
            onLeft: onLeft,
            onRight: onRight
        )
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isSearchFieldFocused = isSearchFieldFocused
        context.coordinator.onDown = onDown
        context.coordinator.onUp = onUp
        context.coordinator.onReturn = onReturn
        context.coordinator.onLeft = onLeft
        context.coordinator.onRight = onRight
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator {
        var isSearchFieldFocused = false
        var onDown: (() -> Void)?
        var onUp: (() -> Void)?
        var onReturn: (() -> Void)?
        var onLeft: (() -> Void)?
        var onRight: (() -> Void)?
        private var monitor: Any?

        func attach(
            isSearchFieldFocused: Bool,
            onDown: @escaping () -> Void,
            onUp: @escaping () -> Void,
            onReturn: @escaping () -> Void,
            onLeft: @escaping () -> Void,
            onRight: @escaping () -> Void
        ) {
            self.isSearchFieldFocused = isSearchFieldFocused
            self.onDown = onDown
            self.onUp = onUp
            self.onReturn = onReturn
            self.onLeft = onLeft
            self.onRight = onRight
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                switch event.keyCode {
                case 125: // ↓
                    DispatchQueue.main.async { self.onDown?() }
                    return nil
                case 126: // ↑
                    if self.isSearchFieldFocused { return event }
                    DispatchQueue.main.async { self.onUp?() }
                    return nil
                case 123: // ←
                    if self.isSearchFieldFocused { return event }
                    DispatchQueue.main.async { self.onLeft?() }
                    return nil
                case 124: // →
                    if self.isSearchFieldFocused { return event }
                    DispatchQueue.main.async { self.onRight?() }
                    return nil
                case 36: // ↩
                    if self.isSearchFieldFocused { return event }
                    DispatchQueue.main.async { self.onReturn?() }
                    return nil
                default:
                    return event
                }
            }
        }

        func detach() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit { detach() }
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
        placeNearMouse(panel)
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

    private func placeNearMouse(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else {
            panel.center()
            return
        }
        let frame = WindowFrameClamp.nearAnchor(
            anchor: mouse,
            size: panel.frame.size,
            screenVisible: screen.visibleFrame
        )
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
