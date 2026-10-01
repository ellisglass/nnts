---
name: xomsky-distilled-principles
description: "Core architectural, UI/UX, hardware fidelity, Polar monetization, and macOS system invariants for the Khomyak / Xomsky application and landing page."
metadata:
  origin: rules-distill
  distilled_sessions: 20
---

# Xomsky (Khomyak) Core Product & System Invariants

This skill codifies the complete set of hard-won engineering, design, monetization, and system rules extracted from the production sessions across the **Xomsky (Khomyak)** ecosystem (native Swift 6 macOS app, WebGL landing page, and Polar monetization). Generic generative AI rules are strictly excluded.

## 1. Native Swift 6 Engine & macOS System Invariants

- **`driverless-hardware-remapping-no-led`**:
  Remap Caps Lock to dedicated modifier (F18) using driverless hardware remapping via `/usr/bin/hidutil` property matching (`UserKeyMapping`), paired with a head-insert `CGEventTap` to intercept physical keydowns without triggering the macOS Caps Lock green LED or toggling capital letters.
  *Violation Risk*: Caps Lock modifier usage desynchronizes case state, triggers distracting green LED blinks, and causes driver instability across macOS versions.

- **`system-app-bundle-resolution`**:
  Never assume macOS system applications exist in `/Applications`. Always resolve applications dynamically via `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)` or search `/System/Applications` and `/System/Library/CoreServices` for core apps like Finder (`com.apple.finder`) and System Settings (`com.apple.systempreferences`).
  *Violation Risk*: Core macOS system utilities fail to launch or pin to quick slots, breaking user workflows.

- **`hud-overlay-dismissal-precedence`**:
  Always hide the HUD overlay window (`MinimalHUDWindow.shared.hideImmediate()`) BEFORE triggering application activation (`NSWorkspace.openApplication`) or window focus transitions.
  *Violation Risk*: Window server focus races swallow keyboard events, lock the run loop, and leave the HUD permanently stuck on screen.

- **`hud-shortcut-transparency-and-split-sections`**:
  Never hide conflicting same-letter application shortcuts in collapsed submenus or nested clicks. Render all apps assigned to the same key transparently with distinct badges, and cleanly demarcate pinned Toolset Shortcuts from dynamic Quick Shortcuts.
  *Violation Risk*: Breaks muscle memory and increases cognitive friction for power users.

- **`chromium-profile-native-accessibility-menu-automation`**:
  Never match Chromium profile windows by window title or profile name substrings. Automate profile switching strictly via the browser's native macOS "Profiles" menu bar item (`kAXMenuBarAttribute`, `getProfilesMenuItems`), selecting items by exact position/index and detecting active state via `AXMenuItemMarkChar == "✓"`.
  *Violation Risk*: Title-based profile matching breaks whenever page tabs change titles, or in localized browser installations.

- **`copy-on-select-distance-and-multi-click-threshold`**:
  Automatic Linux/X11-style clipboard copying (`CopyOnSelectEngine`) must strictly require a drag distance threshold (>10pt) or explicit multi-click selection (double/triple click) before writing to `NSPasteboard.general`. Never copy on trivial mouse clicks or micro-jitters (<10pt). Pair with non-intrusive cursor-following toast (`CopyToastWindow`) with rapid auto-dismiss (<1.2s).
  *Violation Risk*: Overwrites user clipboard history on accidental mouse clicks and causes visual toast spam.

## 2. Polar.sh Monetization & Licensing Architecture

- **`polar-licensing-async-validation`**:
  Online Polar license key validation (`LicenseEngine`) must always execute in a non-blocking asynchronous `Task` on `@MainActor` with graceful offline fallback and explicit network failure messaging. Never block the UI thread during license key verification or checkout redirection (`LicenseEngine.polarCheckoutUrl`).
  *Violation Risk*: Network timeouts or server latency freeze the entire macOS application main run loop during startup or license activation.

## 3. Product Naming

- **`app-name-xomsky`**:
  The application is **Xomsky**, never Khomyak. Always use `Xomsky` for the app name, docs, binaries, and releases.

## 4. Release Automation & Resilience

- **`cloud-release-sync-and-homebrew-cask-resilience`**:
  In release pipelines, never update or publish a Homebrew Cask formula (`Casks/xomsky.rb`) until the GitHub release tag is pushed AND the GitHub Actions cloud build has successfully attached the DMG asset. Deterministically verify the remote URL with `curl -sI` and compute the SHA256 checksum directly from the published binary.
  *Violation Risk*: Broken installation for all Homebrew users experiencing 404 Not Found or checksum mismatch errors.

## 5. Development & CI/CD Invariants

- **`opt-in-local-telemetry-and-export`**:
  Never implement silent, auto-transmitting remote crash reporting. Buffer logs locally (e.g., using a deterministic `os_log` ring buffer). Do NOT rely on macOS `NSSharingService` (Share Sheet) to export logs, as it often fails to detect standalone apps like Telegram (.dmg). Instead, present a custom feedback UI window providing two reliable paths: (1) A draggable ZIP file proxy (drag-and-drop directly into any messenger) and (2) A button to open a GitHub Issue with pre-filled URL parameters.
  *Violation Risk*: Silently sending data violates privacy. Relying on macOS Share Sheet leads to missing messaging apps and frustrated users.

