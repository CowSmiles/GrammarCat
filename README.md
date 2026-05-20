# GrammarCat

**English** · [简体中文](README.zh-CN.md)

A Grammarly-friendly scratchpad for macOS.

Terminals (Terminal, Claude Code, iTerm, …) don't support Grammarly Desktop,
because they don't expose native text fields. GrammarCat gives you a small
popup with a **native macOS text box** that Grammarly *does* hook into — type
or paste your English there, let Grammarly underline and fix it inline, then
submit. On submit GrammarCat:

1. Pastes the corrected text into the app you were using.
2. Appends the text to your Obsidian daily note
   (`~/Documents/Notes/Daily/Journal/<YYYY>/<YYYY-MM-DD>.md`).

GrammarCat itself does **no** grammar correction — Grammarly does all of it.

## Usage

- **Open the popup:** press the global hotkey (`⌘⇧I`) or click the
  floating button (drag it anywhere on screen).
- **Edit:** type or paste; Grammarly corrects inline.
- **Submit:** `⌘↩` — popup hides, text is pasted into the previous app and
  logged to today's note.
- **Cancel:** `esc` — hides the popup, keeps your draft.

## Build

Requires Swift 6+ (Command Line Tools are enough — no Xcode IDE needed).

```sh
bash scripts/build-app.sh            # builds GrammarCat.app
bash scripts/build-app.sh --install  # also copies it to /Applications
open GrammarCat.app
```

## Permissions

On first launch macOS asks for **Accessibility** permission — required for the
auto-paste. Grant GrammarCat in System Settings → Privacy & Security →
Accessibility, then relaunch. Note logging works even without it.

The app is ad-hoc signed, so every rebuild changes its signature and macOS
invalidates the Accessibility grant — re-enable GrammarCat after each rebuild.

## Configuration

Defaults live as constants in the source:

- Hotkey — `HotkeyManager.swift`
- Daily-note base path — `DailyNotePath.swift`
