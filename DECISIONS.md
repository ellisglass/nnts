# Architecture Decision Records (ADRs)

> Record of key architectural, security, and interface decisions for **NNTS**.  
> Persisted in Git-versioned memory to prevent regression of hard-won engineering insights.

---

## ADR-001: Driverless Hardware Remapping via `hidutil` (Caps-Lock -> F18)

- **Status**: Accepted & Implemented (v1.0.0+)
- **Context**: Remapping the physical `caps lock` key on macOS typically requires third-party kernel extensions (KEXTs), Karabiner-Elements background daemons, or virtual input drivers that introduce security concerns, installer friction, and kernel panics. Additionally, pressing physical `caps lock` toggles macOS uppercase state and flashes the physical green LED.
- **Decision**: Use native `/usr/bin/hidutil` property setting (`0x700000039` -> `0x70000006D` / `F18`) combined with a head-insert `CGEventTap` (`.cghidEventTap`).
- **Consequences**:
  - Zero kernel extensions, zero third-party drivers, and zero system modifications.
  - No physical green LED blinking or accidental uppercase toggling.
  - Clean automatic restoration to default mapping upon application termination (`hidutil property --set '{"UserKeyMapping":[]}'`).

---

## ADR-002: Chromium Profile Automation via Native Menu Bar (`kAXMenuBarAttribute`)

- **Status**: Accepted & Implemented (v1.0.0+)
- **Context**: Switching between multiple Chrome or Brave profiles on macOS is broken in `Cmd+Tab` because macOS treats all windows as a single process. Naive approaches rely on window title regex matching (e.g. searching for `- Google Chrome` or profile nicknames). This fails when browser tabs change titles dynamically, when window titles are localized, or when profiles share identical web pages.
- **Decision**: Target the browser's native macOS menu bar via Accessibility (`AXUIElementCopyAttributeValue` with `kAXMenuBarAttribute`), locate the "Profiles" menu, select profiles deterministically by index, and detect active profiles using `AXMenuItemMarkChar == "✓"`. Window raising is performed via `kAXRaiseAction` and `kAXMainAttribute`.
- **Consequences**:
  - 100% deterministic window activation regardless of tab title, active webpage, or URL.
  - Sub-16ms switching latency without OCR or screen scraping.
  - Requires macOS Accessibility permission (`AXIsProcessTrusted()`).

---

## ADR-003: Zero-Permission Avatar Model & Absolute Screen Privacy

- **Status**: Accepted & Implemented (v2.0.0+)
- **Context**: To display visual avatars for Chrome/Brave profiles in the HUD, early prototypes considered capturing profile avatar badges directly from the browser window using `CGRequestScreenCaptureAccess` or `/usr/sbin/screencapture`. However, requesting macOS Screen Recording permission triggers alarming security dialogs ("NNTS would like to record this computer's screen"), eroding user trust.
- **Decision**: Categorically forbid requesting `CGRequestScreenCaptureAccess` or invoking screen capture CLI tools. Avatars are populated exclusively via:
  1. Default dynamic monogram avatars rendered with vibrant DJB2 hash-based gradients.
  2. Direct clipboard paste (`⌘⌃⇧4` screenshot taken by user into system clipboard, read via `NSPasteboard.general`).
  3. User folder selection via standard macOS open panel.
- **Consequences**:
  - Absolute screen privacy guaranteed; zero risk of sensitive screen data leaks.
  - Eliminates macOS Screen Recording permission request dialog entirely.

---

## ADR-004: Swift 6 Strict Concurrency & Actor Isolation

- **Status**: Accepted & Implemented (v2.0.0+)
- **Context**: Event tap processing (`CGEventTap`) runs on low-level CoreGraphics threads, while AppKit UI (`NSWindow`, `NSMenu`, SwiftUI views) must run strictly on the Main thread. Cross-thread data access frequently causes subtle data races and memory corruption.
- **Decision**: Compile with Swift 6 strict concurrency checks. Isolate all UI components, view models, and state managers to `@MainActor`. Require `Sendable` conformance on state transfer payloads. Explicitly bind `[weak self]` in `@MainActor` Task blocks (`guard let self = self else { return }`).
- **Consequences**:
  - Zero data races or thread-safety crashes under high-frequency key tap events.
  - Headless unit testing via Swift Testing framework runs deterministically in CI.

---

## ADR-005: Core Architecture Modularization (Phase 3)

