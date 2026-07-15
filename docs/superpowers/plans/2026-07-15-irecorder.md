# iRecorder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a macOS menu bar app that logs committed typed text (incl. Chinese), copy, and paste into daily UTF-8 `.log` files.

**Architecture:** SPM library `IRecorderCore` holds pure capture/log logic (TDD). Executable `iRecorder` is an LSUIElement menu bar app (AppKit + SwiftUI) that wires AX, pasteboard, and UI. Package as `iRecorder.app` via a small wrap script.

**Tech Stack:** Swift 6 / macOS 13+, Swift Testing or XCTest, AppKit Accessibility / NSPasteboard, SwiftUI Settings, SMAppService login item.

## Global Constraints

- macOS 13+ (Ventura); Chinese via AX value diffs, not keycodes
- Skip secure/password fields; truncate payloads > 100KB with ` [truncated]`
- Log line: `{ISO8601}\t{type|copy|paste}\t{app}\t{payload}` UTF-8; newlines→`\n`, tabs→`\t`
- Default log dir `~/Documents/iRecorder/`; default retention 30 days (`0` = never prune)
- Menu bar only; Accessibility required for `type`; login item default ON
- NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST (pure logic modules)

## File Structure

```
Package.swift
Sources/IRecorderCore/
  Models/CaptureEvent.swift
  Diff/TextInsertionDiff.swift
  Log/LogLineFormatter.swift
  Log/PayloadTruncator.swift
  Log/LogFileNamer.swift
  Log/RetentionPruner.swift
  Log/LogWriter.swift
  Secure/SecureRoleClassifier.swift
  Settings/SettingsStore.swift
Sources/iRecorder/
  main.swift / iRecorderApp.swift
  AppDelegate+StatusItem.swift
  Capture/AXWatcher.swift
  Capture/ClipboardWatcher.swift
  Capture/PasteDetector.swift
  Capture/CaptureCoordinator.swift
  UI/SettingsView.swift
  Info.plist
Tests/IRecorderCoreTests/
  TextInsertionDiffTests.swift
  LogLineFormatterTests.swift
  PayloadTruncatorTests.swift
  LogFileNamerTests.swift
  RetentionPrunerTests.swift
  SecureRoleClassifierTests.swift
  LogWriterTests.swift
  SettingsStoreTests.swift
scripts/package-app.sh
README.md
```

---

### Task 1: SPM scaffold + CaptureEvent

**Files:**
- Create: `Package.swift`
- Create: `Sources/IRecorderCore/Models/CaptureEvent.swift`
- Create: `Tests/IRecorderCoreTests/CaptureEventTests.swift`

**Interfaces:**
- Produces: `enum CaptureKind: String { case type, copy, paste }`, `struct CaptureEvent { kind, appName, payload, date }`

- [ ] **Step 1: Write failing test**

```swift
import Testing
@testable import IRecorderCore

@Test func captureKindRawValuesMatchLogTokens() {
    #expect(CaptureKind.type.rawValue == "type")
    #expect(CaptureKind.copy.rawValue == "copy")
    #expect(CaptureKind.paste.rawValue == "paste")
}
```

- [ ] **Step 2: Run test — expect fail (module / type missing)**

```bash
cd /Users/linwenjie/workspace/irecorder && swift test --filter CaptureEventTests
```

- [ ] **Step 3: Minimal Package.swift + CaptureEvent**

```swift
// Package.swift
// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "iRecorder",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "IRecorderCore", targets: ["IRecorderCore"]),
        .executable(name: "iRecorder", targets: ["iRecorder"]),
    ],
    targets: [
        .target(name: "IRecorderCore"),
        .executableTarget(name: "iRecorder", dependencies: ["IRecorderCore"]),
        .testTarget(name: "IRecorderCoreTests", dependencies: ["IRecorderCore"]),
    ]
)
```

```swift
public enum CaptureKind: String, Sendable {
    case type, copy, paste
}

public struct CaptureEvent: Sendable, Equatable {
    public let kind: CaptureKind
    public let appName: String
    public let payload: String
    public let date: Date
    public init(kind: CaptureKind, appName: String, payload: String, date: Date = Date()) {
        self.kind = kind; self.appName = appName; self.payload = payload; self.date = date
    }
}
```

- [ ] **Step 4: `swift test --filter CaptureEventTests` — PASS**

- [ ] **Step 5: Commit** `feat: scaffold SPM and CaptureEvent`

---

### Task 2: TextInsertionDiff

**Files:**
- Create: `Sources/IRecorderCore/Diff/TextInsertionDiff.swift`
- Create: `Tests/IRecorderCoreTests/TextInsertionDiffTests.swift`

**Interfaces:**
- Produces: `enum TextInsertionDiff { static func insertedText(previous: String, current: String) -> String? }`
- Returns nil if no net insertion (delete-only / identical)

- [ ] **Step 1: Failing tests**

