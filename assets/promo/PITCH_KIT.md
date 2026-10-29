# NNTS Pitch & Viral Launch Kit

> **Target Audience:** r/mac, r/apple, r/software, r/commandline, Product Hunt, Twitter / X  
> **Brand Guardrail:** Strict lowercase `caps lock` everywhere. 100% English. Authentic technical craft.  
> **Hero Graphics:**  
> - `assets/promo/producthunt_hero_1200x630.png` (Flagship 1200×630px card)  
> - `assets/promo/reddit_gallery_1920x1080.png` (Reddit 1920×1080px hero visual)  

---

## 1. Reddit Post Draft

**Target Subreddits:** r/mac, r/software, r/apple, r/commandline  
**Post Type:** Image & Video Post (Attach `assets/promo/reddit_gallery_1920x1080.png` + demo GIF/video)  

### Title:
> **I got tired of `Cmd+Tab` losing my Chrome profiles across 3 workspaces, so I built a physical remote workflow in Swift 6 (<16ms window focus).**

### Post Body:

If you juggle multiple Chrome or Brave profiles on macOS across multiple Spaces or monitors (e.g. Personal, Work, Client, Side Project), you already know the daily `Cmd+Tab` frustration:

1. **macOS bundles all browser windows into one icon.** You hit `Cmd+Tab`, but macOS has no idea *which* profile window you want.
2. **Exposé and `Cmd+\`` require multiple keystrokes and manual scanning.** If a window lives on a different virtual desktop / Space, macOS stutters through a jarring 800ms slide animation—or worse, raises the wrong window entirely.
3. **Third-party window switchers are either bloated Electron apps or demand intrusive Screen Recording permissions.**

I wanted switching browser profiles to feel like **changing channels on a physical TV remote control**: instant, muscle-memory, and zero visual friction.

So I spent the last few months writing **NNTS** — an ultra-lightweight, 100% native macOS productivity engine in Swift 6.

---

### How It Works: The "Hardware Remote" Concept

Instead of treating `caps lock` as an accidental shout key, NNTS remaps it at the hardware driver level to `F18` using native macOS `hidutil` (meaning **zero green LED blinking**, zero kernel extensions, and zero third-party drivers). 

Then, a head-insert CoreGraphics event tap (`CGEventTap`) turns your keyboard into a dedicated channel selector:

- **Direct Chrome / Brave Profiles (`caps lock + 1..8`):**  
  Brings the exact profile window to focus in **<16ms**. It uses native macOS Accessibility (`AXUIElement`) profile navigation rather than brittle window title string matching. Whether the profile is on Display 1 or tucked inside Space 3, it raises instantly.
- **First-Letter Application Jump (`caps lock + [a-z]`):**  
  `caps lock + o` brings Obsidian, `caps lock + s` jumps between Spotify and System Settings with deterministic `1/2 ↻` cycling badges, `caps lock + t` switches to Terminal/Telegram.
- **Linux/X11 Copy-on-Select:**  
  Selecting text with mouse drag (>10pt threshold) automatically copies it to the system clipboard. Eliminates over 1,000 redundant `Cmd+C` strokes per day. Includes immunity rules for password inputs and sensitive apps.

---

### Technical Highlights (No Compromises):
- **Swift 6 Strict Concurrency:** Fully `@MainActor` isolated with zero data races. Headless tests run deterministically in GitHub Actions.
- **Zero Screen Recording Permissions:** Unlike other switchers, NNTS never calls `CGRequestScreenCaptureAccess` or takes screen captures. Profile avatars are imported safely from local folders or clipboard paste (`⌘⌃⇧4`).
- **Resource Footprint:** Consistently uses **<18 MB RAM** and **0.0% CPU at idle**.
- **Non-Activating Bezel Overlay:** The HUD floats at `NSWindow.Level.floating`, rendering profile badges and `<16ms` focus receipts without stealing key focus from your active apps.

### Quick Install & Download:
- **GitHub:** https://github.com/igorekishev/mac-productivity-suite
- **Homebrew:**
  ```bash
  brew tap igorekishev/nnts
  brew install --cask nnts
  ```
- **Requirements:** macOS 14.0+ Sonoma or macOS 15.0+ Sequoia (Apple Silicon & Intel universal).

I'd love your feedback on the interaction model and whether this solves your multi-profile workflow pains!

---

## 2. Product Hunt Launch Kit

