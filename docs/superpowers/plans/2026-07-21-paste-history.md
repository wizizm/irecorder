# Paste History (粘贴历史) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a **粘贴历史** picker: configurable (default-off) global hotkey opens a two-tab panel; select a row to paste into the previously focused app via pasteboard + synthesized ⌘V.

**Architecture:** Parse existing daily UTF-8 `.log` files in `IRecorderCore` (`LogRecordParser` + `LogHistoryQuery`). App layer adds a second Carbon hotkey, floating `NSPanel`, focus restore, and a short suppress window so programmatic pasteboard/⌘V is not re-logged.

**Tech Stack:** Swift 5.9, macOS 14+, Swift Testing, AppKit (`NSPanel`, `NSPasteboard`, Carbon hotkeys), SwiftUI.

## Global Constraints

- Feature name / UI copy: **粘贴历史** (not 复制历史)
- Separate hotkey from 打开今日日志 (default ⇧⌘L unchanged)
- Default paste-history hotkey: `isEnabled = false` — do not register while disabled
- Tab 今日: kinds `copy` + `copy_paste` only; exact-payload dedupe keep newest; newest → oldest
- Tab 搜索: all kinds; case-insensitive substring on payload + app; empty query = no scan; result cap **200**; debounce ~200 ms
- On select: close panel → activate prior frontmost app → set pasteboard string → synthesize ⌘V
- Programmatic pasteboard write + ⌘V must not append new `copy` / `paste` log lines
- Esc / close: dismiss only, no paste
- NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST (Core modules)
- Build from repo path under `os-tools/irecorder`; if ModuleCache path error appears, `rm -rf .build` then rebuild

## File Structure

```
Sources/IRecorderCore/
  Models/PasteHistoryItem.swift          # NEW
  Log/LogRecordParser.swift              # NEW
  Log/LogHistoryQuery.swift              # NEW
  Settings/HotKeySpec.swift              # ADD defaultPasteHistory
  Settings/SettingsStore.swift           # ADD pasteHistoryHotKey

Tests/IRecorderCoreTests/
  LogRecordParserTests.swift             # NEW
  LogHistoryQueryTests.swift             # NEW
  HotKeySpecTests.swift                  # EXTEND
  SettingsStoreTests.swift               # EXTEND

Sources/iRecorder/
  Capture/HotKeyMonitor.swift            # REFACTOR multi-id
  Capture/PasteInjector.swift            # NEW
  Capture/CaptureCoordinator.swift       # ADD programmatic suppress
  UI/PasteHistoryPanel.swift             # NEW (SwiftUI + NSPanel host)
  UI/SettingsView.swift                  # ADD 粘贴历史 row
  UI/MenuBarViews.swift                  # ADD menu item
  UI/HotKeyCaptureView.swift             # MAY tweak if dual recorders need ids
  AppState.swift                         # WIRE hotkey + panel + injector
```

---

### Task 1: `PasteHistoryItem` + `LogRecordParser`

**Files:**
- Create: `Sources/IRecorderCore/Models/PasteHistoryItem.swift`
- Create: `Sources/IRecorderCore/Log/LogRecordParser.swift`
- Create: `Tests/IRecorderCoreTests/LogRecordParserTests.swift`

**Interfaces:**
- Produces:
  - `public struct PasteHistoryItem: Equatable, Sendable { public let date: Date; public let kind: CaptureKind; public let appName: String; public let payload: String }`
  - `public enum LogRecordParser { public static func parse(fileContents: String, timeZone: TimeZone = .current) -> [PasteHistoryItem] }`
- Header regex: line starts with `^\d{4}-\d{2}-\d{2}T` then `\t(type|copy|paste|copy_paste)\t` then app then `\t` then payload start.
- Multi-line: for `copy`/`paste`/`copy_paste`, continue appending lines until next header or EOF.
- `type`: single physical line; decode `\n`/`\t`/`\\` in payload when building `PasteHistoryItem.payload`.
- Skip lines that do not form a valid header (do not crash).

- [ ] **Step 1: Write failing tests**

