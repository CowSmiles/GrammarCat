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

- **Open the popup:** press the global hotkey (`⌘⇧I` by default) or click the
  floating button (drag it anywhere on screen).
- **Edit:** type or paste; Grammarly corrects inline.
- **Submit:** `⌘↩` — popup hides, text is pasted into the previous app and
  logged to today's note.
- **Cancel:** `esc` — hides the popup, keeps your draft.
- **Settings / Quit:** right-click the floating button.

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

## Settings

Right-click the floating button → **Settings…** (or press `⌘,` while a
GrammarCat window is focused — useful if the floating button is hidden).
The Settings window configures:

- **Append submitted text to my daily note** — turn note logging on/off.
- **Daily-note folder** — where notes live; files go to
  `<folder>/YYYY/YYYY-MM-DD.md`.
- **Global hotkey** — click the field, then press a new chord.
- **Auto-paste into the previous app** — when off, corrected text only goes
  to the clipboard for a manual `⌘V` (no Accessibility permission needed).
- **Show the floating button** — hide it to rely on the hotkey alone.
- **Launch GrammarCat at login** — works most reliably when the app lives in
  `/Applications` (see Build → `--install`).

Settings are stored in `UserDefaults` and apply immediately.