### Tagline (60 characters max):
> **Turn `caps lock` into a TV remote for Mac windows in <16ms.**

### Short Description:
> Direct Chrome profiles, first-letter app cycling, and Linux-style Copy-on-Select. Zero `Cmd+Tab` hunting, zero Electron bloat, 100% Swift 6 native.

### Primary Gallery Asset:
- `assets/promo/producthunt_hero_1200x630.png`

### Topics:
- `Mac`, `Productivity`, `Open Source`, `Developer Tools`, `Window Management`

### Maker Comment (First Comment on Launch Day):

Hey Product Hunt! 👋

I'm Igor, creator of **NNTS**.

Like many developers, designers, and founders, my daily workspace is split into distinct lives: **Personal** (shopping, personal email), **Work** (company Slack, internal dashboards), and **Client/Side Projects** (separate Google accounts and GitHub tokens).

On macOS, managing this is painful. `Cmd+Tab` treats all Chromium profiles as a single lumped process. If you have 4 profile windows across 3 virtual desktops, switching to your work profile takes multiple `Cmd+\`` cycles or full-screen Exposé searching.

I built NNTS to give macOS the instant responsiveness of a physical TV remote:

1. **`caps lock + 1..8` brings your exact browser profile window to front in <16ms.** No guessing, no spaces lag.
2. **`caps lock + [a-z]` jumps directly to any application by its first letter**, deterministically cycling between apps sharing the same key (`1/2 ↻`).
3. **Copy-on-Select** ports the beloved Linux/X11 mouse drag copy to macOS, eliminating thousands of redundant `Cmd+C` keystrokes.

**Architecture & Privacy Philosophy:**
- **Zero Electron:** Written 100% in pure Swift 6 with AppKit and SwiftUI.
- **Zero invasive permissions:** Never requests Screen Recording (`CGRequestScreenCaptureAccess`).
- **Driverless remapping:** Uses native `/usr/bin/hidutil` to bind `caps lock` to `F18`, completely bypassing the green LED toggle.
- **Free & Open Source:** The entire codebase is open on GitHub under the MIT license.

Give it a spin and let me know which features you'd like to see next!

---

## 3. Twitter / X Launch Thread (5 Tweets)

### Tweet 1 (The Hook & Viral Video / Hero Image)
> macOS `Cmd+Tab` still lumps all your Chrome & Brave profile windows into a single blind icon.
>
> If you juggle Work, Personal, and Client accounts across multiple Spaces, you spend hundreds of seconds a day hunting for windows.
>
> So I turned `caps lock` into an authentic TV remote for Mac. 📺⚡
>
> [Attach: `assets/promo/producthunt_hero_1200x630.png` or 15s MP4 clip]

### Tweet 2 (The Chromium Profile Superpower)
> Tap `caps lock + 1` → Personal profile window.  
> Tap `caps lock + 2` → Work profile window.  
> Tap `caps lock + 3` → Client profile window.
>
> Measured window focus time: **<16ms**.
>
> It automates via native macOS Accessibility (`AXUIElement`), bypassing spaces lag and window title substring matching completely.

### Tweet 3 (First-Letter Jump & Duplicate Cycling)
> Need Slack? `caps lock + s`.  
> Need Spotify? Tap `caps lock + s` again.
>
> The floating CRT/glass HUD displays deterministic cycling badges (`1/2 ↻`, `2/2 ↻`), so you always know exactly which window comes next. Zero cognitive overhead.

### Tweet 4 (Copy-on-Select & Privacy Invariants)
> We also brought Linux/X11 Copy-on-Select to macOS.
>
> Drag to highlight any text (>10pt) → instantly copied to clipboard. Saves ~1,000 redundant `Cmd+C` taps daily.
>
> Privacy first:  
> 🔒 Zero Screen Recording permissions required.  
> 🏎️ <18MB RAM, 0% CPU at idle.  
> ⚙️ Driverless hardware remapping via native `hidutil`.

### Tweet 5 (Call to Action & Open Source Link)
> NNTS is 100% free and open-source (Swift 6 native).
>
> Works on macOS 14+ Sonoma & Sequoia (M-series Apple Silicon & Intel universal).
>
> ⭐️ Star & download on GitHub: https://github.com/igorekishev/mac-productivity-suite  
> 🍺 Or install via Homebrew: `brew install --cask nnts`
>
> What's your biggest window switching pet peeve on Mac? Let me know below! 👇