```swift
import Foundation
import Testing
@testable import IRecorderCore

@Test func parseSingleLineCopy() {
    let raw = "2026-07-21T10:00:00+08:00\tcopy\tSafari\thello"
    let items = LogRecordParser.parse(fileContents: raw, timeZone: TimeZone(secondsFromGMT: 8 * 3600)!)
    #expect(items.count == 1)
    #expect(items[0].kind == .copy)
    #expect(items[0].appName == "Safari")
    #expect(items[0].payload == "hello")
}

@Test func parseMultilineCopyUntilNextHeader() {
    let raw = """
    2026-07-21T10:00:00+08:00\tcopy\tNotes\tline1
    line2
    2026-07-21T10:01:00+08:00\tpaste\tSafari\tx
    """
    let items = LogRecordParser.parse(fileContents: raw, timeZone: TimeZone(secondsFromGMT: 8 * 3600)!)
    #expect(items.count == 2)
    #expect(items[0].payload == "line1\nline2")
    #expect(items[1].kind == .paste)
    #expect(items[1].payload == "x")
}

@Test func parseTypeUnescapesPayload() {
    let raw = "2026-07-21T10:00:00+08:00\ttype\tSafari\ta\\nb\\\\c"
    let items = LogRecordParser.parse(fileContents: raw, timeZone: TimeZone(secondsFromGMT: 8 * 3600)!)
    #expect(items.count == 1)
    #expect(items[0].kind == .type)
    #expect(items[0].payload == "a\nb\\c")
}

@Test func parseSkipsGarbageLines() {
    let raw = "not-a-record\n2026-07-21T10:00:00+08:00\tcopy\tA\toK\n"
    let items = LogRecordParser.parse(fileContents: raw, timeZone: TimeZone(secondsFromGMT: 8 * 3600)!)
    #expect(items.count == 1)
    #expect(items[0].payload == "oK")
}
```

- [ ] **Step 2: Run tests — expect fail**

```bash
cd /Users/linwenjie/workspace/os-tools/irecorder && swift test --filter LogRecordParserTests
```

Expected: compile/link failure or missing `LogRecordParser`.

- [ ] **Step 3: Minimal implementation**

Implement `PasteHistoryItem` and `LogRecordParser.parse` as specified. Use `ISO8601DateFormatter` with `.withInternetDateTime` (and fractional seconds if needed) matching how logs are written. For `type` unescape: reverse `LogLineFormatter` escaping order (first `\\n`→newline, `\\t`→tab, then `\\\\`→`\`) carefully so `\\n` is not double-processed — prefer a small scanner or replace `\\\\` first to a sentinel, then `\n`/`\t`, then sentinel→`\`.

- [ ] **Step 4: Run tests — expect pass**

```bash
swift test --filter LogRecordParserTests
```

- [ ] **Step 5: Commit**

```bash
git add Sources/IRecorderCore/Models/PasteHistoryItem.swift \
  Sources/IRecorderCore/Log/LogRecordParser.swift \
  Tests/IRecorderCoreTests/LogRecordParserTests.swift
git commit -m "feat: parse multi-line log records for paste history"
```

---

### Task 2: `LogHistoryQuery` (今日去重 + 全局搜索)

**Files:**
- Create: `Sources/IRecorderCore/Log/LogHistoryQuery.swift`
- Create: `Tests/IRecorderCoreTests/LogHistoryQueryTests.swift`

**Interfaces:**
- Consumes: `LogRecordParser.parse`, `LogFileNamer.fileName(for:)`, `PasteHistoryItem`
- Produces:
  - `public enum LogHistoryQuery`
  - `public static func todayUniqueCopies(directory: URL, date: Date = Date(), calendar: Calendar = .current, fileManager: FileManager = .default) -> [PasteHistoryItem]`
  - `public static func search(directory: URL, query: String, limit: Int = 200, fileManager: FileManager = .default) -> [PasteHistoryItem]`

**Rules:**
- `todayUniqueCopies`: read `{directory}/{YYYY-MM-DD.log}`; filter `kind ∈ {.copy, .copyPaste}`; dedupe by exact `payload` keeping newest `date`; sort newest → oldest. Missing file → `[]`.
- `search`: if `query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty` → `[]`. Else list `*.log` via `fileManager`, parse each, match case-insensitive substring on `payload` **or** `appName`, collect, sort newest → oldest, take first `limit`.

- [ ] **Step 1: Write failing tests** (use temp directory)

```swift
import Foundation
import Testing
@testable import IRecorderCore

@Test func todayUniqueCopiesKeepsNewestPayload() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
    let day = cal.date(from: DateComponents(year: 2026, month: 7, day: 21))!
    let name = LogFileNamer.fileName(for: day, calendar: cal)
    let body = """
    2026-07-21T09:00:00+08:00\tcopy\tA\tdupe
    2026-07-21T10:00:00+08:00\tcopy_paste\tB\tdupe
    2026-07-21T11:00:00+08:00\tpaste\tC\tignored
    2026-07-21T12:00:00+08:00\tcopy\tD\tother
    """
    try body.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    let items = LogHistoryQuery.todayUniqueCopies(directory: dir, date: day, calendar: cal)
    #expect(items.map(\.payload) == ["other", "dupe"])
    #expect(items[1].appName == "B")
}

