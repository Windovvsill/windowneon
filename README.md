# windowneon

A macOS menu bar app that draws a colored border around the active window, so you always know which window has focus. Useful for split-screen work, multiple monitors, and anyone who finds macOS makes it hard to tell which window is active.

![Demo](docs/windowneon.gif)

## Install

Download the latest `windowneon-x.x.x.zip` from the [Releases](https://github.com/Windovvsill/windowneon/releases) page, unzip it, and move `windowneon.app` to your Applications folder.

## Accessibility permission

Windowneon requires Accessibility access to detect which window is currently focused. macOS will prompt you on first launch. You can also grant it manually in System Settings under Privacy and Security, then Accessibility.

The app only uses this permission to read window positions and focus state. It does not read window contents, keystrokes, or any other input.

## Requirements

macOS 13 or later.

## Features

The menu bar icon gives access to all settings, which are per-app unless noted:

- **Border width** -- choose a global default from 1-10pt, or override per app
- **Set corner radius** -- live preview slider to match any window style
- **Set border color** -- solid color or two-color gradient; updates live as you pick
- **Exclude app from border** -- hide the border for specific apps
- **Show edge ticks** -- short perpendicular marks at the midpoint of each edge, useful in split-screen to see which side is focused at a glance; ticks are suppressed at screen edges
- **Draw border outside window** -- extend the border outward instead of inward
- **Fade in on focus** -- animate the border on focus change (off by default)
- **Enable borders** -- toggle all borders on/off with Cmd+Opt+B
- **Export / Import settings** -- save and restore all per-app settings as JSON
- **Launch at login** -- start automatically when you log in
- **Check for updates** -- built-in auto-updater via Sparkle

## URL scheme

Windowneon registers the `windowneon://` URL scheme so you can control the border color from scripts or the terminal.

| URL | Effect |
|-----|--------|
| `windowneon://set?color=FF0000` | Override all borders to the given hex color |
| `windowneon://reset` | Clear the override and restore per-app colors |

The override is in-memory only — it clears when the app quits.

> **Note:** URL scheme handling requires the app to be running as a built `.app` bundle. It does not work when launched via `swift run`. To test, run `make app && open windowneon.app` first.

A common use case is a shell wrapper that turns borders red when you SSH into a production host:

```bash
# ~/.zshrc
function ssh() {
    if [[ "$*" == *prod* ]]; then
        open "windowneon://set?color=FF0000"
        command ssh "$@"
        open "windowneon://reset"
    else
        command ssh "$@"
    fi
}
```

## Run from source

```bash
git clone https://github.com/Windovvsill/windowneon
cd windowneon
swift run
```

## Build a release app

```bash
make app
open windowneon.app
```