- **Status**: Accepted & Implemented (v2.0.3, Oct 2026)
- **Context**: As NNTS grew, `AppDelegate.swift`, `AppGroupEngine.swift`, and `MinimalHUDWindow.swift` swelled past 800 lines each, making maintenance brittle and increasing context consumption during AI pair-programming.
- **Decision**: Modularize monolithic classes into domain-specific extensions and dedicated packages:
  - Source root unified to `src/NNTS/`.
  - `AppDelegate` split into `AppDelegate+Hotkeys`, `AppDelegate+StatusMenu`, `AppDelegate+Mascot`, `AppDelegate+Dialogs`.
  - `AppGroupEngine` split into `+PinnedApps`, `+Scanner`, `+Predefined`, `+ActiveAppTracking`.
  - `ChromeProfileEngine` split into `+Accessibility`, `+Avatars`.
  - `MinimalHUDWindow` split into `HUDCardView` and `RetroHUDComponents`.
  - Settings split into modular tabs (`GeneralSettingsTab`, `LicenseSettingsTab`, `ShortcutsSettingsTab`).
  - Unit tests modularized into 10 domain suites in `tests/NNTSTests/`.
- **Consequences**:
  - Dramatically cleaner file boundaries; individual files stay well below 400 lines.
  - Fast compiler caching and targeted unit test execution.

---

## ADR-006: Pre-Focus HUD Dismissal Order (Anti-Hang Invariant)

- **Status**: Accepted & Implemented (v1.2.0+)
- **Context**: Dismissing the HUD window after invoking `NSWorkspace.shared.openApplication` or `AXUIElementPerformAction(kAXRaiseAction)` occasionally caused the HUD window to remain stuck on screen. External window server transitions would swallow keyboard release events, preventing `keyUp` from triggering HUD hide.
- **Decision**: Strictly dismiss the HUD overlay window (`MinimalHUDWindow.shared.hideImmediate()`) BEFORE triggering external application activation or window focus transitions.
- **Consequences**:
  - Completely eliminates orphaned HUD overlays and frozen bezel artifacts.

---

## ADR-007: Space Grotesk Bold Canonical Typeface & Lowercase `caps lock`

- **Status**: Accepted & Implemented (v2.0.0+)
- **Context**: Branding inconsistencies (e.g. writing "Caps Lock", "Caps", "CAPS", or using default system fonts across marketing assets) degraded perceived craft quality and brand identity.
- **Decision**:
  1. Enforce Space Grotesk Bold (`assets/fonts/SpaceGrotesk-Bold.ttf`) as the locked brand and display font for headings, bento grids, and promotional media.
  2. Enforce strictly lowercase `caps lock` (two words, no uppercase) across all UI copy, documentation, menus, and marketing collateral.
- **Consequences**:
  - Unified aesthetic across landing page, animated GIF assets, README, and native HUD.

---

## ADR-008: Automated Live App Rebuild & Relaunch Invariant

- **Status**: Accepted & Implemented (v2.0.0+)
- **Context**: Requiring the human developer to manually run `make dev` or restart the app after code edits caused cognitive friction and delay in verifying native macOS UX changes.
- **Decision**: Enforce an agent invariant that every modification to native Swift application code must immediately and automatically trigger `make dev` (compiling, code-signing, updating `/Applications/NNTS.app`, and relaunching the live process) before returning turn to the user.
- **Consequences**:
  - Immediate tactile verification for the developer.
  - Zero manual make/build invocations required from the user.

---

## ADR-009: Unified Status Menu Icon Alignment & Dynamic Profile Info Bar

- **Status**: Accepted & Implemented (v2.0.3+)
- **Context**: In the status bar menu, items without icons caused AppKit to eliminate the 18pt gutter, resulting in jagged, inconsistent left margins. Furthermore, when browser profile counts exceeded 4, `isCompact` mode stripped profile names, leaving users unable to identify accounts sharing identical initial letters.
- **Decision**:
  1. Standardize 18x18 proportional SF Symbols across all menu items (`doc.on.clipboard`, `macwindow.on.rectangle`, `gearshape`, `info.circle`, `bubble.left.and.exclamationmark.bubble.right`, `power`), ensuring 100% pixel-perfect vertical alignment down the entire menu.
  2. Embed an interactive dynamic status bar at the bottom of `ProfileStripView` that dynamically updates on hover to display full profile names and exact shortcuts (e.g. `dhl.com · caps lock + 3`), resolving anonymous initial confusion at 120Hz/60Hz.
  3. Celebrate license ownership with a gold/cadmium yellow `PRO` badge in the About section.
