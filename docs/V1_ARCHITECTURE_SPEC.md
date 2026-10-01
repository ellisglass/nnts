# Architecture & Specification: Xomsky — v1.1.7

## 1. Vision & Core Objective
**Xomsky** — утилита для быстрого доступа к окнам конкретного профиля Chrome/Brave через **Капс Лок + C/B + 1-4**, интуитивного доступа к выбранным приложениям через **Капслок + Первая Буква Приложения**, и для **копирования текста при выделении** (Copy-on-Select).

Built in pure native Swift 6 and SwiftUI, it operates as a driverless standalone application providing:
1. **Специальная фича (#1 Killer Feature): быстрый доступ к окнам конкретного Chrome/Brave профиля (`Caps-Lock + C/B + 1..4`)**: Мгновенный переход к окнам конкретного профиля браузера без скриптов AppleScript и без открытия пустых вкладок.
2. **Быстрый доступ к выбранным приложениям (`Caps-Lock + Первая Буква Приложения`)**: Интуитивное переключение на выбранные приложения по их первой букве (`Caps + [A–Z]`: Obsidian `O`, Spotify `S`, Terminal `T`, Notes `N`, Finder `F` и др.) с поддержкой мгновенного циклирования дубликатов (`1/2 ↻`) и до 4 закрепленных слотов (без ограничений в Pro).
3. **Копирование текста при выделении (Copy-on-Select)**: Автоматическое копирование в буфер обмена в стиле Linux/X11 при выделении текста мышью (>10pt) с тактильным всплывающим уведомлением (HUD toast).
4. **Non-Activating Floating Bezel HUD**: Visual feedback showing profile/application avatars, dismissible before window focus transitions.

### 1.1 Architectural Genesis (The 3 Core Frictions)
Xomsky was engineered around the "missing limb effect" — the visceral friction experienced when the utility is disabled:
1. **The Root Friction (#1 Killer Feature): Browser Profile Windows (`Caps + C/B + 1..4`)**: macOS cannot natively navigate windows by browser profile. `Cmd + Tab` groups all windows under one process; `Cmd + \`` forces blind sequential cycling across unrelated windows. Xomsky targets profile windows directly by index via `AXUIElement`.
2. **Focal Continuity (#2): First-Letter Application Jump (`Caps + [A–Z]`)**: Once the hand rests on Caps Lock, typing app names into Spotlight or Raycast is redundant cognitive friction. Single-keystroke jump to Obsidian (`O`), Spotify (`S`), Terminal (`T`), Notes (`N`), Finder (`F`) с прозрачным циклированием нескольких приложений на одной букве (`1/2 ↻`).
3. **Intent-Action Synthesis (#3): Universal Copy-on-Select**: 99.9% of mouse text selections are intended for copying. Xomsky eliminates thousands of redundant `Cmd + C` keystrokes daily.

---

## 2. Keystroke & Interaction Flow

```
                     ┌────────────────────────────────────────┐
                     │          Physical Caps-Lock            │
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
   (No action / No Escape)                                    ├── 'C': Cycle Chrome profiles
                                                              ├── 'B': Cycle Brave profiles
                                                              ├── '1'..'4': Direct profile index jump
                                                              ├── '[A–Z]': Dynamic First-Letter App Jump (with duplicate cycling 1/2 ↻)
                                                              ├── 'Tab' / 'Shift-Tab': Navigate HUD
                                                              ├── 'Escape': Cancel HUD
                                                              └── Arrows: Navigate Left/Right
```

---

## 3. Subsystem Architecture

### 3.1 CapsLock Engine (`src/ChromeQuickAccess/Engine/CapsLockEngine.swift`)
- **Driverless Remapping**: Uses macOS `hidutil property --set` to map Caps-Lock (`0x700000039`) to F18 (`0x70000006D`). Restores default mapping upon application termination.
- **Head-Insert Event Tap**: Intercepts `keyDown`, `keyUp`, and `flagsChanged` via `.cghidEventTap`.
- **Modifier State Machine**: Tracks physical F18 events and isolates external multi-modifier (`Cmd+Opt+Ctrl+Shift`) state, ensuring modifier keys (e.g. Shift during Shift-Tab navigation) never cause premature Caps-Lock release. Physical Caps Lock acts purely as a dedicated modifier without synthetic Escape side effects or LED toggling.
- **Sleep/Wake Resilience**: Registers an observer for `NSWorkspace.didWakeNotification` to re-apply HID mappings and re-enable event taps upon system wake.

### 3.2 Chrome Profile Engine (`src/ChromeQuickAccess/Engine/ChromeProfileEngine.swift`)
- **Zero Hardcoding**: Dynamically parses Chromium `Local State` JSON files (`profile.info_cache`) across Google Chrome, Brave, Microsoft Edge, and Chromium.
- **Avatar & Monogram Rendering**: Resolves custom profile avatars, Google Profile Pictures, or generates high-resolution circular monogram avatars with deterministic color seeding.
- **Native Accessibility Switching**: Uses macOS Accessibility API (`AXUIElementCopyAttributeValue`) traversing the browser's menu bar (`kAXMenuBarAttribute`) to trigger profile switching via `AXMenuItemMarkChar == "✓"` and item selection, eliminating brittle window title matching.
- **Minimized Window Recovery**: Detects minimized windows via `kAXMinimizedAttribute` and unminimizes/raises them without unwanted tab creation.

### 3.3 App Group Engine (`src/ChromeQuickAccess/Engine/AppGroupEngine.swift`)
- **Universal Pinned Quick Apps**: Maps home-row keys (`T`, `I`, `A`, `N`, `C`) to core toolchains with a strict 4-slot pinned limit.
- **Letter-Cycle Submenus**: When multiple apps share a hotkey or letter group, subsequent presses cycle deterministically across candidates.
- **Slot Replacement**: Allows users to replace pinned slots in 1 click from the menu bar or settings without restarting the daemon.
- **Single-App Mode Optimization**: Automatically hides the avatar card row in HUD overlay when an app group contains only a single candidate.

### 3.4 Antigravity Engine (`src/ChromeQuickAccess/Engine/AntigravityEngine.swift`)
- Discovers `Antigravity` and `Antigravity IDE` application bundles.
- Tracks frontmost application transitions via `NSWorkspace.didActivateApplicationNotification`.
- Provides instant toggle between Antigravity and Antigravity IDE on `Caps-Lock + A`.

### 3.5 Copy-on-Select Engine (`src/ChromeQuickAccess/Engine/CopyOnSelectEngine.swift`)
- **Driverless Mouse Tap**: Listens for `leftMouseDown` and `leftMouseUp` via `.cghidEventTap` (`.listenOnly`) with fallback to `NSEvent.addGlobalMonitorForEvents`.
- **Displacement & Multi-Click Trigger**: Triggers automatic clipboard copying if drag displacement exceeds 10pt (`dx > 10 || dy > 10`) or if multi-click (`clickCount > 1`).
- **Modifier Protection**: Ignores drags with `Command` or `Control` held to avoid conflicting with window movements, canvas operations, or Xcode outlet connections.
- **Loop Prevention & Marking**: Synthesizes `Cmd+C` tagged with `syntheticMarker` (`0x43514150`) to prevent recursive event interception.
- **Auto-Recovery**: Recovers automatically if the event tap is disabled by macOS timeout (`tapDisabledByTimeout`).

### 3.6 Minimal HUD Window (`src/ChromeQuickAccess/Views/MinimalHUDWindow.swift`)
- Non-activating, floating bezel overlay rendered in SwiftUI with AppKit bridging.
- Conforms to macOS Human Interface Guidelines (HIG) with portrait card indicators.
- Dismissal Guardrail: Always hidden immediately (`MinimalHUDWindow.shared.hideImmediate()`) BEFORE triggering application activation to avoid window server transition lockouts.

---

## 4. File Layout

```
xomsky/
├── Package.swift                             # Swift Package Manager manifest
├── VERSION.txt                               # Semantic version tracking (1.0.0)
├── BUILD.txt                                 # Build increment counter (1)
├── Makefile                                  # Convenience targets (build, test, health, bump)
├── build_native_app.sh                       # Universal Mach-O binary & DMG build pipeline
├── bump_version.sh                           # Semantic version bump utility
├── install.sh                                # /Applications installation script
├── release.sh                                # Production build & GitHub release automation
├── assets/                                   # Production branding & UI assets
│   ├── explorations/                         # Icon matrices & design exploration archive
│   └── features/                             # README feature infographics
├── docs/                                     # Architecture & Neuroaesthetics brandbooks
│   ├── site/                                 # Official interactive 3D website & web demo
│   ├── BRANDBOOK_BAUHAUS_EDITION.md          # Geometric deconstruction brandbook
│   ├── BRANDBOOK_NEUROAESTHETICS.md          # Neuroaesthetic design hierarchy
│   └── V1_ARCHITECTURE_SPEC.md               # Technical specification
├── src/
│   └── ChromeQuickAccess/
│       ├── main.swift                        # AppKit application entry point
│       ├── AppDelegate.swift                 # Menu bar status item & action routing
│       ├── Info.plist                        # macOS application bundle metadata
│       ├── Resources/                        # AppIcon & DMG background
│       ├── Engine/
│       │   ├── KeyCodes.swift                # Carbon virtual keycode mappings
│       │   ├── CapsLockEngine.swift          # hidutil remapping & event tap modifier router
│       │   ├── AppGroupEngine.swift          # 5-app toolkit & dynamic letter cycling
│       │   ├── ChromeProfileEngine.swift     # Chromium Local State parser & AX switcher
│       │   ├── AntigravityEngine.swift       # Antigravity app discovery & switcher
│       │   └── CopyOnSelectEngine.swift      # Drag & multi-click copy engine
│       └── Views/
│           └── MinimalHUDWindow.swift        # Floating bezel HUD overlay
├── scripts/
│   ├── generate_media_assets.py              # PIL asset rendering utility
│   ├── health_check.sh                       # 3-point system health validation
│   └── monitor_telemetry.sh                  # macOS Unified Logging telemetry monitor
└── tests/
    ├── run_tests.sh                          # Headless test runner
    └── ChromeQuickAccessTests/
        └── ChromeQuickAccessTests.swift      # 50 Swift Testing unit tests
```
