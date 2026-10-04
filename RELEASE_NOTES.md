## What's Changed in v2.0.3

### Features
* **Zero-Permission Avatar Assistant:** Restored and enhanced the dedicated profile avatar capture assistant (`⌘⌃⇧4` snip, instant preview, zero screen recording permissions).
* **Interactive Profile Strip Context Menu:** Added right-click and Control-click interactions on profile cards in the status bar to jump straight into avatar customization.
* **Direct Status Menu Access:** Added "Avatar Assistant (⌘⌃⇧4)..." to the native menu bar and Quick Apps settings footer for instant 1-click access.

### Improvements
* **Liquid Glass Contrast Overhaul:** Engineered an 88% dark obsidian smoke base tint in `MacNativeLiquidGlassBackground` to eliminate milky-white glare and prevent underlying window text bleed-through.
* **Harmonized Subwindow Design Language:** Unified layout geometry, cards, headers, keycap badges, and monospaced shortcut hint bars across Settings, Avatar Assistant, and Feedback windows.
* **High-Contrast Typography:** Raised font opacity and added tactile dark keycap backing so all labels, hints, and keys pop crisply over both light and dark backgrounds.

### Fixes
* **Menu Tracking Context Menu Routing:** Fixed AppKit `NSMenu` swallowing secondary click events on custom menu item views via direct `rightMouseDown` and modifier routing.
