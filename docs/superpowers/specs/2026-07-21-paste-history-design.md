# iRecorder Design — Paste History (粘贴历史)

**Date:** 2026-07-21  
**Status:** Approved for implementation planning  
**Approach:** Parse existing daily `.log` files + floating NSPanel + separate Carbon hotkey

## Goal

Provide a **粘贴历史** picker:

1. User-configurable global hotkey (default **disabled** until recorded in Settings)
2. Floating panel with two tabs:
   - **今日** (default): today’s unique `copy` / `copy_paste` payloads (newest first)
   - **搜索**: substring search across all historical log kinds
3. On row select: close panel → restore previous frontmost app → write payload to pasteboard → synthesize ⌘V

Existing **打开今日日志** hotkey (default ⇧⌘L) is unchanged.

## Non-goals (this feature)

- Separate SQLite / in-memory clipboard index (logs remain source of truth)
- Image / rich-text pasteboard types
- Favorites, pinning, or multi-select paste
- Merging “today” across timezones or retention-pruned files
- Replacing the open-today-log hotkey

## Architecture

```
HotKeyMonitor (multi ID)
  ├─ openTodayLog  → open file (existing)
  └─ pasteHistory  → PasteHistoryPanel (new, default disabled)

PasteHistoryPanel (NSPanel + SwiftUI)
  ├─ Tab 今日  → LogHistoryQuery.todayUniqueCopies(logDir, date)
  └─ Tab 搜索  → LogHistoryQuery.search(logDir, query, limit)

On select:
  remember frontmost app → close panel → activate app
  → NSPasteboard.general.setString
  → synthesize ⌘V
  → suppress self-logging of this programmatic paste
```

| Unit | Layer | Responsibility |
|------|-------|----------------|
| `LogRecordParser` | Core | Split daily log into records (multi-line copy/paste payloads) |
| `LogHistoryQuery` | Core | Today unique copies; full-dir search with limit |
| `PasteHistoryItem` | Core | Model: date, kind, app, payload |
| `HotKeyMonitor` | App | Register two Carbon hot keys by distinct `EventHotKeyID` |
| `PasteHistoryPanelController` | App | Show/hide panel; Esc / close without paste |
| `PasteInjector` | App | Focus restore + pasteboard write + ⌘V; mark suppress window |
| `SettingsStore` | Core | Persist `pasteHistoryHotKey` (`HotKeySpec`, default disabled) |

## Data rules

### Record parsing

- A new record starts when a line matches: `ISO8601\t{kind}\t{app}\t` where `kind` ∈ `type|copy|paste|copy_paste`.
- For `copy` / `paste` / `copy_paste`, payload may contain real newlines until the next record header or EOF.
- For `type`, one physical line; escaped `\n` / `\t` / `\\` in payload; search/display decode escapes before match/preview.

### Tab 今日

- Read only today’s `YYYY-MM-DD.log` (local calendar day).
- Include kinds: `copy`, `copy_paste` only.
- Deduplicate by **exact full payload string**; keep the **newest** timestamp; order **newest → oldest**.
- Row UI: time · app · payload preview (truncate for display only; paste uses full payload).

### Tab 搜索

- Empty query → no scan / empty list (prompt to type).
- Scan all `YYYY-MM-DD.log` under the configured log directory.
- Case-insensitive substring match on **payload** (all kinds) and **app** name.
- Results newest → oldest; show kind badge; same select → paste path as 今日.
- Debounce input (~200 ms). Cap results at **200** per search to bound UI work.

### Paste side effects

- Programmatic pasteboard write + synthesized ⌘V must **not** append a new `paste` / `copy` line (extend existing self-capture / suppress path used after paste).
- After select: **close panel** and **restore focus** to the previously frontmost app before ⌘V so the paste lands in the right place.
- Esc / window close: dismiss only, no paste.

## UI & Settings

### Panel

- Title: **粘贴历史**
- Floating `NSPanel` (can appear without stealing durable activation until select flow runs)
- Tabs: `今日` | `搜索`
- Position: centered upper on the screen containing the mouse; clamp on-screen (reuse window-frame clamp ideas)
- Empty states: short Chinese hints

### Hotkey

- Second Carbon registration alongside open-today-log; distinct hot key IDs under the same handler signature family.
- Default: `isEnabled = false` (placeholder keyCode allowed; **do not register** while disabled).
- While either Settings shortcut recorder is active, suspend **both** monitors.
- Accessibility: panel browse works without trust; synthesized ⌘V may fail — light in-panel hint if untrusted.

### Settings row

- Below「打开今日日志」: **粘贴历史** — enable checkbox + record button + clear (back to disabled default).
- Caption: 全局快捷键打开粘贴历史（默认关闭，需自行设置）.

### Menu bar

- Add **粘贴历史…** menu item calling the same entry point as the hotkey.

## Testing (IRecorderCore, TDD)

- Multi-line `copy` payload parse boundaries (header detection, EOF)
- Today dedupe: identical payloads keep newest only
- Search: case-insensitive; cross-file; `type` unescape before match; result cap
- Malformed / empty files: skip bad lines, no crash
- `SettingsStore`: paste-history hotkey defaults disabled; encode/decode round-trip; corrupt data → default

App-layer focus/⌘V path is thin glue; prefer manual smoke after package install. Core owns the behavior contracts above.

## Open decisions (resolved)

| Topic | Decision |
|-------|----------|
| Relation to open-today-log hotkey | Separate hotkey |
| Default tab contents | Today `copy` + `copy_paste`, unique by payload |
| Second tab | Global search of all historical kinds |
| Paste mechanism | Pasteboard + synthesize ⌘V |
| Default hotkey | Disabled until user records |
| After select | Close panel + restore prior app focus, then ⌘V |
| Feature name | 粘贴历史 |