- **`zero-hardcoded-secrets-and-promo`**:
  Never hardcode promotional codes, bypass keys, or offline "giveaway" overrides in the Swift client application or public GitHub repository. All license validation, including 100% discount promotions, must be strictly delegated to the server-side Polar API.
  *Violation Risk*: Source code leaks secrets, leading to uncontrollable pirate bypasses.

- **`atomic-release-and-homebrew-pipeline`**:
  The CI/CD release pipeline must be fully atomic. A push to `main` (or tag) must compile the DMG, publish the GitHub Release, and *immediately/automatically* update the Homebrew Cask formula (`Casks/xomsky.rb`) with the correct version and SHA256 checksum in the same automated flow. Never treat Homebrew updates as an isolated manual step.
  *Violation Risk*: Users downloading via Homebrew receive outdated binaries or 404/Checksum errors when the Cask falls behind the GitHub release.

- **`deterministic-magic-numbers`**:
  When defining memory bounds, circular buffers, or cache sizes in the Swift engine, never use arbitrary "magic numbers" guessed by the LLM. Always justify the exact integer choice based on empirical calculations (e.g., average log string bytes * N limits = max memory footprint) and document the rationale in inline comments.
  *Violation Risk*: Unjustified buffer sizes lead to silent OOM (Out of Memory) crashes or truncated critical logs.

- **`adversarial-design-critique`**:
  Before implementing complex features (licensing, telemetry pipelines, global event taps), explicitly pause to execute an adversarial self-critique of the proposed design. Actively seek out memory leaks, race conditions, single points of failure, and UX edge cases in the plan before writing the first line of Swift code.
  *Violation Risk*: Shipping fundamentally flawed architecture that requires complete rewrites days later.

- **`concise-release-changelog-mandate`**:
  Whenever cutting, tagging, or announcing a new release, always generate and attach a concise bulleted changelog (List of Changes) directly in the release notes and user response. Group changes into clear categories (`Features`, `Improvements`, `Fixes`, `Branding`), stating the tangible user-facing value in 1 sentence per item.
  *Violation Risk*: Users and maintainers receive opaque version bumps without visibility into what changed or broke.

## 6. Active Pair-Programming & Collaboration Guardrails

- **`preflight-invariant-protection-anti-whiplash`**:
  When requested to delete, clean up, or drastically reduce components/code/assets, never execute deletions immediately. First identify and protect core invariants (3D mascot, CTA buttons, HUD preview, brand assets), and propose a 3-5 bullet candidate removal list for user confirmation before modifying files.
  *Violation Risk*: Accidental destruction of prized visual/code components requiring hundreds of turns to recover.

- **`adversarial-qa-anti-sycophancy`**:
  When asked to audit security, performance, or edge cases, never return a superficial "Everything looks good / No issues found". Adopt an adversarial Red-Team mindset, actively probe boundary scenarios (e.g. password managers, race conditions, clean macOS states), and document at least 2-3 concrete failure vectors.
  *Violation Risk*: Critical vulnerabilities and bugs slip into release builds undetected.

- **`narrative-technical-audit-triage`**:
  When executing recommendations from previous audit sessions (`@[conversation:...]`), strictly separate technical/UX action items from subjective branding/copywriting claims. Implement technical fixes immediately, but verify narrative or lore changes with the user before editing files.
  *Violation Risk*: Hallucinated branding stories (e.g. invented backstory) get permanently committed into documentation and code.

- **`bias-for-action-zero-speech-diffs`**:
  For clear, direct task commands, avoid long meta-explanations or hesitation ("Should I proceed?"). Modify files directly, verify syntax/builds, and present the result with a concise diff.
  *Violation Risk*: Extra turn overhead and user fatigue from repetitive confirmations.

- **`draft-first-code-over-conversation`**:
  Prefer shipping an immediate working code prototype / MVP over drafting speculative architecture choices.
  *Violation Risk*: Decision paralysis and prolonged discussion cycles before seeing tangible progress.

- **`fail-fast-build-gate`**:
  Never report completion without executing an automated headless sanity check (`make validate`, `swift test`, `node -c`).
  *Violation Risk*: Regressions, syntax errors, and broken layouts passed onto the user for manual QA.

- **`instant-rollback-checkpoint`**:
  Create an ephemeral git checkpoint (`git stash create` or transient branch) before destructive or high-risk edits.
  *Violation Risk*: Destructive file loss requiring dozens of turns to manually reconstruct.

- **`headless-visual-proof`**:
  When adjusting UI, CSS, or layout, inspect the rendered component via browser automation tools before reporting completion.
  *Violation Risk*: Visual glitches and alignment bugs shipped blindly to the user.

- **`adaptive-verbosity`**:
  Deliver 1-line status updates and direct diffs on clear, high-confidence micro-tasks.
  *Violation Risk*: Context bloat and reading fatigue from conversational filler.
