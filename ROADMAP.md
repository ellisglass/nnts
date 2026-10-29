# NNTS — Project Roadmap

> Strategic direction, architecture milestones, and feature backlog for **NNTS** (v2.0.4+).  
> Tracking invariant: Updated across release cycles and persisted in Git-versioned memory.

---

## 1. Vision & Core Value Pillars

NNTS is a native macOS productivity engine engineered to solve three fundamental macOS window and workflow frictions:
1. **Chromium Profile Isolation**: Direct window raising for specific Chrome and Brave profiles via `caps lock` + `c`/`b` + `1..8` in sub-16ms latency.
2. **First-Letter Application Switching**: Instant app jump via `caps lock` + `[a–z]` with deterministic cycling (`1/2 ↻`) for same-letter apps.
3. **Copy-on-Select**: Linux/X11-style automatic clipboard copying on mouse drag (>10pt) and multi-click text selection.

---

## 2. Release Milestones & Status

```
v2.0.0 (Architecture Baseline) ──► v2.0.3 (Modular Core & Avatar Assistant) ──► v2.1.0 (Refinements) ──► v2.2.0 (Extensions)
[SHIPPED & PRODUCTION READY]       [CURRENT PRODUCTION RELEASE]                 [IN-FLIGHT]              [PLANNED BACKLOG]
```

### ✅ v2.0.0 – v2.0.3: Core Architecture & Modularization (Shipped)
- [x] **Driverless Hardware Remapping**: Physical `caps lock` remapped to `F18` (`0x70000006D`) via `/usr/bin/hidutil` with zero kexts and zero green LED blinking.
- [x] **Event Tap Pipeline**: Head-insert `CGEventTap` (.cghidEventTap) for deterministic hotkey routing and sub-16ms switching.
- [x] **Native Accessibility Automation**: Chromium profile window raising using native macOS menu bar (`kAXMenuBarAttribute` -> "Profiles") rather than fragile window title regexes.
- [x] **Zero-Permission Avatar Privacy**: Screen capture permissions (`CGRequestScreenCaptureAccess`) categorically avoided. Avatars imported strictly via clipboard paste (`⌘⌃⇧4`) or local folder selection.
- [x] **Liquid Glass HUD Overhaul**: High-contrast 88% dark obsidian smoke base tint (`MacNativeLiquidGlassBackground`) eliminating glare and background bleed-through.
- [x] **Finder Window Tidy Engine**: Auto-pruning stale duplicate Finder windows and capping open windows to a configurable ceiling.
- [x] **Phase 3 Modular Architecture**: Complete split of monolithic codebase into domain extensions:
  - `src/NNTS/AppDelegate+*.swift` (`Dialogs`, `Hotkeys`, `Mascot`, `StatusMenu`)
  - `src/NNTS/Engine/AppGroupEngine+*.swift` (`ActiveAppTracking`, `PinnedApps`, `Predefined`, `Scanner`)
  - `src/NNTS/Engine/ChromeProfileEngine+*.swift` (`Accessibility`, `Avatars`)
  - `src/NNTS/Views/Settings/` (`GeneralSettingsTab`, `LicenseSettingsTab`, `ShortcutsSettingsTab`)
- [x] **Modular Swift Testing Suite**: 164 unit tests modularized across 10 test suites in `tests/NNTSTests/` running in <3.5 seconds.
- [x] **Unified Packaging**: Clean packaging via `make dev`, `make native`, and `make health`.

---

### 🚧 v2.1.0: Polish, Diagnostics & Hardware Ergonomics (In-Flight)
- [x] **Streamlined Status Menu & Quick Apps Cheat Sheet Submenu (Option 1)**:
  - De-bloated status menu from ~550px down to ~270px native macOS height.
  - Retained Chromium Profiles killer feature (`caps lock + 1..8`) as a clean single-row strip in the root menu.
  - Relocated full Quick Apps catalog into a dedicated `Quick Apps Cheat Sheet (N) ▶` submenu with formatted keycaps `[ X ] App1 · App2`.
  - Disallowed mouse click launches on cheat sheet items to preserve keyboard-first focus; added direct link to Settings Shortcuts tab.
