# windowneon

Draws a border around the focused window on macOS.

## Requirements

- macOS 13+
- Xcode command line tools (`xcode-select --install`)

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

Grant Accessibility permission when prompted. A `◻` menu bar icon appears — use it to change border color, width, or quit.
