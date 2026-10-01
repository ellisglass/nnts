# Project: Xomsky (Хомяк) — macOS Productivity Suite (v1.0.0)

> **Positioning:** Утилита для быстрого доступа и интуитивного доступа к выбранным приложениям через **Капслок + Первая Буква Приложения**, со специальной фичей — **быстрый доступ к окнам конкретного хром/брейв профайла через Капс Лок + C/B + 1-4**, и для **копирования текста при выделении** (Copy-on-Select).
>
> **The 3 Core Pains (Why It Exists):**
> 1. *Killer Feature #1:* Окна профилей Chrome/Brave — в macOS системный `Cmd+Tab` не разделяет профили, переключение сломано. `Caps + C/B + 1..4` поднимает окно конкретного профиля.
> 2. *Feature #2:* Доступ к приложениям по первой букве (`Caps + [A–Z]`: `Caps + O` Obsidian, `Caps + S` Spotify/Settings, `Caps + F` Finder, `Caps + T` Telegram/Terminal) с мгновенным циклированием нескольких приложений на одной букве (`1/2 ↻`).
> 3. *Feature #3:* Copy-on-Select — выделил текст = скопировал, устранение 1 000 лишних `Cmd+C` в день.

## Tech Stack & Architecture
- **Target Platform**: macOS 14.0+ (Sonoma, Sequoia, Tahoe).
- **Primary Engine (Swift 6+)**: 100% Pure Native Standalone App (`src/ChromeQuickAccess`) using SwiftUI, AppKit bridging, CoreGraphics `CGEvent` taps, and driverless IOHID remapping.
  - `Engine/KeyCodes.swift`: Virtual keycode definitions and Carbon/AppKit key lookup.
  - `Engine/CapsLockEngine.swift`: Driverless hardware remapping via `hidutil` (Caps-Lock -> F18) and head-insert `CGEventTap` for dedicated application switching modifiers (without green LED blinking).
  - `Engine/AppGroupEngine.swift`: Universal Pinned Quick Apps (4 slots max in Free, unlimited in Pro), dynamic first-letter shortcuts, letter cycling submenus (`1/2 ↻`), dynamic alphabet catalog, and 1-click slot replacement.
  - `Engine/ChromeProfileEngine.swift`: Dynamic Chromium `Local State` discovery, monogram avatar rendering, native macOS Accessibility (`AXUIElement`) menu bar profile switching, and window raising.
  - `Engine/AntigravityEngine.swift`: Discovery and fast cycling for Antigravity & Antigravity IDE.
  - `Engine/CopyOnSelectEngine.swift`: Linux/X11-style automatic clipboard copying on text drag selection (>10pt) and multi-click selection.
  - `Engine/LicenseEngine.swift`: Polar.sh online license verification via non-blocking async `Task` on `@MainActor`, offline caching, and checkout redirection.
  - `Engine/XomskyMotion.swift`: Procedural mascot micro-interactions (blinking, breathing, peek easter egg) using SwiftUI springs.
  - `Views/MinimalHUDWindow.swift`: Non-activating floating bezel HUD overlay with profile avatars and active card indicators.
  - `Views/CopyToastWindow.swift`: Non-intrusive cursor-following HUD toast for copy confirmation with rapid auto-dismiss (<1.2s).
  - `AppDelegate.swift`: Menu bar status item, hotkey routing, and lifecycle management.
  - `main.swift`: Standard native application entry point.

## Key Build, Verification & Operations Commands
- **Run All Tests**: `make test` or `./tests/run_tests.sh` or `swift test`.
- **System Health & Diagnostics**: `make health` or `./scripts/health_check.sh` (3-point validation).
- **Semantic Version Bumping**: `make bump-patch`, `make bump-minor`, `make bump-major` (Synchronizes `VERSION.txt`, `BUILD.txt`, and `Info.plist`).
- **Telemetry & Direct Log Ingestion**:
  - `make monitor`: Real-time streaming from macOS Unified Logging (`os_log` subsystem `com.almosteleven.xomsky`).
  - `make diagnostics`: Aggregated log level and category distribution summary over the last hour.
  - `./scripts/monitor_telemetry.sh errors 30m`: Filter errors and faults directly from system log stream.
- **Validation & Quality Gates**: `make validate` (verifies version synchronization and shell script syntax).
- **Build Native App**: `make native` or `./build_native_app.sh` (Produces universal Mach-O binary & DMG).
- **Generate Checksums**: `make checksums` (Produces SHA-256 `dist/checksums.txt`).
- **Local Installation**: `make install` or `./install.sh` (Installs native app to `/Applications`).
- **Release Automation**: `./release.sh --push` (creates git tag & triggers GitHub Actions cloud release pipeline) or `./release.sh --local` (local build + `gh release create`).

