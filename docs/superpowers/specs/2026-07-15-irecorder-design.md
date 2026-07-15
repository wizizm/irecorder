# iRecorder Design — macOS Text & Clipboard Logger

**Date:** 2026-07-15  
**Status:** Approved for implementation planning  
**Approach:** Native Swift menu bar app (Accessibility + Pasteboard)

## Goal

Record on the local Mac:

1. Committed typed text in any app (including Chinese via IME — **not** raw keycodes)
2. Copied clipboard text
3. Pasted text

Write UTF-8 daily log files. Skip password / secure fields. Menu bar control only.

## Non-goals (v1)

- Cloud sync, remote upload, encryption at rest
- On-screen OCR / read-all-visible-text
- Full-text search UI
- Per-app allow/deny lists
- Recording images or non-string pasteboard types

## Architecture

```
MenuBar (SwiftUI + AppKit)
  ├─ TextCapture
  │    ├─ AXWatcher      — frontmost app + focused control, AXValue diffs → type
  │    └─ SecureGuard    — skip AXSecureTextField / password roles
  ├─ ClipboardWatcher    — NSPasteboard string changes → copy
  ├─ PasteDetector       — Cmd+V / paste gesture → paste
  ├─ LogWriter           — daily YYYY-MM-DD.log, retention cleanup
  └─ Settings            — log directory, retention days, login item
```

### Components

| Unit | Responsibility | Depends on |
|------|----------------|------------|
| `AXWatcher` | Observe focused element value; emit inserted text deltas | Accessibility permission, SecureGuard |
| `SecureGuard` | Decide whether an AX element is secure | AX APIs |
| `ClipboardWatcher` | Poll/observe pasteboard string; emit copy events | AppKit NSPasteboard |
| `PasteDetector` | Detect paste action; emit paste with current clipboard string | Event monitor / hotkey |
| `LogWriter` | Append tab-separated lines; roll by calendar day; prune old files | File system, Settings |
| `SettingsStore` | Persist directory, retention, launch-at-login, recording on/off | UserDefaults |
| `MenuBarApp` | Status item UI, permission prompts, open settings / logs | All above |

## Capture rules

### Typed text (`type`)

- Track frontmost app and focused AX element.
- On `AXValue` change, compute string diff vs last snapshot; log **insertions only** (deletes ignored).
- IME candidate stage is not in the field value; committed Chinese appears after确认 → natural Chinese support.
- Reset snapshot on focus change or app switch.
- If Accessibility is denied: do not capture `type` (clipboard still works).

### Copy (`copy`)

- When pasteboard string changes and differs from last recorded clipboard string → emit `copy`.
- Ignore non-string types (images, files-only, etc.).
- Truncate single payload above **100 KB**; append ` [truncated]` marker.

### Paste (`paste`)

- On paste action (Cmd+V or equivalent), log current pasteboard string as `paste`.
- A prior `copy` of the same string does **not** suppress `paste` (different action).

### Secure skip

- Do not read or log `AXSecureTextField` or password-related role/subrole.
- While focused element is secure, suppress `type` for that focus session.

## Log format

- Path: `{logDirectory}/YYYY-MM-DD.log` (timezone: system local)
- Encoding: UTF-8
- One record per line, fields separated by tab:

```text
{ISO8601 with offset}	{type|copy|paste}	{frontmostAppName}	{payload}
```

- Newlines inside payload escaped as `\n`; tabs escaped as `\t`.
- Default `logDirectory`: `~/Documents/iRecorder/` (user-changeable).
- Default retention: **30** days; `0` or “never” = no automatic deletion.
- Midnight (local): switch to new filename. Changing directory does not move old files.

Example:

```text
2026-07-15T16:12:03+08:00	type	Safari	你好世界
2026-07-15T16:12:10+08:00	copy	Finder	clipboard text here
2026-07-15T16:12:12+08:00	paste	Notes	clipboard text here
```

## UI

Menu bar status item only (no main window):

- Icon reflects recording / paused
- Menu: Pause/Resume · Open today’s log · Open log folder · Settings… · Quit
- Settings: log directory picker, retention days, launch at login toggle, link to Accessibility settings

## Permissions & launch

- **Accessibility**: required for `type`; first-run prompt + menu shortcut to System Settings.
- **Login item**: default ON via `SMAppService`; user can disable in Settings.
- No network entitlement required.

## Edge cases (accepted)

- Highly custom-drawn / game / some Electron controls may not expose AX text → miss `type`.
- Clipboard payloads > 100 KB truncated.
- Paste without string on pasteboard → no `paste` line.
- App quit / crash: open file flushed on each append (or short buffered flush) to limit data loss.

## Testing strategy

- Unit tests for: string-diff insertion extraction, log line escaping, day-roll filename, retention pruning, secure-element detection heuristics (pure logic).
- Manual / integration: Accessibility + IME Chinese commit, copy, paste, password field skip (requires macOS + permissions; document in README).

## Tech stack

- Swift 5.9+, macOS 13+ (Ventura) target unless build machine requires higher
- SwiftUI for Settings sheet; AppKit for status item / AX / pasteboard
- Xcode project under repo root (`iRecorder/`)
