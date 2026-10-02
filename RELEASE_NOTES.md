## What's Changed in v2.0.0

### 🎨 Branding
* **Brand Evolution to NNTS:** Transitioned product identity and naming entirely from Xomsky to NNTS across macOS binaries, menu bars, HUDs, and documentation.
* **Cyber Mascot & App Icon:** Introduced a cyber-brutalist Titanium CRT emblem with active gaze tracking, scanline rastering, and procedural blinking.
* **Refreshed Visual Assets:** Shipped redesigned macOS Sonoma/Sequoia squircle icons, custom DMG installer backdrop, and full-resolution Bento Grid graphic.

### ⚡ Features
* **Universal Browser Profile Jump:** Instant elevation of Chrome and Brave profile windows via `Caps Lock + C/B + 1..4`.
* **Dynamic First-Letter App Switching:** One-key context switching for all pinned and installed macOS applications via `Caps Lock + [A–Z]`.
* **Linux-Style Copy-on-Select:** Automatic clipboard capture upon drag-selection (>10pt) or multi-click with non-intrusive cursor-following HUD toast.

### 🚀 Improvements
* **Backward Compatibility Shield:** Retained seamless migration paths for existing preferences, Keychain tokens, and previous license keys (`XOMSKY-` & `KHOMYAK-`).
* **Subsystem Log Modernization:** Upgraded Unified Logging (`os_log`) subsystem to `com.almosteleven.nnts` with category-level telemetry streams.
* **Streamlined Universal Distribution:** Native Universal 2 Mach-O binary (Apple Silicon arm64 & Intel x86_64) packaged with an optimized zero-dependency DMG installer.

### 🛠️ Fixes
* **HUD Overlay Dismissal Hygiene:** Ensured floating overlay window hides strictly before app activation to prevent WindowServer transition lockups.
* **Menu Bar Checkmark Collision:** Resolved gutter checkmark collision between Copy-on-Select status badge and Pro license indicators.