@Test func searchMatchesCaseInsensitiveAcrossFilesWithLimit() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    try "2026-07-20T10:00:00+08:00\ttype\tSafari\tHelloWorld\n"
        .write(to: dir.appendingPathComponent("2026-07-20.log"), atomically: true, encoding: .utf8)
    try "2026-07-21T10:00:00+08:00\tcopy\tNotes\thello there\n"
        .write(to: dir.appendingPathComponent("2026-07-21.log"), atomically: true, encoding: .utf8)
    let all = LogHistoryQuery.search(directory: dir, query: "hello", limit: 200)
    #expect(all.count == 2)
    let capped = LogHistoryQuery.search(directory: dir, query: "hello", limit: 1)
    #expect(capped.count == 1)
    #expect(LogHistoryQuery.search(directory: dir, query: "   ").isEmpty)
}
```

- [ ] **Step 2: Run — expect fail**

```bash
swift test --filter LogHistoryQueryTests
```

- [ ] **Step 3: Implement `LogHistoryQuery`**

- [ ] **Step 4: Run — expect pass**

```bash
swift test --filter LogHistoryQueryTests
```

- [ ] **Step 5: Commit**

```bash
git add Sources/IRecorderCore/Log/LogHistoryQuery.swift Tests/IRecorderCoreTests/LogHistoryQueryTests.swift
git commit -m "feat: query today unique copies and search log history"
```

---

### Task 3: Settings + `HotKeySpec.defaultPasteHistory`

**Files:**
- Modify: `Sources/IRecorderCore/Settings/HotKeySpec.swift`
- Modify: `Sources/IRecorderCore/Settings/SettingsStore.swift`
- Modify: `Tests/IRecorderCoreTests/HotKeySpecTests.swift`
- Modify: `Tests/IRecorderCoreTests/SettingsStoreTests.swift`

**Interfaces:**
- Produces: `HotKeySpec.defaultPasteHistory` — same placeholder keyCode as open-today (37 / L) is fine; **`isEnabled: false`**, command+shift true (unused until enabled).
- `SettingsStore.pasteHistoryHotKey` key `"pasteHistoryHotKey"`; corrupt/missing → `.defaultPasteHistory`.
- Update `settingsDefaults` / `settingsPersist` expectations.

- [ ] **Step 1: Failing tests**

```swift
@Test func pasteHistoryHotKeyDefaultIsDisabled() {
    #expect(HotKeySpec.defaultPasteHistory.isEnabled == false)
}

@Test func settingsPasteHistoryHotKeyDefaultsDisabled() {
    let suite = "test.irecorder.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = SettingsStore(defaults: defaults)
    #expect(store.pasteHistoryHotKey == HotKeySpec.defaultPasteHistory)
    #expect(store.pasteHistoryHotKey.isEnabled == false)
}

@Test func pasteHistoryHotKeyCorruptFallsBack() {
    let suite = "test.irecorder.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(Data("bad".utf8), forKey: "pasteHistoryHotKey")
    #expect(SettingsStore(defaults: defaults).pasteHistoryHotKey == .defaultPasteHistory)
}
```

Also extend `settingsPersist` to round-trip an enabled custom `pasteHistoryHotKey`.

- [ ] **Step 2: Run — expect fail**

```bash
swift test --filter pasteHistory
```

- [ ] **Step 3: Implement store + default**

- [ ] **Step 4: Run full settings/hotkey tests — pass**

```bash
swift test --filter SettingsStoreTests
swift test --filter HotKeySpecTests
```

- [ ] **Step 5: Commit**

```bash
git add Sources/IRecorderCore/Settings/HotKeySpec.swift Sources/IRecorderCore/Settings/SettingsStore.swift \
  Tests/IRecorderCoreTests/HotKeySpecTests.swift Tests/IRecorderCoreTests/SettingsStoreTests.swift