- **Consequences**:
  - Flawless vertical typography alignment across light and dark modes.
  - Zero ambiguity when switching between multiple accounts.
  - Full adherence to macOS HIG and Apple Design standards.

---

## ADR-010: HUD-Aligned Profile Strip in Status Menu

- **Status**: Accepted & Implemented (v2.0.3+)
- **Context**: The previous revision of the status menu featured a redundant gray section header (`Browsers & Profiles`) followed by a separate left-aligned item (`Chrome`) and an alien profile container. The user requested removing the separate header lines to keep just a single, centered `Google Chrome` line that looks and feels directly like the HUD (`MinimalHUDWindow`).
- **Decision**:
  1. **Unified HUD Header**: Eliminate the separate `Browsers & Profiles` section header and standalone `Chrome` menu item. Embed a centered `[Icon] Google Chrome` header directly at the top of `ProfileStripView`, with interactive hover feedback and click-to-activate browser window management.
  2. **Zero-Card Foundation**: Eliminate all bulky borders and button containers so avatars, labels, and header breathe directly on the native macOS menu material.
  3. **Green LED Pip**: Render the Apple Emerald LED pip (`appleEmerald`) at the top-right of the currently active profile window, matching the HUD window state indicator.
  4. **Cadmium Yellow Ring & Keycap Badge**: When hovered or selected, wrap the avatar in the signature Cadmium Yellow ring (`cadmiumYellow`) with a subtle glow, and illuminate its slot badge in yellow with dark `obsidianBase` text.
  5. **Profile Name Only Below**: Draw the clean profile headline in Space Grotesk Bold directly below the avatars without redundant action subtitles (`Active Now...`, `click to switch...`), keeping the view ultra-compact (86pt total height with centered header) and eliminating visual noise.
- **Consequences**:
  - 100% visual and behavioral parity between the HUD and the status menu.
  - No bulky borders, redundant section headers, or clunky buttons.
  - Minimal vertical footprint with maximum clarity.



---

## ADR-012: Segmented Letter Bar & Adaptive Card in Status Menu (Option 3)

- **Status**: Accepted & Implemented (v2.0.3+)
- **Context**: Users desired lifting all registered application groups (`A` apps like Antigravity / Activity Monitor, `S` apps like Spotify / Settings, `T` apps, etc.) into the status bar menu alongside Chromium profiles. Stacking each letter group vertically causes severe menu height sprawl (>480pt), pushing Quit and utilities off-screen on 13" MacBooks.
- **Decision**:
  1. **Segmented Letter Bar**: Introduce a compact 23pt native-style segmented bar at the top of `ProfileStripView` (`Chrome` | `A` | `S` | `T`).
  2. **Adaptive HUD Card**: Clicking or hovering tabs dynamically switches the card view below without resizing the menu:
     - **Chrome**: Centered Google Chrome header, circular profile avatars with emerald LED active pip and cadmium yellow slot badges (1..6), centered profile name.
     - **Letter Apps (`A`, `S`, `T`)**: Centered `Letter [A] Apps · caps lock + a` header, squircle app icons with emerald LED active running pip and cycle slot badges (1, 2, 3), centered app name with cycle counter (e.g. `Antigravity · 2/2 ↻`).
  3. **Zero Vertical Bloat**: Locks total custom card height to 128pt (total menu height ~340pt), well below the 380pt screen accessibility ceiling.
  4. **Direct Switching**: Clicking an app icon or profile tile immediately switches focus and dismisses the menu cleanly.
- **Consequences**:
  - Full visibility and one-click access for all registered apps and Chromium profiles.
  - Rock-solid fixed height across all tab transitions.
  - Preserves Chromium profiles as the primary default anchor.

---

## ADR-013: Status Menu Switcher Card Visual Polish & Grid Balance