```swift
@Test func appendAtEnd() {
    #expect(TextInsertionDiff.insertedText(previous: "你", current: "你好") == "好")
}
@Test func insertInMiddle() {
    #expect(TextInsertionDiff.insertedText(previous: "你好世界", current: "你好，世界") == "，")
}
@Test func deleteOnlyReturnsNil() {
    #expect(TextInsertionDiff.insertedText(previous: "你好", current: "你") == nil)
}
@Test func identicalReturnsNil() {
    #expect(TextInsertionDiff.insertedText(previous: "a", current: "a") == nil)
}
@Test func emptyToText() {
    #expect(TextInsertionDiff.insertedText(previous: "", current: "你好世界") == "你好世界")
}
```

- [ ] **Step 2: Run — FAIL missing type**

- [ ] **Step 3: Implement LCP/LCS-suffix style common-prefix + common-suffix diff; middle remainder is insertion if `current.count >= previous.count` and insertion non-empty; if only deletion (current shorter and prefix+suffix cover) return nil. Prefer: longest common prefix + longest common suffix; inserted = current[prefix..<count-suffix] when that range is non-empty AND (current.count - previous.count == inserted.count OR inserted non-empty while current longer). Spec: insertions only — if `current.count < previous.count` and no insertion region, nil. Simple algorithm:**

```swift
public enum TextInsertionDiff {
    public static func insertedText(previous: String, current: String) -> String? {
        if previous == current { return nil }
        let p = Array(previous), c = Array(current)
        var i = 0
        while i < p.count && i < c.count && p[i] == c[i] { i += 1 }
        var j = 0
        while j < (p.count - i) && j < (c.count - i) && p[p.count - 1 - j] == c[c.count - 1 - j] { j += 1 }
        let inserted = String(c[i..<(c.count - j)])
        if inserted.isEmpty { return nil }
        return inserted
    }
}
```

- [ ] **Step 4: PASS all diff tests**

- [ ] **Step 5: Commit** `feat: extract text insertions via string diff`

---

### Task 3: LogLineFormatter + PayloadTruncator

**Files:**
- Create: `Sources/IRecorderCore/Log/LogLineFormatter.swift`
- Create: `Sources/IRecorderCore/Log/PayloadTruncator.swift`
- Create: `Tests/IRecorderCoreTests/LogLineFormatterTests.swift`
- Create: `Tests/IRecorderCoreTests/PayloadTruncatorTests.swift`

**Interfaces:**
- `PayloadTruncator.truncate(_ s: String, maxBytes: Int = 100_000) -> String`
- `LogLineFormatter.format(event: CaptureEvent, timeZone: TimeZone) -> String`

- [ ] **Step 1: Tests**

```swift
@Test func escapesNewlineAndTab() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
    let date = cal.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 16, minute: 12, second: 3))!
    let e = CaptureEvent(kind: .type, appName: "Safari", payload: "a\nb\tc", date: date)
    let line = LogLineFormatter.format(event: e, timeZone: TimeZone(secondsFromGMT: 8 * 3600)!)
    #expect(line == "2026-07-15T16:12:03+08:00\ttype\tSafari\ta\\nb\\tc")
}
@Test func truncateOver100KB() {
    let s = String(repeating: "啊", count: 60_000) // >100KB UTF-8
    let out = PayloadTruncator.truncate(s)
    #expect(out.hasSuffix(" [truncated]"))
    #expect(out.utf8.count <= 100_000 + " [truncated]".utf8.count)
}
```

- [ ] **Step 2: FAIL then implement**

```swift
public enum PayloadTruncator {
    public static let defaultMaxBytes = 100_000
    public static func truncate(_ s: String, maxBytes: Int = defaultMaxBytes) -> String {
        guard s.utf8.count > maxBytes else { return s }
        var result = ""
        result.reserveCapacity(maxBytes)
        for ch in s {
            let next = result + String(ch)
            if next.utf8.count > maxBytes { break }
            result = next
        }
        return result + " [truncated]"
    }
}

public enum LogLineFormatter {
    public static func format(event: CaptureEvent, timeZone: TimeZone = .current) -> String {
        let f = ISO8601DateFormatter()
        f.timeZone = timeZone
        f.formatOptions = [.withInternetDateTime]
        let ts = f.string(from: event.date)
        let payload = event.payload
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\(ts)\t\(event.kind.rawValue)\t\(event.appName)\t\(payload)"
    }
}
```

- [ ] **Step 3: PASS + Commit** `feat: format and truncate log payloads`

---

### Task 4: LogFileNamer + RetentionPruner

**Files:**
- Create: `Sources/IRecorderCore/Log/LogFileNamer.swift`
- Create: `Sources/IRecorderCore/Log/RetentionPruner.swift`
- Create: `Tests/IRecorderCoreTests/LogFileNamerTests.swift`
- Create: `Tests/IRecorderCoreTests/RetentionPrunerTests.swift`

**Interfaces:**
- `LogFileNamer.fileName(for: Date, calendar: Calendar) -> String` → `YYYY-MM-DD.log`
- `RetentionPruner.filesToDelete(names: [String], today: Date, retainDays: Int, calendar: Calendar) -> [String]`
  - `retainDays <= 0` → `[]`

