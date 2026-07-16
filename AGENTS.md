## Learned User Preferences

- Prefer bilingual docs: English `README.md` plus Simplified Chinese `README.zh-CN.md`.
- Session/chat logs belong in `~/.claude/chatlog`, not the project `chatdoc/` directory.
- Copyright / GitHub owner attribution uses `wizizm`.
- Settings numerics (retention days, truncation length, type idle flush seconds) should be plain number text fields, not steppers.
- Type logging should record committed on-screen text only (skip IME pinyin/composition); flush a line after idle N seconds or immediately on Enter.
- Copy followed immediately by paste of the same text should merge into one log event; intervening typed text keeps copy and paste as separate lines.
- Prefer preserving original copy/paste formatting (including newlines) so content can be re-copied from the log without flattening.
- Settings window should open normally when closed, and if already open but obscured, bring it to the front; keep the pane compact (avoid excessive width and scrollbars).
- Menu bar icon should stay crisp at menu-bar size (no white edge, not oversized or blurry).

## Learned Workspace Facts

- iRecorder is a macOS 14+ Swift menu-bar app that logs committed typed text (Accessibility value diffs, CJK/IME-aware), clipboard copy, and ⌘V paste to daily local UTF-8 `.log` files; nothing is uploaded.
- Default log directory is `~/Documents/iRecorder/`; directory and retention days are user-configurable; secure/password fields are skipped; login-at-startup uses `SMAppService`.
- Capture requires Accessibility permission; ad-hoc packaged builds often need the Accessibility entry re-checked (and sometimes a quit/relaunch) after each reinstall to `/Applications`.
- Build/package entrypoint is `./scripts/package-app.sh` (SwiftPM release build → `dist/iRecorder.app`, optional install to `/Applications`).
- Windows counterpart is published separately at `https://github.com/wizizm/irecorder-for-windows` and is linked from the READMEs.
- Self-capture of the app’s own Console/log output previously caused exponential backslash escaping on copy/paste lines; filtering self-capture is part of the capture design.
