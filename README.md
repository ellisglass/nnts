# Xomsky

[![Version](https://img.shields.io/badge/version-1.1.7-007AFF.svg?style=flat-square)](https://github.com/unacau/xomsky/releases/latest)
[![macOS 14+](https://img.shields.io/badge/macOS-14.0%2B-black.svg?style=flat-square)](https://github.com/unacau/xomsky)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)

Instantly jump to specific Chrome or Brave profiles with <kbd>Caps Lock</kbd> + <kbd>C</kbd>/<kbd>B</kbd> + <kbd>1..4</kbd>, switch to favorite apps by their first letter while holding <kbd>Caps Lock</kbd>, and eliminate repetitive <kbd>Cmd</kbd>+<kbd>C</kbd> keystrokes with automatic copy-on-select.

```bash
brew install unacau/tap/xomsky
```
*Or download **[Xomsky.dmg (1.8 MB)](https://github.com/unacau/xomsky/releases/latest/download/Xomsky.dmg)**.*

---

## Shortcuts

<p align="center">
  <img src="assets/xomsky_bento_grid.png" alt="Xomsky Shortcuts & Bento Grid" width="100%">
</p>

| Shortcut | Action | Target / Details |
| :--- | :--- | :--- |
| <kbd>Caps</kbd> + <kbd>C</kbd> / <kbd>B</kbd> + <kbd>1..4</kbd><br> | **Direct Profile Jump** | Instantly raise a specific Chrome (`C`) or Brave (`B`) profile window |
| <kbd>Caps</kbd> + <kbd>C</kbd> / <kbd>B</kbd> | **Profile Cycle** | Cycle through browser profiles with a minimalist HUD overlay |
| <kbd>Caps</kbd> + <kbd>[A–Z]</kbd> | **First-Letter App Switch** | Instant switch to any app by its first letter (<kbd>T</kbd> Terminal, <kbd>F</kbd> Finder, <kbd>N</kbd> Notes, <kbd>S</kbd> Spotify, etc.) |
| *Repeated tap on key* | **App Cycle** | Cycle through all applications sharing the same first letter |
| **Select Text (drag)** | **Copy-on-Select** | Auto-copies selected text to clipboard with instant cursor toast (no <kbd>Cmd</kbd>+<kbd>C</kbd>) |

*Holding <kbd>Caps</kbd> displays the minimalist HUD overlay. Press <kbd>Esc</kbd> anytime to dismiss.*

---

## Under the Hood

* **Driverless Remap:** Physical Caps Lock is remapped to `F18` via `/usr/bin/hidutil`. No green LED, no accidental uppercase.
* **Sub-16ms Latency:** Head-insert `CGEventTap` intercepts hotkeys before the window server for single-frame switching.
* **Reliable Profile Switching:** Uses native macOS Accessibility (`kAXMenuBarAttribute`) on the browser's "Profiles" menu, not fragile window title regexes.
* **100% Local & Lightweight:** Zero telemetry/network calls, ~15 MB RAM, 0% idle CPU. Resets keyboard layout on exit.

---

## Build & Diagnostics

```bash
# Build & install from source
make native install

# Run test suite (107 tests)
make test

# Stream local diagnostics (os_log)
make monitor
```

## Uninstall

```bash
brew uninstall xomsky   # or remove /Applications/Xomsky.app
```

---

## License

MIT © [Igor Ekishev](https://github.com/unacau)
