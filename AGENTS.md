# Project: NNTS — macOS Productivity Suite (v2.0.4+)

> **Positioning:** Fast and intuitive macOS productivity engine providing dedicated application switching via **caps lock + first letter of app**, instant Chromium profile window raising via **caps lock + c/b + 1–8**, and Linux/X11-style **Copy-on-Select** (copy upon mouse drag selection).
>
> **The 3 Core Pains (Why It Exists):**
> 1. *Killer Feature #1:* Chromium profile windows — macOS system `Cmd+Tab` groups all browser profiles under one process. `caps lock + c/b + 1..8` brings the exact profile window to focus in under 16ms.
> 2. *Feature #2:* First-letter application jump (`caps lock + [a–z]`: `caps lock + o` Obsidian, `caps lock + s` Spotify/Settings, `caps lock + f` Finder, `caps lock + t` Telegram/Terminal) with deterministic cycling between duplicate apps on the same letter (`1/2 ↻`).
> 3. *Feature #3:* Copy-on-Select — selecting text automatically copies it to the clipboard, eliminating 1,000 redundant `Cmd+C` keystrokes daily.

---

## 1. Tech Stack & Modular Architecture

- **Target Platform**: macOS 14.0+ (Sonoma, Sequoia, Tahoe).
- **Primary Toolchain**: 100% Pure Native Standalone App (`src/NNTS`) written in Swift 6+ (Strict Concurrency, `@MainActor`, `Sendable`), SwiftUI, AppKit bridging, CoreGraphics `CGEvent` taps, and IOHID remapping.
- **Unified Logging Subsystem**: `com.almosteleven.nnts`.
- **Git-Versioned Memory**:
  - Milestones & Backlog: [ROADMAP.md](file:///Users/igorekishev/Igor/igorekishev/mac-productivity-suite/ROADMAP.md)
  - Architecture Decision Records: [DECISIONS.md](file:///Users/igorekishev/Igor/igorekishev/mac-productivity-suite/DECISIONS.md)

### Subsystem Structure (`src/NNTS/`):
- `Engine/KeyCodes.swift`: Virtual keycode definitions and Carbon/AppKit key lookup.
- `Engine/CapsLockEngine.swift`: Driverless hardware remapping via `hidutil` (caps lock -> F18) and head-insert `CGEventTap` for dedicated application switching modifiers (without green LED blinking).
- `Engine/AppGroupEngine.swift`: Universal Pinned Quick Apps (4 slots max in Free, unlimited in Pro), dynamic first-letter shortcuts, letter cycling submenus (`1/2 ↻`), and modular extensions (`+ActiveAppTracking.swift`, `+PinnedApps.swift`, `+Predefined.swift`, `+Scanner.swift`).
- `Engine/ChromeProfileEngine.swift`: Dynamic Chromium `Local State` discovery, monogram avatar rendering, native macOS Accessibility (`AXUIElement`) menu bar profile switching, and extensions (`+Accessibility.swift`, `+Avatars.swift`).
- `Engine/AntigravityEngine.swift`: Discovery and fast cycling for Antigravity & Antigravity IDE.
- `Engine/CopyOnSelectEngine.swift` & `CopyOnSelectFilterRules.swift`: Linux/X11-style automatic clipboard copying on text drag selection (>10pt) and multi-click selection with application immunity filters.
- `Engine/FinderTidyEngine.swift`: Finder window ceiling cap and stale duplicate window auto-pruning.
- `Engine/DiagnosticBundleService.swift`, `TelemetryBuffer.swift`, `UpdateEngine.swift`: Unified diagnostic archives, bounded ring buffers, and Homebrew update checks.
- `Engine/LicenseEngine.swift`: Polar.sh online license verification via non-blocking async `Task` on `@MainActor`, offline caching, and checkout redirection.
- `Engine/NNTSMotion.swift` & `NNTSDesignTokens.swift`: Procedural mascot micro-interactions (`NNTSMotion`) and design tokens.
- `Views/MinimalHUDWindow.swift`, `HUDCardView.swift`, `RetroHUDComponents.swift`, `ProfileStripView.swift`: Non-activating floating bezel HUD overlay with profile avatars and active card indicators.
- `Views/Settings/`: Modular settings tabs (`GeneralSettingsTab.swift`, `LicenseSettingsTab.swift`, `ShortcutsSettingsTab.swift`, `SettingsViewModel.swift`, `SettingsWindow.swift`).
- `Views/CopyToastWindow.swift`, `FeedbackWindow.swift`, `AvatarCaptureAssistantWindow.swift`, `AppSearchPickerWindow.swift`: Auxiliary floating and feedback windows.
- `AppDelegate.swift`: Modular lifecycle and menu management (`+Hotkeys.swift`, `+StatusMenu.swift`, `+Mascot.swift`, `+Dialogs.swift`).
- `main.swift`: Standard native application entry point.

---

## 2. Key Build, Verification & Operations Commands

- **Developer Inner Loop (Fast Host Build & Relaunch)**: `make dev` or `make run` or `./build_native_app.sh --run` (Compiles host arch with `-Onone`, updates `/Applications/NNTS.app` and relaunches instantly without password).
- **Continuous Live Watcher**: `make watch` or `./scripts/watch_dev.sh` (Monitors `src/` and automatically rebuilds/relaunches upon file save).
- **Run All Tests**: `make test` or `./tests/run_tests.sh` or `swift test`.
- **System Health & Diagnostics**: `make health` or `./scripts/health_check.sh` (3-point validation).
- **Semantic Version Bumping**: `make bump-patch`, `make bump-minor`, `make bump-major` (Synchronizes `VERSION.txt`, `BUILD.txt`, and `Info.plist`).
- **Telemetry & Direct Log Ingestion**:
  - `make monitor`: Real-time streaming from macOS Unified Logging (`os_log` subsystem `com.almosteleven.nnts`).
  - `make diagnostics`: Aggregated log level and category distribution summary over the last hour.
  - `./scripts/monitor_telemetry.sh errors 30m`: Filter errors and faults directly from system log stream.
- **Validation & Quality Gates**: `make validate` (verifies version synchronization and shell script syntax).
- **Build Native App**: `make native` or `./build_native_app.sh` (Produces universal Mach-O binary & DMG).
- **Generate Checksums**: `make checksums` (Produces SHA-256 `dist/checksums.txt`).
- **Local Installation**: `make install` or `./install.sh` (Installs native app to `/Applications`).
- **Release Automation**: `./release.sh --push` (triggers GitHub Actions cloud release pipeline) or `./release.sh --local` (local build + `gh release create`).

---

## 3. Core Technical Invariants & Guardrails

1. **HUD Overlay Dismissal Lifecycle**:
   - **Always hide the HUD overlay window (`MinimalHUDWindow.shared.hideImmediate()`) BEFORE triggering application activation or window focus transitions**. External window server transitions swallow keyboard events and block the run loop, trapping the HUD on screen if hidden after focus.
2. **Chromium Profile Automation Guardrail**:
   - **Never match Chromium windows by profile name or title substrings.**
   - **Always automate via native macOS menu bar (`kAXMenuBarAttribute`)**: Target the browser's "Profiles" menu bar item, select items strictly by position/index, and detect the currently active profile using `AXMenuItemMarkChar == "✓"`.
3. **Zero-Permission Avatar Handling & Screen Privacy**:
   - **Categorically avoid requesting macOS Screen Recording permissions (`CGRequestScreenCaptureAccess`)** or executing system screen captures (`/usr/sbin/screencapture`).
   - Profile avatars are imported exclusively via clipboard paste (`⌘⌃⇧4`) or local user folder selection (`importAvatarsFromFolder`), guaranteeing absolute screen privacy without scary TCC dialogs.
4. **Swift 6 Strict Concurrency & Actor Isolation**:
   - Adhere to Swift 6 modern concurrency patterns (`async`/`await`, `@MainActor`, `Sendable`). Avoid legacy GCD / `DispatchQueue` where possible.
   - When using `[weak self]` inside a concurrent `@MainActor` `Task`, always safely bind it first (`guard let self = self else { return }`). Do not pass `self?` directly into the `Task` block.
5. **Sub-process Execution & GUI App Launches**:
   - When executing external CLI utilities synchronously via `Process()`, **always** include `task.waitUntilExit()` (e.g. `/usr/bin/hidutil`, `/usr/bin/open`).
   - **Crucial Distinction**: NEVER execute a long-running GUI application binary directly with `Process().waitUntilExit()`, as this will synchronously block the main thread waiting for the application to terminate. Always delegate GUI launches to `/usr/bin/open` or `NSWorkspace.openApplication`.
6. **System Application Bundle Resolution**:
   - Never assume macOS system applications exist in `/Applications`. Always resolve applications dynamically via `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)` or query `/System/Applications` and `/System/Library/CoreServices` for core apps like Finder (`com.apple.finder`) and System Settings (`com.apple.systempreferences`).
7. **Pinned Apps & Universal Catalog**:
   - Enforce a hard ceiling of 4 pinned app slots in Free mode.
   - Never hide conflicting same-letter application shortcuts in collapsed submenus. Render all apps assigned to the same key transparently with distinct badges (e.g. 1/2 ↻, 2/2 ↻) in a unified Quick Apps list.
8. **Testing Standards**:
   - Use the modern `Swift Testing` framework (`import Testing`, `@Test`, `#expect`) for all unit tests.
   - Unit tests live in `tests/NNTSTests/` (10 domain-specific suites, 164 automated tests).
   - Tests must run deterministically in headless environments without real GUI spawning.

---

## 4. Brand & Identity Invariants

1. **Strict Lowercase "caps lock" Invariant**:
   - Categorically never write "Caps", "CAPS", "Caps Lock", or "Caps lock" in marketing copy, documentation, graphics, promotional assets, or user-facing text.
   - Always write `caps lock` in full lowercase, two words.
2. **Canonical Brand Typeface (Space Grotesk Bold)**:
   - Space Grotesk Bold is the official, locked brand and display typeface for NNTS across all promotional graphics, bento grids, showcases, and web UI. Static font files reside in `assets/fonts/SpaceGrotesk-Bold.ttf`.
3. **Strict English-Only Deliverables & Assets**:
   - All promotional graphics, marketing bento grids, screenshots, README files, documentation, release notes, and UI assets must be strictly in English. Categorically never generate, maintain, or commit Russian-language graphic variants or localizations.
4. **App Name**:
   - The application is **NNTS**. Always use `NNTS` for the app name, docs, binaries, and releases.

---

## 5. Pair Programming & Collaboration Invariants

1. **Live App Rebuild & Relaunch Invariant (Zero-Manual-Make)**:
   - Whenever modifying native Swift application code (`src/NNTS/`), **NEVER** instruct or expect the user to run `make dev`, `make run`, `make native`, or `make install`.
   - ALWAYS automatically execute `make dev` via `run_command` immediately after tests pass. The updated binary must already be deployed to `/Applications/NNTS.app` and running live before handing the turn back to the user.
2. **Fail-Fast Build Gate (Pre-Report Validation)**:
   - Never report a task as complete without executing an automated headless sanity check (`make validate`, `make test`, or `swift test`) to catch compiler, syntax, or runtime breakages before the user inspects the deliverable.
3. **Pre-Flight Invariant Protection (Anti-Whiplash Guardrail)**:
   - When the user asks to "поудалять всё лишнее", "вычистить сайт/код", "сократить" or make aggressive cuts, **NEVER immediately delete files, components, or UI blocks**.
   - Always identify and explicitly protect core invariants (mascot, CTA button, HUD preview, canonical positioning). Propose a concise 3-5 bullet candidate list of what will be removed *before* editing files.
4. **Adversarial QA & Boundary Testing**:
   - When asked to audit vulnerabilities, security, or edge cases, adopt an adversarial Red-Team mindset. Actively test and formulate concrete boundary failure scenarios with code line citations.
5. **Atomic Test Synchronization During Code Refactoring**:
   - When removing or renaming classes, methods, or properties in `src/NNTS/`, update or prune corresponding unit test assertions in `tests/NNTSTests/` in the same atomic change. Never leave orphaned symbols in test suites that break `make test`.
6. **Bias for Action with Zero-Speech Diffs**:
   - For direct, unambiguous instructions ("сократи README", "поправь опечатку", "почини CSS скролла"), do NOT write long meta-introductions or ask "Should I proceed?". Directly execute the modification, run tests/validations, and present the concise result with a clean diff.
7. **Session Memory & Persistence**:
   - When tasks complete or architectural decisions are made, persist them directly to Git-versioned memory: update [ROADMAP.md](file:///Users/igorekishev/Igor/igorekishev/mac-productivity-suite/ROADMAP.md) for milestone progress and [DECISIONS.md](file:///Users/igorekishev/Igor/igorekishev/mac-productivity-suite/DECISIONS.md) for new ADRs.
8. **Fast-Path Context Resolution (Zero Sequential Exploration Trap)**:
   - **Categorically never execute sequential single-file read chains (`read_file` -> `read_file` -> `read_file`...) across multiple turns** when researching UI components, features, or bug traces.
   - **Direct & Bounded Search**: Localize target symbols, view structures, and call sites directly using bounded `rg` or `git grep`. Avoid unnecessary graph hops for local UI and styling tasks.
   - **Strict Read Batching**: When source inspection is needed, batch 2–4 targeted `read_file` calls in a single turn. Pre-flight context gathering must never exceed 1–2 turns before writing or modifying code.
