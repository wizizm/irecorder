## Learned User Preferences

- Prefer bilingual docs: English `README.md` plus Simplified Chinese `README.zh-CN.md`.
- Session/chat logs belong in `~/.claude/chatlog`, not the project `chatdoc/` directory.
- Copyright / GitHub owner attribution uses `wizizm`.
- Settings numerics (retention days, truncation length, type idle flush seconds) should be plain number text fields, not steppers.
- Type logging: under Chinese IME, hold Latin and resolve via AX field presence — longest held prefix still in field → English; rest (pinyin replaced by CJK) dropped. Idle flush only (Enter does not flush — IME confirm).
- Cursor is a primary daily typing target; when AXValue is unavailable, key-insertion fallback is required (do not treat Cursor as AX-only).
- Copy followed immediately by paste of the same text should merge into one log event; intervening typed text keeps copy and paste as separate lines.
- Prefer preserving original copy/paste formatting (including newlines) so content can be re-copied from the log without flattening.
- Settings window should open normally when closed, and if already open but obscured, bring it to the front; if mostly off-screen or stuck at the bottom, recenter/clamp on screen; keep the pane compact (avoid excessive width and scrollbars).
- Prefer a user-configurable global hotkey (default ⇧⌘L) to open today's log; recording requires ⌘ or ⌃; Escape cancels recording.
- Menu bar icon should stay crisp at menu-bar size (no white edge, not oversized or blurry).

## Learned Workspace Facts

- iRecorder is a macOS 14+ Swift menu-bar app that logs committed typed text (Accessibility value diffs, CJK/IME-aware), clipboard copy, and ⌘V paste to daily local UTF-8 `.log` files; nothing is uploaded.
- Default log directory is `~/Documents/iRecorder/`; directory and retention days are user-configurable; secure/password fields are skipped; login-at-startup uses `SMAppService`.
- Capture requires Accessibility permission; ad-hoc packaged builds often need the Accessibility entry re-checked (and sometimes a quit/relaunch) after each reinstall to `/Applications`.
- `session_started` log lines include `ax=0|1` so Accessibility trust can be verified after reinstalls; copy/paste can still work when `ax=0`, but type capture will not.
- Build/package entrypoint is `./scripts/package-app.sh` (SwiftPM release build → `dist/iRecorder.app`, optional install to `/Applications`).
- Global open-today-log hotkey uses Carbon `RegisterEventHotKey` (more reliable than NSEvent global monitors) and still depends on Accessibility.
- Windows counterpart is published separately at `https://github.com/wizizm/irecorder-for-windows` and is linked from the READMEs.
- Self-capture of the app’s own Console/log output previously caused exponential backslash escaping on copy/paste lines; filtering self-capture is part of the capture design.