## Code Conventions & Standards
- **Swift & SwiftUI**:
  - Strictly adhere to Swift 6 modern concurrency patterns (`async`/`await`, `@MainActor`, `Sendable`). Avoid legacy GCD / `DispatchQueue` where possible.
  - **Strict Concurrency Captures**: When using `[weak self]` inside a concurrent `@MainActor` `Task`, always safely bind it first (`guard let engine = self else { return }`). Do not pass `self?` directly into the `Task` block.
  - **Explicit Module Imports**: Always include explicit `import AppKit` alongside `import Cocoa` when referencing types like `NSImage`.
  - **Sub-process Execution & ARC**: When executing external CLI utilities synchronously via `Process()`, **always** include `task.waitUntilExit()` (e.g. `/usr/bin/hidutil`, `/usr/bin/open`).
  - **Crucial Distinction**: NEVER execute a long-running GUI application binary directly with `Process().waitUntilExit()`, as this will synchronously block the main thread waiting for the application to terminate. Always delegate GUI launches to `/usr/bin/open` or `NSWorkspace.openApplication`.
  - Adhere to macOS Human Interface Guidelines (HIG) for all SwiftUI views, menus, and HUD overlays.
  - Keep low-level `CGEvent` monitoring/filtering logic strictly separated in `Engine/` services away from SwiftUI Views.
  - **Always** ensure explicit accessibility permission checks (`AXIsProcessTrusted()`) before registering global event taps.
  - Gracefully handle event tap disablement events (`kCGEventTapDisabledByTimeout`, `kCGEventTapDisabledByUserInput`) by re-enabling the tap via `CGEvent.tapEnable(tap: true)`.
  - Instrument structured logs using `os.Logger(subsystem: "com.almosteleven.xomsky", category: ...)` rather than raw `print()` statements.
- **HUD Overlay Lifecycle & Dismissal Order**:
  - **Always hide the HUD overlay window (`MinimalHUDWindow.shared.hideImmediate()`) BEFORE triggering application activation or window focus**. External window launches cause macOS window server transitions that can swallow keyboard events and block the run loop, trapping the HUD on screen if hidden after the launch.
- **Pinned Apps & Universal Catalog Conventions**:
  - Enforce a hard ceiling of 4 pinned app slots. Single-app modes must hide the avatar row in the HUD to prevent visual noise.
  - Letter cycling must group apps deterministically by sanitized first letter.
  - **HUD Shortcut Transparency & Categorization**: Never hide conflicting same-letter application shortcuts in collapsed submenus or nested clicks. Render all apps assigned to the same key transparently with distinct badges (e.g. 1/2 ↻, 2/2 ↻) in a unified Quick Apps list.
  - **System Application Bundle Resolution Guardrail**: Never assume macOS system applications exist in `/Applications`. Always resolve applications dynamically via `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)` or query `/System/Applications` and `/System/Library/CoreServices` for core apps like Finder (`com.apple.finder`) and System Settings (`com.apple.systempreferences`).
- **App Name**: The application is **Xomsky**, never Khomyak. Always use `Xomsky` for the app name, docs, binaries, and releases.
- **Release Verification & Homebrew Cask Gate**:
  - In release pipelines, never update or publish a Homebrew Cask formula (`Casks/xomsky.rb`) until the GitHub release tag is pushed AND the GitHub Actions cloud build has successfully attached the DMG asset. Deterministically verify the remote URL with `curl -sI` and compute the SHA256 checksum directly from the published binary.
- **Concise Release Changelog Mandate**:
  - Whenever cutting, tagging, or announcing a new release, always compile and output a concise, structured bulleted list of changes (Changelog) directly in the release notes and user communication. Group updates into clear categories (`Features`, `Improvements`, `Fixes`, `Branding`), highlighting the tangible user-facing value in 1 sentence per item. Never publish a silent release without a summary.
- **Chromium Profile Automation Guardrail**:
  - **Never match Chromium windows by profile name or title substrings.**
  - **Always automate via native macOS menu bar (`kAXMenuBarAttribute`)**: Target the browser's "Profiles" menu bar item (`getProfilesMenuItems`), select items strictly by position/index, and detect the currently active profile using `AXMenuItemMarkChar == "✓"`.
- **Testing**:
  - Use the modern `Swift Testing` framework (`import Testing`, `@Test`, `#expect`) for all unit tests.
  - Unit tests live in `tests/ChromeQuickAccessTests/ChromeQuickAccessTests.swift`.
  - Tests must run deterministically in headless environments without real GUI spawning.
