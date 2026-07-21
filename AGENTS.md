## Learned User Preferences

- Prefer bilingual docs: English `README.md` plus Simplified Chinese `README.zh-CN.md`.
- Session/chat logs belong in `~/.claude/chatlog`, not the project `chatdoc/` directory.
- Copyright / GitHub owner attribution uses `wizizm`.
- Settings numerics (retention days, truncation length, type idle flush seconds) should be plain number text fields, not steppers.
- Type logging (Branch A / native): under Chinese IME, hold Latin and resolve via **Latin-token** field presence (not raw `contains`) — exact token or promote partial hold (`te`→`test`); pinyin scraps (`h` inside `zhong`) dropped. Do **not** idle-flush held Latin while Chinese IME is active (Enter does not flush either — IME confirm).
- Cursor / VS Code–based IDEs (Branch B): Monaco `AXTextArea` with newline-only / ZWSP IME scraps is unreliable (`ElectronEditorAXPolicy`) **only when** `VSCodeBasedIDEPolicy` matches — never apply that gate to Finder/Notes/企微. Under Chinese IME there, key-fallback is fully off; chat Chinese is captured only after send via `CursorChatAXProbe` (Enter / ⌘Enter), with spaced AX-noise filtered out.
- Copy followed immediately by paste of the same text should merge into one log event; intervening typed text keeps copy and paste as separate lines.
- Prefer preserving original copy/paste formatting (including newlines) so content can be re-copied from the log without flattening.
- Settings window should open normally when closed, and if already open but obscured, bring it to the front; if mostly off-screen or stuck at the bottom, recenter/clamp on screen; keep the pane compact (avoid excessive width and scrollbars).
- Prefer a user-configurable global hotkey (default ⇧⌘L) to open today's log; recording requires ⌘ or ⌃; Escape cancels recording.
- Prefer a separate configurable 「粘贴历史」 hotkey (default off until recorded; must not share the open-today-log chord); keep open-today-log unchanged. Panel: Today tab (`copy`/`copy_paste`, payload-deduped) + Search tab (all log kinds); select → pasteboard + restore focus + ⌘V. Accessibility required for paste into other apps; programmatic inject is not re-logged.
- Menu bar icon should stay crisp at menu-bar size (no white edge, not oversized or blurry).

## Learned Workspace Facts

- iRecorder is a macOS 14+ Swift menu-bar app that logs committed typed text (Accessibility value diffs, CJK/IME-aware), clipboard copy, and ⌘V paste to daily local UTF-8 `.log` files; nothing is uploaded.
- Default log directory is `~/Documents/iRecorder/`; directory and retention days are user-configurable; secure/password fields are skipped; login-at-startup uses `SMAppService`.
- Capture requires Accessibility permission; ad-hoc packaged builds often need the Accessibility entry re-checked (and sometimes a quit/relaunch) after each reinstall to `/Applications`.
- `session_started` log lines include `ax=0|1` so Accessibility trust can be verified after reinstalls; copy/paste can still work when `ax=0`, but type capture will not.
- Build/package entrypoint is `./scripts/package-app.sh` (SwiftPM release build → `dist/iRecorder.app`, optional install to `/Applications`).
- Global hotkeys use Carbon `RegisterEventHotKey` via multi-ID `HotKeyMonitor` (open-today-log + 粘贴历史); still depend on Accessibility for reliable ⌘V injection.
- 「粘贴历史」 is log-backed (no separate clipboard DB): Today = `copy`/`copy_paste` newest-first payload dedupe; Search = case-insensitive substring across daily `.log` kinds; programmatic pasteboard+⌘V must be suppressed from capture.
- Menu bar includes Check for Updates (GitHub `releases/latest` vs `CFBundleShortVersionString`, installs `iRecorder.app.zip` over the running bundle) and Help (opens repo Issues). `scripts/package-app.sh` also emits `dist/iRecorder.app.zip` for release assets.
- Windows counterpart is published separately at `https://github.com/wizizm/irecorder-for-windows` and is linked from the READMEs.
- Self-capture of the app’s own Console/log output previously caused exponential backslash escaping on copy/paste lines; filtering self-capture is part of the capture design.
