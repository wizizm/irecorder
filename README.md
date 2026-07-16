# iRecorder

[English](./README.md) | [简体中文](./README.zh-CN.md)

macOS (this repo) | [Windows](https://github.com/wizizm/irecorder-for-windows)

macOS menu bar utility that logs **committed on-screen text** (including CJK after IME confirm — not keycodes), **clipboard copy**, and **⌘V paste**. Writes daily local UTF-8 `.log` files. Nothing is uploaded.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License MIT](https://img.shields.io/badge/License-MIT-blue)

## Features

- **Typing** — Accessibility value diffs for committed text; under Chinese IME, skips pinyin composition and keeps confirmed characters only
- **Copy / paste** — Watches the pasteboard and global ⌘V; a copy followed quickly by the same paste merges into `copy_paste`
- **Line buffering** — Flush after N seconds idle (default 3, configurable), or immediately on Enter
- **Menu bar** — Pause / resume, open today’s log, settings (directory, retention, truncation, launch at login)
- **Privacy-friendly** — Data stays on disk; typing in password / secure fields is not recorded

## Requirements

- macOS 14+
- **Accessibility** permission (text capture + global paste hotkey)

## Install

### Build from source (recommended)

```bash
git clone https://github.com/wizizm/irecorder.git
cd irecorder
./scripts/package-app.sh
```

The script will:

1. `swift build -c release`
2. Produce `dist/iRecorder.app`
3. Install to `/Applications/iRecorder.app` and open it

Package only (skip `/Applications`):

```bash
IRECORDER_SKIP_INSTALL=1 ./scripts/package-app.sh
```

> The build uses ad-hoc signing. After every reinstall, re-check **System Settings → Privacy & Security → Accessibility** for **iRecorder** (path should be `/Applications/iRecorder.app`).

### First run

1. Click the orange **iR** menu bar icon  
2. If Accessibility is inactive: **Open Settings** from the menu or Settings pane, then enable iRecorder  
3. **Quit and relaunch** the app (macOS often does not apply the grant until process restart)  
4. Default log directory: `~/Documents/iRecorder/`

Once capture starts, today’s log should soon contain a `session_started` line.

## Log format

One file per day: `YYYY-MM-DD.log`

```text
2026-07-15T16:12:03+08:00	type	Safari	你好世界
2026-07-15T16:12:10+08:00	copy_paste	Finder→Notes	clipboard text
2026-07-15T16:12:20+08:00	copy	Safari	only copied
2026-07-15T16:12:25+08:00	paste	Notes	pasted later
```

| Column | Meaning |
| --- | --- |
| Time | ISO 8601 |
| Kind | `type` / `copy` / `paste` / `copy_paste` |
| App | Frontmost app; cross-app paste looks like `A→B` |
| Payload | Original text. `type` escapes newline / tab / `\` as `\n` / `\t` / `\\` (one physical line). `copy` / `paste` / `copy_paste` keep real newlines and tabs so you can copy the payload out with original formatting (a record may span multiple lines). |

- Copy / paste beyond the configured size is truncated with ` [truncated]` (default 100 KB; `0` = no truncate). **Typing is never truncated.**
- The app’s own log content is not re-captured (avoids escape blow-up when a log is open in Console)
- AX echo after paste is not logged again as `type`

## Settings

| Setting | Notes |
| --- | --- |
| Log directory | Default `~/Documents/iRecorder` |
| Retention days | `0` = never auto-delete |
| Copy / paste truncate | KB; `0` = unlimited |
| Type-line idle | 1–60 seconds |
| Launch at login | Needs a real `.app` (more reliable under Applications) |

## Limitations

- Highly custom-drawn UIs, games, and some Electron / custom controls may not expose text via Accessibility
- Typing in password / Secure fields is skipped; if text is already on the clipboard, copy / paste may still be logged
- Ad-hoc signature is not notarized; Gatekeeper may warn — grant Accessibility manually

## Development

```bash
swift test          # core library unit tests
swift run iRecorder # run the executable (login item etc. limited without a full .app)
```

| Target | Role |
| --- | --- |
| `IRecorderCore` | Diff, buffering, formatting, file I/O, settings (tested) |
| `iRecorder` | AX / pasteboard / ⌘V, menu bar & settings UI, `.app` packaging |

```text
Sources/
  IRecorderCore/     # pure logic
  iRecorder/         # app + capture + UI
Tests/
  IRecorderCoreTests/
scripts/
  package-app.sh     # release build → dist/ → /Applications
Resources/           # AppIcon.icns, MenuBarIcon.png
```

## Privacy

iRecorder **does not collect or upload** any data. Logs are written only to the directory you choose. Accessibility is used solely to read committed on-screen text and observe the paste hotkey.

## License

[MIT](./LICENSE)