- [ ] **Step 1–4: TDD as usual; Commit** `feat: daily log names and retention prune`

---

### Task 5: LogWriter

**Files:**
- Create: `Sources/IRecorderCore/Log/LogWriter.swift`
- Create: `Tests/IRecorderCoreTests/LogWriterTests.swift`

**Interfaces:**
- `final class LogWriter` with `init(directory: URL, calendar: Calendar = .current, fileManager: FileManager = .default)`
- `func append(_ event: CaptureEvent)` — creates dir, writes to today's file, truncates payload first, flushes per write
- Uses `LogLineFormatter` + `PayloadTruncator` + `LogFileNamer`

- [ ] **Step 1: Test writes UTF-8 line into temp dir**

```swift
@Test func appendWritesDailyFile() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let writer = LogWriter(directory: dir)
    let e = CaptureEvent(kind: .copy, appName: "Finder", payload: "hello", date: Date())
    try writer.append(e)
    let name = LogFileNamer.fileName(for: e.date)
    let text = try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
    #expect(text.contains("\tcopy\tFinder\thello\n") || text.hasSuffix("\tcopy\tFinder\thello"))
}
```

- [ ] **Step 2–4: FAIL → implement → PASS → Commit** `feat: append daily log files`

---

### Task 6: SecureRoleClassifier + SettingsStore

**Files:**
- Create: `Sources/IRecorderCore/Secure/SecureRoleClassifier.swift`
- Create: `Sources/IRecorderCore/Settings/SettingsStore.swift`
- Create: `Tests/IRecorderCoreTests/SecureRoleClassifierTests.swift`
- Create: `Tests/IRecorderCoreTests/SettingsStoreTests.swift`

**Interfaces:**
- `SecureRoleClassifier.isSecure(role: String?, subrole: String?) -> Bool` — true for `AXSecureTextField` or subrole/role containing `Password` / `Secure`
- `SettingsStore` backed by injectable `UserDefaults` suite:
  - `logDirectoryURL` default `Documents/iRecorder`
  - `retentionDays` default `30`
  - `launchAtLogin` default `true`
  - `isRecording` default `true`

- [ ] **TDD + Commit** `feat: secure-field classifier and settings store`

---

### Task 7: Menu bar app shell + CaptureCoordinator

**Files:**
- Create: `Sources/iRecorder/iRecorderApp.swift`
- Create: `Sources/iRecorder/AppState.swift`
- Create: `Sources/iRecorder/Capture/CaptureCoordinator.swift`
- Create: `Sources/iRecorder/Capture/ClipboardWatcher.swift`
- Create: `Sources/iRecorder/Capture/PasteDetector.swift`
- Create: `Sources/iRecorder/Capture/AXWatcher.swift`
- Create: `Sources/iRecorder/UI/SettingsView.swift`
- Create: `Sources/iRecorder/Info.plist`
- Create: `scripts/package-app.sh`
- Create: `README.md`

**Interfaces:**
- `CaptureCoordinator` starts/stops watchers; on event → `LogWriter.append` if `settings.isRecording`
- `ClipboardWatcher`: poll pasteboard changeCount; on new string ≠ last → `.copy`
- `PasteDetector`: `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)` for Cmd+V → `.paste`
- `AXWatcher`: if `AXIsProcessTrusted()`, observe focused UI element value; use `TextInsertionDiff`; skip if `SecureRoleClassifier`
- App: `MenuBarExtra`, Pause/Resume, Open today’s log, Open folder, Settings, Quit; prompt Accessibility

- [ ] **Step 1: Implement app wiring (AX/AppKit not fully unit-tested; core already covered)**
- [ ] **Step 2: `swift build` succeeds**
- [ ] **Step 3: `scripts/package-app.sh` produces `dist/iRecorder.app` with LSUIElement**
- [ ] **Step 4: README — permissions, how to run, log format**
- [ ] **Step 5: Commit** `feat: menu bar app with AX/clipboard capture`

---

### Task 8: Retention on start + login item

**Files:**
- Modify: `Sources/iRecorder/Capture/CaptureCoordinator.swift` (prune on start / daily)
- Modify: `Sources/iRecorder/UI/SettingsView.swift` (SMAppService toggle)
- Modify: `README.md`

- [ ] **Step 1: On coordinator start, list `*.log` in directory, delete via `RetentionPruner`**
- [ ] **Step 2: Settings toggles `SMAppService.mainApp`; reflect status**
- [ ] **Step 3: Manual checklist in README**
- [ ] **Step 4: `swift test` all green; Commit** `feat: retention prune and login item`

---

## Spec coverage check

| Spec item | Task |
|-----------|------|
| type via AX diff + Chinese | 2, 7 |
| copy / paste | 7 |
| secure skip | 6, 7 |
| daily log + format + escape | 3, 4, 5 |
| 100KB truncate | 3 |
| custom dir + retention | 6, 5, 8 |
| menu bar UI | 7 |
| Accessibility prompt | 7 |
| login at login default ON | 6, 8 |

## Execution

Inline execution (user said 开工). After each task: tests green, commit with `/usr/bin/git`.
