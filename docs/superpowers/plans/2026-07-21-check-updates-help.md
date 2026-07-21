# Check for Updates & Help Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add bilingual menu items 检查更新… / 帮助 mirroring iSwitch (GitHub latest release + `iRecorder.app.zip` install; Help → Issues).

**Architecture:** Pure parse/compare/`UpdateChecker.check` in `IRecorderCore` (TDD). Network, install, alerts, `MenuL10n` in `iRecorder` app. Package script emits zip.

**Tech Stack:** Swift 5.9, macOS 14+, Swift Testing, URLSession, ditto unzip.

## Global Constraints

- Repo `wizizm/irecorder`; Issues help URL; prefer asset `iRecorder.app.zip`
- Bilingual only for update/help strings (system language contains `zh` → Chinese)
- Menu: after 设置… → 检查更新… → 帮助 → divider → 退出
- Install only accepts `iRecorder.app` inside zip
- NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST (Core)

## File Structure

```
Sources/IRecorderCore/Update/
  AppProject.swift
  VersionCompare.swift
  GitHubRelease.swift
  UpdateChecker.swift          # check() + protocols/outcomes/errors used by check
Tests/IRecorderCoreTests/
  UpdateCheckerTests.swift
Sources/iRecorder/
  Update/UpdateNetworking.swift  # fetcher/downloader/installer
  Update/UpdateMenuActions.swift
  Update/MenuL10n.swift
  UI/MenuBarViews.swift          # wire buttons
scripts/package-app.sh           # zip
README.md / README.zh-CN.md
```

---

### Task 1: Core VersionCompare + GitHubRelease + UpdateChecker (TDD)

**Files:** create Core Update/* + `UpdateCheckerTests.swift`

- [ ] RED tests (Swift Testing), then GREEN, commit `feat: core update check against GitHub releases`

Interfaces:
- `AppProject.githubOwner/Repo`, `issuesURL`, `latestReleaseAPIURL`
- `VersionCompare.isRemoteNewer`, `normalize`
- `GitHubRelease` with `zipAssetDownloadURL` preferring `iRecorder.app.zip`
- `ReleaseFetching`, `UpdateCheckOutcome`, `UpdateCheckerError.zipAssetMissing` (+ others if shared)
- `UpdateChecker(localVersion:fetcher:).check()`

### Task 2: App networking + installer + MenuL10n + menu + package zip

**Files:** app Update/*, MenuBarViews, package-app.sh, READMEs

- [ ] Port installer from iSwitch with `iRecorder.app` names
- [ ] `UpdateMenuActions` alerts (bilingual)
- [ ] Menu buttons
- [ ] `ditto` zip in package script
- [ ] Docs mention Check for Updates / release zip
- [ ] `swift test` + `swift build` + package smoke
- [ ] Commit `feat: menu check-updates and help`

## Spec coverage

| Spec | Task |
|------|------|
| Version/release parse + check | 1 |
| Menu + L10n + install + zip | 2 |
| Help Issues URL | 2 |