- **Status**: Accepted & Implemented (v2.0.3+)
- **Context**: The initial implementation of Option 3 exhibited several visual defects when inspected on live macOS screens: (1) Rigid equal-width segmented tabs caused the left `Chrome 6` tab to overflow and clip, while single-letter tabs had vast empty space; (2) The solid cadmium yellow pill with black text was visually harsh in dark mode; (3) App icons suffered from a "double-squircle" artifact where an outer wireframe stroke surrounded an icon that already contained macOS native squircle masks and drop shadows; (4) Sparse app groups (e.g. 2 apps on `F`) looked tiny and deserted in a wide container; (5) Active Chrome profiles had overlapping, clashing green and yellow indicators; (6) Chrome profiles subtitle lacked shortcut education.
- **Decision**:
  1. **Proportional Segmented Tab Bar**: Calculate Chrome tab width intrinsically based on icon, text, and count badge, and distribute the remaining space evenly across letter tabs. Eliminates clipping entirely.
  2. **Frosted Glass Segmented Styling**: Active tab uses a refined translucent dark glass fill (`Color.white.opacity(0.16)`) with a 1px cadmium yellow border (`Color.yellow.opacity(0.85)`) and subtle ambient glow. Every tab renders its count in a distinct capsule badge.
  3. **Consistent Clean Headers with Keycaps**: Remove verbose `Letter [A] Apps · caps lock + a`. Render clean titles (`Google Chrome`, `Letter A Apps`) accompanied by a macOS keyboard shortcut capsule (`caps lock + c`, `caps lock + a`).
  4. **Selection Backdrop Plate (No Double-Squircle)**: App icons are drawn natively with their natural shadows unclipped. Hover and selection are indicated by a rounded backdrop tile (`plateRect`, xRadius: 8.0) rendered *behind* the icon, with cadmium yellow tint and border on selection.
  5. **Dynamic Item Sizing & Balanced Spacing**: Dynamically size tiles based on item count: 36pt icons / 46pt tiles for 1–2 items, 34pt for 3 items, 30pt for 4–5 items, and 26pt for 6+ items. Eliminates empty voids on small groups like `F` (Freeform + Finder).
  6. **Indicator De-cluttering**: Only show the emerald LED pip on the active profile when hovering another profile. When selected, the yellow focus ring alone denotes active selection, eliminating color collision.
  7. **Direct Shortcut Education**: Chrome profile subtitles now display `[Name] · caps lock + [Index]` (e.g. `Igor · caps lock + 1`), reinforcing direct profile access. Monograms use Space Grotesk Bold.
  8. **Interactive Cursor**: Switch to `NSCursor.pointingHand` over tabs, header, and icon tiles.
- **Consequences**:
  - Pixel-perfect visual fidelity matching Apple Human Interface Guidelines and Bauhaus modernism.
  - No clipping, no double outlines, no harsh solid highlighter pills.
  - Directly teaches keyboard shortcuts across profiles and letter apps.

---

## ADR-014: Status Menu Visual Matrix Cheat Sheet (Variant B)

- **Status**: Accepted & Implemented (v2.0.3+)
- **Context**: The segmented tab bar (`[Chrome 6] [A 3] [F 2] [M 2]`) introduced cognitive friction and violated keyboard-first principles: (1) Users had to manually click through tabs to see shortcuts; (2) The `M 2` tab resembled an Apple Silicon processor rather than letter M; (3) 4-layer over-badging (outer ring + icon + LED pip + slot badge) caused severe visual clutter on 36px icons; (4) Cryptic `Letter A Apps` titles and lone URLs degraded polish.
- **Decision**:
  1. **Two-Tier Zero-Click Matrix**: Eliminate tabs entirely. Display both **PROFILES** (`caps lock + 1..8`) and **QUICK APPS** (`caps lock + [a–z]`) simultaneously in a clean, unified visual cheat sheet card.
  2. **Clean Icon Restraint**: Strip multi-layer badge stacking. Avatars use clean circular clipping with an elegant 1.5pt focus ring on the active profile; quick apps use native squircles with subtle highlight plates on the frontmost app.
  3. **Direct Two-Line Badging**: Below each icon, Line 1 displays the exact keycap (`1..8` or `a · 1/2`), and Line 2 displays the truncated name (`Work`, `DHL`, `Antigrav`, `Finder`).
  4. **Adaptive Scaling**: Flatten letter groups into direct app tiles when total apps <= 6, or group by letter when > 6.
  5. **Direct Focus Routing**: Clicking any profile or app tile immediately focuses that target and dismisses the menu cleanly.
- **Consequences**:
  - Zero clicks required to discover all active keyboard shortcuts.
  - Eliminates cryptic letter tabs and 4-layer badge collision.
  - Total status menu height stays compact (~380pt) while providing full cheat sheet utility.

---