git commit -m "feat: persist paste-history hotkey (default disabled)"
```

---

### Task 4: Multi-binding `HotKeyMonitor`

**Files:**
- Modify: `Sources/iRecorder/Capture/HotKeyMonitor.swift`

**Interfaces:**
- Change monitor to support **two** bindings without two conflicting static IDs.
- Suggested API:

```swift
final class HotKeyMonitor {
    var isSuspended = false
    func setBinding(id: UInt32, spec: HotKeySpec, onTrigger: @escaping () -> Void)
    func removeBinding(id: UInt32)
    func start()  // re-register all enabled specs
    func stop()
}
```

- Use fixed IDs in AppState: `openTodayLog = 1`, `pasteHistory = 2`.
- Single Carbon event handler: dispatch by `hotKeyID.id`.
- `RegisterEventHotKey` only when `spec.isEnabled`.

**Note:** No Core unit test for Carbon; smoke after packaging. Keep diff focused — do not rewrite unrelated capture code.

- [ ] **Step 1: Refactor `HotKeyMonitor` to multi-binding** (no production callers broken: update `AppState` in same task enough to compile)

- [ ] **Step 2: Build**

```bash
cd /Users/linwenjie/workspace/os-tools/irecorder && swift build
```

If ModuleCache path mismatch: `rm -rf .build && swift build`.

- [ ] **Step 3: Commit**

```bash
git add Sources/iRecorder/Capture/HotKeyMonitor.swift Sources/iRecorder/AppState.swift
git commit -m "refactor: HotKeyMonitor supports multiple Carbon bindings"
```

---

### Task 5: `PasteInjector` + programmatic capture suppress

**Files:**
- Create: `Sources/iRecorder/Capture/PasteInjector.swift`
- Modify: `Sources/iRecorder/Capture/CaptureCoordinator.swift`
- Modify: `Sources/iRecorder/Capture/ClipboardWatcher.swift` (optional: `noteExternalWrite(_:)`)

**Interfaces:**
- `PasteInjector.paste(payload: String, into app: NSRunningApplication?)` on main:
  1. `app?.activate(options: [.activateIgnoringOtherApps])` (or best available API for macOS 14)
  2. Brief delay (~50–80 ms) so focus settles
  3. Call `coordinator.noteProgrammaticClipboard(payload)` **before** writing pasteboard
  4. `NSPasteboard.general.clearContents(); setString(payload, forType: .string)`
  5. Synthesize ⌘V via `CGEvent` keyDown/keyUp for keyCode `9` (V) with `.maskCommand`
- `CaptureCoordinator.noteProgrammaticClipboard(_ payload: String)`:
  - Set TTL suppress (~1.5 s) for matching `copy` and `paste` payloads (and ignore pasteboard change echo).
  - Also call `typeSuppressor.notePaste(payload)` so AX echo is suppressed.
- Implementation options (pick one, keep small):
  - **A (prefer):** `ClipboardWatcher.syncLastString(payload)` + coordinator flag `ignoreNextPasteMatching`
  - **B:** coordinator checks `programmaticSuppressor.shouldIgnore(kind:payload:)` at start of `handle`

- [ ] **Step 1: Add suppress helpers + `PasteInjector`**

- [ ] **Step 2: `swift build` passes**

- [ ] **Step 3: Commit**

```bash
git add Sources/iRecorder/Capture/PasteInjector.swift Sources/iRecorder/Capture/CaptureCoordinator.swift \
  Sources/iRecorder/Capture/ClipboardWatcher.swift
