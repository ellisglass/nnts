# Project: NNTS — macOS Productivity Suite (v2.0.0)

> **Positioning:** Fast and intuitive application access via **caps lock + first letter of app**, dedicated browser profile switching via **caps lock + c/b + 1–8**, and Linux/X11-style **Copy-on-Select** (copy upon mouse drag selection).
>
> **The 3 Core Pains (Why It Exists):**
> 1. *Killer Feature #1:* Chrome/Brave profile windows — in macOS, system `Cmd+Tab` groups all profiles under one process. `caps lock + c/b + 1..8` brings the exact profile window to focus in under 16ms.
> 2. *Feature #2:* First-letter application jump (`caps lock + [a-z]`: `caps lock + o` Obsidian, `caps lock + s` Spotify/Settings, `caps lock + f` Finder, `caps lock + t` Telegram/Terminal) with instant cycling between duplicate apps on the same letter (`1/2 ↻`).
> 3. *Feature #3:* Copy-on-Select — selecting text automatically copies it to the clipboard, eliminating 1,000 redundant `Cmd+C` keystrokes daily.

## Tech Stack & Architecture
- **Platform**: macOS 14.0+ (Sonoma, Sequoia, Tahoe).
- **Toolchain**: Swift 6+ (Strict Concurrency, `@MainActor`, `Sendable`), Swift Package Manager (SPM).
- **Core Frameworks**: AppKit, CoreGraphics (`CGEventTap`), ApplicationServices (Accessibility `AXUIElement`), IOHID (`hidutil`), SwiftUI.
- **Zero Heavy Runtime Dependencies**: Driverless hardware remapping via IOHID; no background daemons or kernel extensions.
- **Unified Logging Subsystem**: `com.almosteleven.nnts`.

## Key Build & Verification Commands
- **Developer Inner Loop (Host Build & Relaunch)**: `make dev` or `make run` or `./build_native_app.sh --run`
- **Continuous Live Watcher**: `make watch` or `./scripts/watch_dev.sh`
- **Run Tests**: `make test` or `swift test` or `./tests/run_tests.sh`
- **Quality & Validation Gates**: `make validate` (version sync and shell script syntax)
- **Build Native App**: `make native` or `./build_native_app.sh` (Universal Mach-O binary & DMG)
- **Generate Checksums**: `make checksums` (SHA-256 `dist/checksums.txt`)
- **System Health Check**: `make health` or `./scripts/health_check.sh`
- **Install App**: `make install` or `./install.sh`
- **Stream System Logs**: `make monitor` or `./scripts/monitor_telemetry.sh stream`
- **Telemetry Summary**: `make diagnostics` or `./scripts/monitor_telemetry.sh summary 1h`
- **Clean Scratch & Build Artifacts**: `make clean-scratch` / `make clean`

## Architecture & Subsystems
1. **Caps-Lock Engine (`src/ChromeQuickAccess/Engine/CapsLockEngine.swift`)**:
   - Hardware remapping via `hidutil property --set` (caps lock `0x700000039` -> F18 `0x70000006D`).
   - Head-insert `CGEventTap` (.cghidEventTap):
     - Held down acts as dedicated modifier routing `C`, `B`, `A`, `T`, `I`, `N`, dynamic letters `A-Z`, digits `1`..`8`, Arrow keys, and `Tab` (without green LED blinking).
     - Released without action simply swallows event (no synthetic Escape).
2. **App Group Engine (`src/ChromeQuickAccess/Engine/AppGroupEngine.swift`)**:
   - Universal Pinned Quick Apps (4 slots max in Free, unlimited in Pro).
   - Dynamic first-letter shortcuts, letter cycling submenus (`1/2 ↻`), and MRU window focus priority.
3. **Chrome Profile Engine (`src/ChromeQuickAccess/Engine/ChromeProfileEngine.swift`)**:
   - Parses Chromium `Local State` (`profile.info_cache`) dynamically.
   - Profile switching via native macOS menu bar (`kAXMenuBarAttribute` -> `Profiles` menu item).
   - Window raising via `kAXRaiseAction` and `kAXMainAttribute`.
   - Supports up to 8 profile slots with drag-and-drop slot management in Settings.
4. **Antigravity Engine (`src/ChromeQuickAccess/Engine/AntigravityEngine.swift`)**:
   - Discovers Antigravity and Antigravity IDE bundles/paths.
   - Activates frontmost app or toggles to partner app on `caps lock + a`.
5. **Copy-on-Select Engine (`src/ChromeQuickAccess/Engine/CopyOnSelectEngine.swift`)**:
   - Pure native drag detection (>10pt) and multi-click (double/triple) text selection copying.
   - Synthesizes `Cmd+C` with loop-prevention marker.
   - Built-in immunity for password managers, financial apps, spreadsheet cells, and interactive controls.
6. **Finder Tidy Engine (`src/ChromeQuickAccess/Engine/FinderTidyEngine.swift`)**:
   - Enforces a configurable ceiling on open Finder windows (default: 3 max).
   - Prunes duplicate folder windows and closes stale background Finder windows while preserving active windows and modal sheets.
7. **HUD Window (`src/ChromeQuickAccess/Views/MinimalHUDWindow.swift`)**:
   - Non-activating, floating bezel overlay showing app icon and profile/app avatars.
   - Always dismissed immediately BEFORE window focus transitions (`launchOrFocusTarget`).
8. **Settings & Feedback (`src/ChromeQuickAccess/Views/SettingsWindow.swift`, `FeedbackWindow.swift`)**:
   - Pure native SwiftUI multi-tab settings panel (General, Profiles, Quick Apps, Copy-on-Select, Pro License).
   - Zero-permission avatar import strictly via clipboard paste (`⌘⌃⇧4`) or local folder selection.

## Key Code Conventions & Invariants
- **Strict English-Only Deliverables & Assets**: All documentation, UI strings, promotional assets, and release notes must be strictly in English.
- **Strict Lowercase "caps lock"**: Categorically never write "Caps", "CAPS", "Caps Lock", or "Caps lock". Always write `caps lock` in full lowercase, two words.
- **Canonical Brand Typeface**: Space Grotesk Bold (`assets/fonts/SpaceGrotesk-Bold.ttf`) for all brand headings and displays.
- **HUD Dismissal Order**: Always hide the HUD overlay window (`MinimalHUDWindow.shared.hideImmediate()`) BEFORE triggering application activation or window focus.
- **Chromium Profile Automation Guardrail**: Never match Chromium windows by profile name or title substrings. Always automate via native macOS menu bar (`kAXMenuBarAttribute`), selecting items strictly by position/index.
- **Zero-Permission Privacy Invariant**: Categorically avoid requesting macOS Screen Recording permissions (`CGRequestScreenCaptureAccess`).
- **Live App Rebuild & Relaunch**: After code modifications, automatically run `make dev` so the running `/Applications/NNTS.app` is updated before returning turn.
