# GrammarCat

[English](README.md) · **简体中文**

一个适配 Grammarly 的 macOS 速记小工具。

终端类应用（Terminal、Claude Code、iTerm 等）不支持 Grammarly Desktop，因为它们
不提供原生文本框。GrammarCat 给你一个带**原生 macOS 文本框**的小弹窗，而
Grammarly *能够*挂接这种文本框——在里面输入或粘贴英文，让 Grammarly 就地标注并
修正，然后提交。提交时 GrammarCat 会：

1. 把修正后的文本粘贴回你刚才使用的应用。
2. 把这段文本追加到你的 Obsidian 日记
   （`~/Documents/Notes/Daily/Journal/<YYYY>/<YYYY-MM-DD>.md`）。

GrammarCat 本身**不做**任何语法修正——全部由 Grammarly 完成。

## 使用方式

- **打开弹窗：** 按全局快捷键（默认 `⌘⇧I`），或点击悬浮按钮（可拖到屏幕任意位置）。
- **编辑：** 输入或粘贴文本，Grammarly 会就地修正。
- **提交：** `⌘↩`——弹窗隐藏，文本被粘贴回上一个应用，并记录到当天的日记。
- **取消：** `esc`——隐藏弹窗，保留草稿。
- **设置 / 退出：** 右键点击悬浮按钮。

## 构建

需要 Swift 6 以上版本（只装命令行工具即可，无需完整的 Xcode）。

```sh
bash scripts/build-app.sh            # 构建 GrammarCat.app
bash scripts/build-app.sh --install  # 同时复制到 /Applications
open GrammarCat.app
```

## 权限

首次启动时 macOS 会请求**辅助功能（Accessibility）**权限——自动粘贴需要它。
在「系统设置 → 隐私与安全性 → 辅助功能」中授权 GrammarCat，然后重新启动。
即使没有该权限，日记记录功能仍然可用。

本应用使用临时签名（ad-hoc），因此每次重新构建签名都会变化，macOS 会让辅助功能
授权失效——每次重新构建后都需要重新启用 GrammarCat。

## 设置

右键点击悬浮按钮 →**设置…**（或在 GrammarCat 窗口获得焦点时按 `⌘,`——当悬浮
按钮被隐藏时很有用）。设置窗口可配置：

- **将提交的文本追加到日记** ——开启 / 关闭日记记录。
- **日记文件夹** ——日记所在位置；文件写入 `<文件夹>/YYYY/YYYY-MM-DD.md`。
- **全局快捷键** ——点击该输入框，然后按下新的组合键。
- **自动粘贴到上一个应用** ——关闭时，修正后的文本只会放入剪贴板，由你手动
  `⌘V` 粘贴（无需辅助功能权限）。
- **显示悬浮按钮** ——隐藏后只用快捷键触发。
- **开机时启动 GrammarCat** ——当应用位于 `/Applications` 时最为可靠
  （见「构建」中的 `--install`）。

设置保存在 `UserDefaults` 中，更改后立即生效。
