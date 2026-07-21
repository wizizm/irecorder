# iRecorder Design — Check for Updates & Help

**Date:** 2026-07-21  
**Status:** Approved for implementation planning  
**Approach:** Port iSwitch update/help pattern (`GitHub releases/latest` + `iRecorder.app.zip` install; Help → Issues)

## Goal

Menu bar gains two items matching iSwitch behavior:

1. **检查更新… / Check for Updates…** — fetch latest GitHub release, compare to `CFBundleShortVersionString`, offer download+install of `iRecorder.app.zip` over the running bundle, then relaunch and quit.
2. **帮助 / Help** — open the GitHub Issues page in the default browser.

UI strings follow system language: Chinese when preferred language is Chinese; otherwise English (same rule as iSwitch `L10n`). Existing Chinese-only menu items are unchanged in this feature.

## Non-goals

- Background / periodic auto-check
- Sparkle or App Store updates
- Changelog UI beyond alert text
- Full bilingual rewrite of the entire menu bar

## Architecture

```
MenuBarContent
  ├─ 检查更新… → UpdateMenuActions.checkForUpdates()
  └─ 帮助 → UpdateMenuActions.openHelp() → AppProject.issuesURL

IRecorderCore (testable)
  ├─ AppProject (owner/repo URLs)
  ├─ VersionCompare
  ├─ GitHubRelease (+ preferred zip asset name)
  └─ UpdateChecker (check outcome only; network via protocol)

iRecorder app
  ├─ URLSessionReleaseFetcher / ZipDownloader / AppBundleInstaller
  ├─ UpdateMenuActions (alerts + install + relaunch)
  └─ MenuL10n (minimal bilingual strings for update/help only)
```

Pure comparison/parse logic lives in **IRecorderCore** for TDD. Network, ditto unzip, and file replace stay in the **app** target (same split spirit as iSwitch, adjusted for SPM).

## Behavior

### Help

- Open `https://github.com/wizizm/irecorder/issues`.

### Check for Updates

1. Guard against concurrent checks.
2. `GET` `https://api.github.com/repos/wizizm/irecorder/releases/latest` with GitHub JSON Accept + User-Agent `iRecorder`.
3. Normalize local (`CFBundleShortVersionString`) and remote (`tag_name`, strip leading `v`).
4. If remote not newer → alert “已是最新 / You’re up to date”.
5. If newer → alert with current/latest; confirm → download zip → extract → replace `Bundle.main.bundleURL` with `iRecorder.app` from archive → open new app → terminate.
6. On error → alert with localized failure title + message.

### Zip asset selection

1. Prefer asset named exactly `iRecorder.app.zip`.
2. Else first asset whose name ends with `.zip` (case-insensitive).
3. Else error `zipAssetMissing`.
4. Installer only accepts a bundle named `iRecorder.app` inside the archive (do not overwrite from an arbitrary `.app`).

### Menu placement

Between **设置…** and **退出**, with a divider before 退出 (mirror iSwitch: Settings / Check for Updates / Help / Divider / Quit). Insert:

```
设置…
检查更新…
帮助
———
退出
```

### Packaging

`scripts/package-app.sh` after building `dist/iRecorder.app`:

```bash
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ROOT/dist/iRecorder.app.zip"
```

Release uploads should include that zip as the primary update asset.

## Localization (update/help only)

Keys (Chinese / English), selected by preferred language containing `zh`:

| Key | zh | en |
|-----|----|----|
| checkForUpdates | 检查更新… | Check for Updates… |
| help | 帮助 | Help |
| upToDateTitle | 已是最新版本 | You’re Up to Date |
| updateAvailableTitle | 有可用更新 | Update Available |
| updateFailedTitle | 检查更新失败 | Update Check Failed |
| downloadAndInstall | 下载并安装 | Download and Install |
| cancel | 取消 | Cancel |
| checkingForUpdates | 正在检查更新… | Checking for Updates… |

Plus formatted messages for up-to-date / update-available (version strings), matching iSwitch tone.

## Testing (IRecorderCore, TDD)

- `VersionCompare`: normalize `v` prefix; ordering across 1–3 segment versions
- `GitHubRelease.decode`: prefer `iRecorder.app.zip`; fallback `.zip`; missing zip
- `UpdateChecker.check`: upToDate / updateAvailable with mock fetcher; zip missing throws

App alerts/install: manual smoke after packaging.

## Resolved decisions

| Topic | Decision |
|-------|----------|
| Feature parity | Same as iSwitch (API + zip install + Issues) |
| Strings | Bilingual for these items only |
| Repo | `wizizm/irecorder` |
| Asset | `iRecorder.app.zip` |
| Scope of L10n | Update/help only; rest of menu stays Chinese for now |