## ADR-015: HUD Zero-Ghosting Discrete Switching & Uncollapsed Status Menu Matrix

- **Status**: Accepted & Implemented (v2.0.3+)
- **Context**: Video QA revealed critical visual and interaction defects:
  1. **HUD Double-Exposure Ghosting**: Switching between Chrome Profile mode and App Group mode caused SwiftUI's `ZStack` to crossfade both hierarchies, superimposing `Nastya` directly over `Activity Monitor` in 24pt bold Space Grotesk.
  2. **Status Menu Void & Collapsed Apps**: The previous `totalApps <= 6` logic in `ProfileStripView` arbitrarily collapsed groups to 1 app per letter when count reached 7, leaving only 3 apps visible with bizarre 50pt gaps and hiding duplicate apps on the same letter.
  3. **Ellipsis Hell & Floating Digits**: Critical app names were truncated (`Antigravity I...`, `Activity Mon...`), and slot numbers floated awkwardly without visual anchors.
  4. **Menu/HUD Focus Clash**: Invoking `caps lock` hotkeys while the status menu was open caused the center HUD to render simultaneously over the active dropdown.
- **Decision**:
  1. **Discrete Mode Switching in HUD**: Replaced `ZStack` crossfading with `Group` and `.transition(.identity)` / `.animation(nil, value: isProfileMode)` in `MinimalHUDView`, ensuring 100% discrete zero-ghosting state updates.
  2. **Uncollapsed Quick Apps Matrix**: Render all registered quick apps (up to 8 in single row, 16 in multi-row) without collapsing duplicates, preserving the complete cheat sheet affordance.
  3. **Bounded Spacing & Smart Alignment**: Capped maximum horizontal spacing between tiles to 14pt (never expanding to fill remaining width into 50pt chasms).
  4. **Keycap Pill Affordances**: Render slot numbers (`1..8`) and shortcut letters (`a·1/3`, `f·1/2`) inside physical keyboard keycap pills (height 13pt, xRadius 3.5), illuminated in cadmium yellow for active items.
  5. **Intelligent Label Fitting**: Prevent ugly ellipsis truncation on critical names (`AGY IDE`, `Activity`) with adaptive text sizing.
  6. **Auto-Dismiss Status Menu on Hotkey**: Bound `statusItem?.menu?.cancelTracking()` inside hotkey callbacks and HUD presentations.
- **Consequences**:
  - Absolute elimination of HUD text collisions and double-exposure artifacts.
  - Consistent visual rhythm between the Profiles row and the Quick Apps matrix.
  - Zero-effort shortcut discovery without missing apps or awkward spacing.

---

## ADR-016: Streamlined Status Menu & Read-Only Quick Apps Cheat Sheet Submenu (Option 1)

- **Status**: Accepted & Implemented (v2.0.3+)
- **Context**: The status menu expanded into an oversized multi-row visual launcher (~19 app tiles across 4 rows, >550px height) that competed with the Dock and Launchpad. NNTS is fundamentally a keyboard-driven productivity switcher (`caps lock + [a–z]`), not a mouse launcher. Cluttering the root status menu with clickable app launch tiles violated core UX invariants, delayed menu opening, and dominated the user's screen.
- **Decision**:
  1. **Lean Root Menu with Profiles Strip**: Keep the killer Chromium Profiles feature (`caps lock + 1..8`) as a single, elegant horizontal strip in the root menu (`ProfileStripView` with `letterGroups: []`, ~88pt height).
  2. **Dedicated Read-Only Cheat Sheet Submenu**: Extract the complete Quick Apps catalog into a clean submenu: `Quick Apps Cheat Sheet (N) ▶`.
  3. **Read-Only Informational Rows**: Items in the cheat sheet are rendered as read-only reference entries (`item.action = nil`, `item.isEnabled = false`) displaying formatted keycap badges `[ A ] Antigravity · AGY IDE · Activity (3 ↻)`. Click-to-launch actions are strictly removed.
  4. **Direct Shortcuts Settings Entry**: Add a bottom action item in the submenu: `Configure Quick Apps in Settings...` routing directly to `SettingsWindow.shared.show(tab: .shortcuts)`.
- **Consequences**:
  - Root status menu height reduced from ~550px to a compact, native ~270px.
  - Clear conceptual separation: Status bar is for settings, system toggles, and shortcut cheat sheets; keyboard is for lightning-fast application switching.
  - 100% test coverage preserved with 169 automated tests passing.




