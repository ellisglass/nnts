# Architecture & Technical Specification: NNTS (v2.0.0)

## 1. Vision & Core Objective
**NNTS** is a lightweight, high-performance native macOS productivity utility engineered in pure Swift 6 and SwiftUI. It operates as a driverless standalone application providing:
1. **Dedicated Browser Profile Switching (`caps lock + c/b + 1..8`)**: Instant switching to windows of specific Chrome or Brave profiles via macOS Accessibility APIs without AppleScript and without opening empty tabs.
2. **First-Letter Application Jump (`caps lock + [a–z]`)**: Direct single-keystroke jump to applications by their first letter (`caps lock + o` Obsidian, `caps lock + s` Spotify/Settings, `caps lock + f` Finder, `caps lock + t` Telegram/Terminal) with deterministic duplicate cycling (`1/2 ↻`).
3. **Universal Copy-on-Select**: Automatic clipboard copying on text drag selection (>10pt) or multi-click (double/triple click) with a non-intrusive cursor-following HUD toast, eliminating thousands of redundant `Cmd+C` keystrokes daily.
4. **Finder Tidy Engine**: Automated ceiling enforcement on open Finder windows, closing redundant background folders while preserving active windows and modal sheets.
5. **Non-Activating Floating Bezel HUD**: Visual feedback displaying active app and profile avatars, dismissible before window focus transitions.

---

## 2. Keystroke & Interaction Flow

```
                     ┌────────────────────────────────────────┐
                     │          Physical caps lock            │
                     └───────────────────┬────────────────────┘
                                         │
                  Remapped via hidutil to F18 (0x70000006D)
                                         │
                                         ▼
                               ┌───────────────────┐
                               │    CGEventTap     │
                               └─────────┬─────────┘
                                         │
         ┌───────────────────────────────┴───────────────────────────────┐
         │                                                               │
  Tapped Alone (<250ms)                                            Held Down
         │                                                               │
         ▼                                                               ▼
   Swallow Event                                              Route Active Key Actions:
   (No action / No Escape)                                    ├── 'c': Cycle Chrome profiles
                                                              ├── 'b': Cycle Brave profiles
                                                              ├── '1'..'8': Direct profile index jump
                                                              ├── '[a–z]': Dynamic first-letter app jump
                                                              ├── 'tab' / 'shift-tab': Navigate HUD
                                                              ├── 'escape': Cancel HUD
                                                              └── arrows: Navigate Left/Right
```

---

## 3. Subsystem Architecture

### 3.1 Caps-Lock Engine (`src/ChromeQuickAccess/Engine/CapsLockEngine.swift`)
- **Driverless Remapping**: Uses macOS `hidutil property --set` to map physical caps lock (`0x700000039`) to F18 (`0x70000006D`). Restores default mapping upon application termination.
- **Head-Insert Event Tap**: Intercepts `keyDown`, `keyUp`, and `flagsChanged` via `.cghidEventTap`.
- **Modifier State Machine**: Tracks physical F18 events and isolates external multi-modifier (`Cmd+Opt+Ctrl+Shift`) state, ensuring modifier keys (e.g. Shift during Shift-Tab navigation) never cause premature caps lock release. Physical caps lock acts purely as a dedicated modifier without synthetic Escape side effects or LED toggling.
- **Sleep/Wake Resilience**: Registers an observer for `NSWorkspace.didWakeNotification` to re-apply HID mappings and re-enable event taps upon system wake.

### 3.2 Chrome Profile Engine (`src/ChromeQuickAccess/Engine/ChromeProfileEngine.swift`)
- **Dynamic Chromium Parsing**: Dynamically parses Chromium `Local State` JSON files (`profile.info_cache`) across Google Chrome, Brave, Microsoft Edge, and Chromium.
- **Avatar & Monogram Rendering**: Resolves custom profile avatars, Google Profile Pictures, or generates high-resolution circular monogram avatars with deterministic color seeding.
- **Native Accessibility Switching**: Uses macOS Accessibility API (`AXUIElementCopyAttributeValue`) traversing the browser's menu bar (`kAXMenuBarAttribute`) to trigger profile switching via `AXMenuItemMarkChar == "✓"` and item selection, eliminating brittle window title matching.
- **Minimized Window Recovery**: Detects minimized windows via `kAXMinimizedAttribute` and unminimizes/raises them without unwanted tab creation.
- **8 Profile Slots**: Supports up to 8 pinned profiles with dynamic drag-and-drop ordering and status synchronization.

### 3.3 App Group Engine (`src/ChromeQuickAccess/Engine/AppGroupEngine.swift`)
- **Universal Pinned Quick Apps**: Maps home-row keys (`T`, `I`, `A`, `N`, `C`) to core toolchains with a 4-slot pinned limit in Free mode (unlimited in Pro).
- **Letter-Cycle Submenus**: When multiple apps share a hotkey or letter group, subsequent presses cycle deterministically across candidates (`1/2 ↻`).
- **MRU Priority**: Prefers frontmost or most recently used open application windows when selecting ambiguous keys.