- **Bash Scripting**:
  - Use defensive bash patterns (`set -euo pipefail`) in all build, verification, and release scripts to prevent silent failures.
- **Telemetry & Bug Reporting UI**: Never auto-transmit telemetry. Do NOT rely on macOS `NSSharingService` (Share Sheet) as it fails to detect standalone apps like Telegram. Use a dual-path custom UI: (1) Draggable ZIP file for direct drag-and-drop into any messenger, and (2) GitHub Issue pre-filled button.
- **Zero Hardcoded Licensing**: Never hardcode Polar promotional codes or offline "giveaway" overrides in the Swift client application. All license validation must execute server-side.
- **Deterministic Buffer Sizing**: Never use arbitrary "magic numbers" for memory bounds, circular buffers, or cache sizes. Always justify the exact integer choice based on empirical calculations and document it.
- **Doubt-Driven Architecture**: Before implementing complex pipelines, explicitly pause to execute an adversarial self-critique. Actively seek out memory leaks, single points of failure, and UX edge cases before writing Swift code.

## Pair Programming & Collaboration Invariants (Active Agent Guidance)
- **Pre-Flight Invariant Protection (Anti-Whiplash Guardrail)**:
  - When the user asks to "поудалять всё лишнее", "вычистить сайт/код", "сократить" or make aggressive cuts, **NEVER immediately delete files, components, or UI blocks**.
  - Always identify and explicitly protect the core invariants (e.g. 3D mascot, CTA button, HUD preview, canonical positioning).
  - Propose a concise 3-5 bullet candidate list of what will be removed *before* editing files, asking: "Оставляем X, Y, Z и удаляем только эти кандидаты?".
- **Adversarial QA & Security Audits (Anti-Sycophancy Guardrail)**:
  - When asked to audit vulnerabilities, security, or edge cases, **NEVER return a superficial "Everything looks good / No issues found"**.
  - Adopt an adversarial Red-Team mindset: assume security leaks or race conditions exist (e.g. password managers in Copy-on-Select, multi-monitor coordinates, uninstalled applications, corrupted Chromium `Local State`).
  - Actively test and formulate at least 2-3 concrete boundary failure scenarios with code line citations.
- **Narrative vs Technical Triage on Chained Audits (Anti-Hallucination Bridge)**:
  - When given an instruction like "реализуй рекомендации аудитора из @[conversation:...]", **NEVER blindly accept speculative lore or fictional branding** (e.g. invented backstory or names).
  - Automatically triage audit recommendations into two buckets: (1) *Technical & UX fixes* (implement immediately), and (2) *Narrative, branding, or copywriting claims* (highlight explicitly and verify with the user before changing files).
- **Bias for Action with Zero-Speech Diffs (Anti-Bureaucracy Guardrail)**:
  - For direct, unambiguous instructions ("сократи README", "поправь опечатку", "почини CSS скролла"), do NOT write long meta-introductions or ask "Should I proceed?".
  - Directly execute the modification, run tests/validations, and present the concise result with a clean diff.
- **Multi-Mac & Clean-State Invariant**:
  - Whenever implementing system integration logic (app discovery, profiles, caches, settings), always account for a "clean machine" state (e.g. first launch, no third-party apps installed, different default Chromium directories) to prevent the "works on my Mac, broken on the other Mac" bug.
- **Draft-First Principle (Code-Over-Conversation)**:
  - Prefer shipping an immediate, working code prototype / MVP (Option A) accompanied by a 1-sentence switch note for alternative options over drafting abstract architectural treatises or asking the user to choose in a vacuum.
- **Fail-Fast Build Gate (Pre-Report Validation)**:
  - Never report a task as complete without executing an automated headless sanity check (`make validate`, `swift test`, or `node -c`) to catch compiler, syntax, or runtime breakages before the user inspects the deliverable.
- **Instant Rollback Checkpoint (Safe Sandbox)**:
  - Prior to initiating non-trivial refactorings, mass deletions, or risky structural changes, create an ephemeral git checkpoint (`git stash create` or transient checkpoint branch) enabling 1-second recovery via single-command rollback.
- **Headless Visual Proof (Visual-First UI Verification)**:
  - When modifying UI, CSS, or layout components, capture a local visual snapshot or render artifact using browser tools before reporting completion, rather than offloading manual rendering and visual inspection to the user.
- **Adaptive Verbosity (Minimalism on High Confidence)**:
  - On unambiguous, high-confidence micro-tasks (bugfixes, typography adjustments, config changes), strictly output a 1-line status statement followed immediately by the diff or artifact link. Eliminate conversational introductions, recapitulations, and polite pleasantries.