- [x] **Status Menu Visual Matrix Cheat Sheet (Variant B)**:
  - Eliminated cognitive friction from segmented letter tabs (`Chrome 6`, `A 3`, `F 2`, `M 2`).
  - Unified two-tier zero-click matrix displaying Profiles (`caps lock + 1..8`) and Quick Apps (`caps lock + [a–z]`) simultaneously.
  - Stripped 4-layer over-badging (outer ring + icon + LED pip + slot badge); replaced with clean circular clipping, subtle active focus rings, and direct two-line keycap/name labels.
- [x] **Status Menu Pixel-Perfect Alignment & Typography**:
  - Eliminating jagged margins via standardized 18x18 SF Symbols across all menu items and submenus.
  - Unified HUD-style centered browser card in `ProfileStripView` (centered `Google Chrome` header, avatar strip with emerald LED pip and yellow focus ring, centered profile title below; eliminated redundant "Browsers & Profiles" line and verbose subtitles).
  - Cadmium yellow `PRO` status badge honoring active license tier in About item.
- [ ] **Multi-Display Coordinate Bounding**:
  - Dynamically detect active mouse screen coordinates during `caps lock` press.
  - Anchor the floating HUD bezel (`MinimalHUDWindow`) to the active screen center rather than main display center on multi-monitor rigs.
- [ ] **HUD Motion & Spring Physics**:
  - Integrate Emil Kowalski motion curves for card selection and profile strip switching.
  - Implement smooth focus ring translation using `.matchedGeometryEffect` across profile cards.
- [ ] **Extended Chromium Browser Family**:
  - Expand `ChromeProfileEngine` discovery to support Arc (`com.thebrowser.Company.Arc`) and Microsoft Edge (`com.microsoft.edgemac`) `Local State` schemas.
- [ ] **Swift 6 Toolchain Deprecation Cleanup**:
  - Remove redundant `swift-testing` package dependency from `Package.swift` to silence toolchain deprecation warnings on Xcode 16 / Swift 6.
- [ ] **Fuzzy Settings Search**:
  - Filter assigned hotkeys, applications, and browser slots in `ShortcutsSettingsTab` with a quick search field.

---

### 📋 v2.2.0: Deep Integration & Extensibility (Planned Backlog)
- [ ] **Custom Script Layer**:
  - Allow users to bind custom shell scripts or AppleScripts to arbitrary `caps lock` key combinations in Settings.
- [ ] **Local Peer-to-Peer Profile Sync**:
  - Export and import profile mappings and custom avatars via encrypted local bundle (`.nntsbackup`) with zero cloud telemetry.
- [ ] **Launcher URL Scheme**:
  - Expose `nnts://profile/{browser}/{slot}` and `nnts://app/{letter}` URL scheme for Raycast, Alfred, and Shortcuts integration.
- [ ] **Automatic Conflict Resolution Visualizer**:
  - Dedicated interactive conflict graph in Settings showing multi-app letter collision rings and switch ordering.

---

## 3. Engineering Invariants & Quality Standards

1. **Strict Lowercase `caps lock`**: Written as `caps lock` everywhere in UI, docs, and assets.
2. **Canonical Brand Typeface**: Space Grotesk Bold (`assets/fonts/SpaceGrotesk-Bold.ttf`).
3. **HUD Dismissal Lifecycle**: `MinimalHUDWindow.shared.hideImmediate()` must execute strictly BEFORE window focus or app activation.
4. **Zero Screen Recording Permissions**: Avatars must never require macOS Screen Recording permissions.
5. **Driverless Native Remap**: Remapping must remain 100% native via `hidutil` with automatic teardown on exit.
6. **Sub-4s Automated Test Gate**: `make test` must pass 100% of tests with execution under 4 seconds in headless environments.
7. **Zero-Manual-Make Developer Loop**: Every Swift change must be verified and live-deployed to `/Applications/NNTS.app` via `make dev` before completing the turn.