### 3.4 Copy-on-Select Engine (`src/ChromeQuickAccess/Engine/CopyOnSelectEngine.swift`)
- **Driverless Mouse Tap**: Listens for `leftMouseDown` and `leftMouseUp` via `.cghidEventTap` (`.listenOnly`) with fallback to `NSEvent.addGlobalMonitorForEvents`.
- **Displacement & Multi-Click Trigger**: Triggers automatic clipboard copying if drag displacement exceeds 10pt (`dx > 10 || dy > 10`) or if multi-click (`clickCount > 1`).
- **Modifier Protection**: Ignores drags with `Command` or `Control` held to avoid conflicting with window movements, canvas operations, or Xcode outlet connections.
- **Sensitive App Shielding**: Automatically suspends Copy-on-Select in 1Password, Bitwarden, KeePass, Terminal password prompts, Google Sheets, Microsoft Excel, and interactive canvas components.
- **Loop Prevention & Marking**: Synthesizes `Cmd+C` tagged with `syntheticMarker` (`0x43514150`) to prevent recursive event interception.

### 3.5 Finder Tidy Engine (`src/ChromeQuickAccess/Engine/FinderTidyEngine.swift`)
- **Ceiling Enforcement**: Closes stale background Finder windows when open window count exceeds the configured maximum (default: 3).
- **Duplicate Pruning**: Closes redundant duplicate folder views automatically.
- **Active Window Immunity**: Never closes the frontmost active Finder window or windows hosting open modal sheets.

### 3.6 Antigravity Engine (`src/ChromeQuickAccess/Engine/AntigravityEngine.swift`)
- Discovers `Antigravity` and `Antigravity IDE` application bundles.
- Tracks frontmost application transitions via `NSWorkspace.didActivateApplicationNotification`.
- Provides instant toggle between Antigravity and Antigravity IDE on `caps lock + a`.

### 3.7 Minimal HUD Window (`src/ChromeQuickAccess/Views/MinimalHUDWindow.swift`)
- Non-activating, floating bezel overlay rendered in SwiftUI with AppKit bridging.
- Conforms to macOS Human Interface Guidelines (HIG) with portrait card indicators.
- **Dismissal Guardrail**: Always hidden immediately (`MinimalHUDWindow.shared.hideImmediate()`) BEFORE triggering application activation to avoid window server transition lockouts.

---

## 4. Repository & File Layout

```
nnts/
├── Package.swift                             # Swift Package Manager manifest
├── VERSION.txt                               # Semantic version tracking (2.0.0)
├── BUILD.txt                                 # Build increment counter
├── Makefile                                  # Developer inner loop & CI automation targets
├── build_native_app.sh                       # Universal Mach-O binary & DMG build pipeline
├── bump_version.sh                           # Semantic version bump utility
├── install.sh                                # One-line /Applications installation script
├── release.sh                                # Release tagging & GitHub Actions pipeline
├── assets/                                   # Production branding, fonts, and showcase assets
│   ├── fonts/                                # Space Grotesk Bold, Syne, Archivo Black
│   ├── features/                             # Architecture diagrams & feature assets
│   └── profiles/                             # Canonical sample avatar icons
├── docs/                                     # Architecture documentation & web showcase
│   ├── ARCHITECTURE_SPEC.md                  # Technical architecture specification
│   ├── PRD_LANDING_REDESIGN.md               # Landing page UX/UI PRD
│   └── site/                                 # Official web showcase (modern & retro variants)
├── src/
│   └── ChromeQuickAccess/                    # Core native Swift 6 engine
│       ├── main.swift                        # AppKit application entry point
│       ├── AppDelegate.swift                 # Menu bar status item & action routing
│       ├── Info.plist                        # macOS application bundle metadata
│       ├── Resources/                        # AppIcon & DMG background
│       ├── Engine/
│       │   ├── KeyCodes.swift                # Carbon/AppKit keycode mappings
│       │   ├── CapsLockEngine.swift          # hidutil remapping & event tap modifier router
│       │   ├── AppGroupEngine.swift          # Universal pinned apps & dynamic letter cycling
│       │   ├── ChromeProfileEngine.swift     # Chromium Local State parser & AX switcher
│       │   ├── CopyOnSelectEngine.swift      # Drag & multi-click copy engine
│       │   ├── FinderTidyEngine.swift        # Finder window ceiling enforcement
│       │   ├── AntigravityEngine.swift       # Antigravity app discovery & switcher
│       │   ├── LicenseEngine.swift           # Polar.sh license verification & Keychain storage
│       │   ├── TelemetryBuffer.swift         # Circular PII-sanitized telemetry ring
│       │   ├── DiagnosticBundleService.swift # ZIP diagnostic report generator
│       │   ├── UpdateEngine.swift            # Homebrew Cask & GitHub release update detector
│       │   └── NNTSMotion.swift              # Mascot spring micro-interactions
│       └── Views/
│           ├── MinimalHUDWindow.swift        # Floating bezel HUD overlay
│           ├── SettingsWindow.swift          # Native SwiftUI multi-tab settings panel
│           ├── CopyToastWindow.swift         # Non-intrusive cursor-following copy confirmation
│           ├── ProfileStripView.swift        # 8-slot draggable profile strip
│           ├── FeedbackWindow.swift          # Bug report & telemetry exporter
│           ├── AppSearchPickerWindow.swift   # Pinned app selector modal
│           └── AvatarCaptureAssistantWindow.swift # Clipboard avatar importer
├── scripts/
│   ├── health_check.sh                       # 3-point system health validation
│   ├── monitor_telemetry.sh                  # macOS Unified Logging telemetry monitor
│   ├── watch_dev.sh                          # Continuous file change watcher & reloader
│   ├── build_nnts_font.py                    # Font builder script
│   └── generate_mascot_assets.swift          # Mascot icon asset generator
└── tests/
    ├── run_tests.sh                          # Headless test runner
    └── ChromeQuickAccessTests/               # Swift Testing unit test suites
```
