# iRecorder

[English](./README.md) | [简体中文](./README.zh-CN.md)

macOS（本仓库）| [Windows](https://github.com/wizizm/irecorder-for-windows)

macOS 菜单栏小工具：在本机记录你在各 App 里**已上屏的文字**（含中文输入法确认后的汉字，不是按键码）、**复制**，以及 **⌘V 粘贴**。按天写入本地 UTF-8 `.log`，不上传网络。

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License MIT](https://img.shields.io/badge/License-MIT-blue)

## 功能

- **打字**：通过辅助功能读取已上屏文本差分；中文输入法下忽略拼音组字过程，只记确认后的汉字
- **复制 / 粘贴**：监听剪贴板与全局 ⌘V；短时间内「复制后立刻粘贴同一段」合并为 `copy_paste`
- **按行缓冲**：停输 N 秒（默认 3，可调）写一行；按 Enter 立即换行
- **菜单栏**：暂停 / 继续、打开今日日志、设置（目录、保留天数、截断、开机启动）
- **隐私友好**：数据仅存本机；密码框内打字不记录

## 系统要求

- macOS 14+
- **辅助功能**权限（打字采集 + 全局粘贴热键）

## 安装

### 从源码打包（推荐）

```bash
git clone https://github.com/wizizm/irecorder.git
cd irecorder
./scripts/package-app.sh
```

脚本会：

1. `swift build -c release`
2. 生成 `dist/iRecorder.app`
3. 安装到 `/Applications/iRecorder.app` 并打开

只打包、不装到「应用程序」：

```bash
IRECORDER_SKIP_INSTALL=1 ./scripts/package-app.sh
```

> 当前使用 ad-hoc 签名。每次重新安装后，请到 **系统设置 → 隐私与安全性 → 辅助功能** 重新确认勾选 **iRecorder**（路径应为 `/Applications/iRecorder.app`）。

### 首次使用

1. 点击菜单栏橙色 **iR** 图标  
2. 若显示辅助功能未生效：菜单或设置里点 **打开设置**，勾选 iRecorder  
3. **退出并重新打开** App（macOS 勾选后往往要重启进程才生效）  
4. 默认日志目录：`~/Documents/iRecorder/`

启动成功后，当日 log 中应很快出现一行 `session_started`。

## 日志格式

一天一个文件：`YYYY-MM-DD.log`

```text
2026-07-15T16:12:03+08:00	type	Safari	你好世界
2026-07-15T16:12:10+08:00	copy_paste	Finder→Notes	clipboard text
2026-07-15T16:12:20+08:00	copy	Safari	only copied
2026-07-15T16:12:25+08:00	paste	Notes	pasted later
```

| 列 | 说明 |
| --- | --- |
| 时间 | ISO 8601 |
| 类型 | `type` / `copy` / `paste` / `copy_paste` |
| App | 前台应用名；跨 App 粘贴时形如 `A→B` |
| 正文 | 原文。`type` 会把换行 / 制表符 / `\` 转义为 `\n` / `\t` / `\\`（物理上一行）。`copy` / `paste` / `copy_paste` **保留真实换行与制表符**，方便按原格式复制出来（一条记录可能跨多行）。 |

- 复制 / 粘贴超过设置长度会截断并附加 ` [truncated]`（默认 100 KB，`0` = 不截断）；**打字不截断**
- 不会把「自己的 log 内容」再记一遍（避免在控制台打开 log 时转义膨胀）
- 粘贴后的 AX 回声不会再多记一条 `type`

## 设置项

| 项 | 说明 |
| --- | --- |
| 日志目录 | 默认 `~/Documents/iRecorder` |
| 保留天数 | `0` = 永不自动删 |
| 复制/粘贴截断 | KB；`0` = 不截断 |
| 打字换行等待 | 1–60 秒 |
| 登录时启动 | 需安装为 `.app`（放入 Applications 后更可靠） |

## 限制

- 高度自绘、游戏、部分 Electron / 自定义控件可能读不到文字
- 密码 / Secure 字段的**打字**不记录；若内容已被复制到剪贴板，复制/粘贴仍可能记下
- ad-hoc 签名无公证；Gatekeeper 可能提示，需在隐私设置中手动授权

## 开发

```bash
swift test          # 核心库单元测试
swift run iRecorder # 直接跑可执行文件（无完整 .app 时，登录项等能力受限）
```

架构概览：

| 目标 | 职责 |
| --- | --- |
| `IRecorderCore` | 文本差分、行缓冲、格式化、写文件、设置（有测试） |
| `iRecorder` | AX / 剪贴板 / ⌘V、菜单栏与设置 UI、打包为 `.app` |

```text
Sources/
  IRecorderCore/     # 纯逻辑
  iRecorder/         # App + Capture + UI
Tests/
  IRecorderCoreTests/
scripts/
  package-app.sh     # release 打包 → dist/ → /Applications
Resources/           # AppIcon.icns、MenuBarIcon.png
```

## 隐私

iRecorder **不收集、不上传**任何数据。日志只写在你指定的本地目录。辅助功能权限仅用于读取已上屏文本与监听粘贴快捷键。

## License

[MIT](./LICENSE)