git commit -m "feat: paste injector with programmatic copy/paste suppress"
```

---

### Task 6: Paste History panel UI

**Files:**
- Create: `Sources/iRecorder/UI/PasteHistoryPanel.swift` (SwiftUI view + small `NSPanel` controller)

**Behavior:**
- Title: `粘贴历史`
- `TabView` / segmented: `今日` | `搜索`
- 今日: on appear load `LogHistoryQuery.todayUniqueCopies(directory: settings.logDirectoryURL)`
- 搜索: `TextField` + debounced 200 ms → `LogHistoryQuery.search(...)`; show kind badge
- Row: time (short) · app · preview (first line / truncated ~120 chars); full payload on select
- Empty hints in Chinese
- If `!AXWatcher.isTrusted`: caption「粘贴到其他 App 需要辅助功能权限」
- Callbacks: `onSelect(PasteHistoryItem)`, `onDismiss`
- Panel: `NSPanel` style nonactivating or `utility` + `level = .floating`; place upper-center on mouse screen; clamp with `WindowFrameClamp.ensureVisible`
- Esc / close → `onDismiss` only

- [ ] **Step 1: Implement panel + controller**

- [ ] **Step 2: `swift build`**

- [ ] **Step 3: Commit**

```bash
git add Sources/iRecorder/UI/PasteHistoryPanel.swift
git commit -m "feat: paste history panel with today and search tabs"
```

---

### Task 7: Wire AppState, Settings, Menu Bar

**Files:**
- Modify: `Sources/iRecorder/AppState.swift`
- Modify: `Sources/iRecorder/UI/SettingsView.swift`
- Modify: `Sources/iRecorder/UI/MenuBarViews.swift`
- Modify: `Sources/iRecorder/UI/HotKeyCaptureView.swift` if needed for dual recorders

**AppState flow `showPasteHistory()`:**
1. `priorApp = NSWorkspace.shared.frontmostApplication`
2. Show panel (load data)
3. On select: hide panel → `PasteInjector.paste(payload: item.payload, into: priorApp)`
4. On dismiss: hide only

**Settings:** below 打开今日日志, row **粘贴历史**:
- Checkbox bound to `pasteHistoryHotKey.isEnabled`
- Record button (suspend both hotkeys while recording) — reuse `HotKeyCaptureView` with a second `@State isRecordingPasteHistoryHotKey` OR one active recorder at a time
- 「清除」→ `.defaultPasteHistory`
- Caption: `全局快捷键打开粘贴历史（默认关闭，需自行设置）`

**Menu:** `Button("粘贴历史…") { appState.showPasteHistory() }` near 打开今日日志.

**start():** register both bindings on `HotKeyMonitor`.

- [ ] **Step 1: Wire settings + menu + AppState**

- [ ] **Step 2: Build + unit tests**

```bash
swift test
swift build
```

- [ ] **Step 3: Commit**

```bash
git add Sources/iRecorder/AppState.swift Sources/iRecorder/UI/SettingsView.swift \
  Sources/iRecorder/UI/MenuBarViews.swift Sources/iRecorder/UI/HotKeyCaptureView.swift
git commit -m "feat: wire paste history hotkey, settings, and menu"
```

---

### Task 8: Docs + package smoke

**Files:**
- Modify: `README.md`, `README.zh-CN.md` (Features / Settings rows for 粘贴历史)
- Optionally one-line pointer in `AGENTS.md` if not already present

- [ ] **Step 1: Update bilingual READMEs** — settings table + feature bullet; note default-off hotkey; paste = clipboard + ⌘V; requires Accessibility for paste into other apps

- [ ] **Step 2: Package**

```bash
cd /Users/linwenjie/workspace/os-tools/irecorder
rm -rf .build   # if ModuleCache path error from old checkout path
IRECORDER_SKIP_INSTALL=1 ./scripts/package-app.sh
```

- [ ] **Step 3: Manual smoke** (install or run `dist/iRecorder.app`)
  - Menu → 粘贴历史… → 今日 lists copies
  - Search finds older `type`/`paste`
  - Select pastes into Notes/TextEdit
  - Log does **not** gain a new paste line for that inject
  - 打开今日日志 ⇧⌘L still works

- [ ] **Step 4: Commit docs**

```bash
git add README.md README.zh-CN.md AGENTS.md
git commit -m "docs: document paste history feature"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Separate hotkey, default disabled | 3, 4, 7 |
| Tab 今日 unique copy/copy_paste | 2, 6 |
| Tab 搜索 all kinds, case-insensitive, cap 200 | 2, 6 |
| Multi-line log parse + type unescape | 1 |
| Close + restore focus + pasteboard + ⌘V | 5, 6, 7 |
| Suppress programmatic copy/paste log | 5 |
| Settings row + menu item | 7 |
| Name 粘贴历史 | 6, 7, 8 |
| Core TDD | 1–3 |

## Placeholder / consistency self-review

- No TBD steps; APIs named consistently (`PasteHistoryItem`, `LogHistoryQuery`, `pasteHistoryHotKey`).
- Hotkey IDs `1` / `2` fixed in AppState to match Task 4.
- Search limit constant `200` matches spec.
