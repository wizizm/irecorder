# iRecorder

macOS 菜单栏工具：记录各 App 中**已上屏的输入文字**（含中文输入法确认后的汉字，不是按键码）、**复制**到剪贴板的文本，以及 **Cmd+V 粘贴**的文本。按天写入本地 UTF-8 `.log` 文件。

## 要求

- macOS 14+
- 授予 **辅助功能** 权限（打字采集 + 全局粘贴监听）

## 构建与安装

```bash
./scripts/package-app.sh
# 生成 dist/iRecorder.app（含 App 图标）
# 拖到 /Applications 后双击启动
```

开发调试：

```bash
swift test
swift run iRecorder
```

> 登录项（开机启动）仅在打包成 `.app` 并放入 Applications 后可靠生效。

## 首次使用

1. 启动后点击菜单栏圆点图标  
2. 若提示未授权 → **授予辅助功能权限…**，在系统设置中勾选 iRecorder  
3. 默认日志目录：`~/Documents/iRecorder/`  
4. 设置里可改目录、保留天数、登录启动  

## 日志格式

一天一个文件：`YYYY-MM-DD.log`

打字会**缓冲成行**：停输入 N 秒（默认 3，设置可改）后写一行；按 **Enter** 立即写一行。  
复制后立刻粘贴同一段且中间没有其他打字记录 → 合并为一行 `copy_paste`（约 3 秒内）；否则仍是分开的 `copy` / `paste`。  
中文输入法下会**忽略拼音组字过程**（`a-z` / `'` 等），只保留上屏汉字；英文输入源下的字母仍会记录。  
不会再把「自己的 log 内容」二次记入（避免在控制台打开 log 时 `\t`/`\` 指数膨胀）。

```text
2026-07-15T16:12:03+08:00	type	Safari	你好世界
2026-07-15T16:12:10+08:00	copy_paste	Finder→Notes	clipboard text
2026-07-15T16:12:20+08:00	copy	Safari	only copied
2026-07-15T16:12:25+08:00	paste	Notes	pasted later
```

字段：`时间`、`type|copy|paste|copy_paste`、`前台 App`、`原文`（换行/制表符转义为 `\n` / `\t`）。  
超过配置长度的复制/粘贴内容会截断并附加 ` [truncated]`（设置里可改 KB，默认 100；`0` = 不截断）。打字记录不截断。  
密码框 / Secure 字段的**打字**不会被记录（复制/粘贴到剪贴板的内容仍会记）。  
粘贴后同一次上屏的 AX 回声不会再记一条 `type`。

## 限制

- 高度自绘、游戏、部分 Electron 控件可能无法通过辅助功能读到文字  
- 数据只存本机，不上传  

## 架构

- `IRecorderCore`：差分、格式化、写文件、设置（单元测试覆盖）  
- `iRecorder`：AX 轮询、剪贴板、粘贴快捷键、菜单栏 UI  
