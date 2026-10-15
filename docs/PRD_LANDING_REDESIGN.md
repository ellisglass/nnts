# Technical Specification (ТЗ): NNTS Landing Page Redesign
**Version:** 2.0.0  
**Status:** Approved for Implementation  
**Target:** `docs/site/` (`index.html`, `styles.css`, `app.js`)  
**Brand Identity:** NNTS — macOS Productivity Suite  
**Typography:** Space Grotesk Bold (Headings), SF Pro Display / System Sans (Body), SF Mono (Code & Badges)  

---

## 1. Project Positioning & Business Goals

### 1.1 Product Positioning
NNTS is a lightweight, high-performance native macOS utility built in pure Swift 6. It eliminates three daily micro-frictions for engineers, power users, and multi-profile browser workers:
1. **Chrome & Brave Profile Windows:** macOS native `Cmd+Tab` bundles all browser windows into one blind stack. NNTS raises the specific profile window directly via `caps lock + c/b + 1..4` in under 16ms.
2. **First-Letter Quick App Cycling:** Instant access to applications by their first letter (`caps lock + [a-z]`) with instant cycling between same-letter apps (`1/2 ↻`), bypassing Spotlight and Raycast indexing lag.
3. **Copy-on-Select:** Linux/X11-style automatic clipboard copying upon text drag selection (>10pt) or double-click, eliminating 1,000 redundant `Cmd+C` keystrokes per day.

### 1.2 Core Business & Conversion Goals
- **Primary Conversion Action:** Direct download of the universal native binary DMG (2.1 MB).
- **Secondary Conversion Action:** Homebrew Cask installation via one-click copy (`brew install --cask nnts`).
- **Target Audience:** Mac developers, designers, multi-account operators, and productivity enthusiasts on macOS 14.0+ (Sonoma, Sequoia, Tahoe).
- **Deliverable Requirements:**
  - Strict English copy across all UI elements, buttons, titles, and documentation.
  - Strict lowercase notation for `caps lock` (two words, all lowercase).
  - High-performance, 60fps interactive preview without layout shifts or cognitive fatigue.
  - Two parallel variants for visual comparison: **Variant 1 (Refined Retro-Trinitron Cockpit)** and **Variant 2 (Clean Modern Showcase / Meta-Apple Style)**.

---

## 2. Benchmark Analysis: Meta VR Glasses vs NNTS

### 2.1 Meta VR Glasses Benchmark Insights
Analysis of Meta VR Glasses landing page (`scratch/meta_clean.html`, `scratch/meta_clean_full.png`):

| UX/UI Dimension | Meta VR Glasses Implementation | Design Lesson for NNTS |
| :--- | :--- | :--- |
| **Scrolling Rhythm** | Generous 96–140px vertical gaps between sections. Alternating full-bleed cards and centered narrative blocks. | Eliminate cluttered vertical stacking. Provide breathing room around features. |
| **Micro-Copywriting** | Eyebrow (1–2 words) $\rightarrow$ Heading (2–3 words) $\rightarrow$ Description (1–2 sentences, $\le$35 words). | Replace dense paragraphs with punchy, benefit-first sentences. |
| **Card Geometry** | Large rounded cards (24–32px radius) with subtle hairline borders (`1px solid rgba(255,255,255,0.08)`). | Standardize bento card radii to 28–32px. Eliminate clumsy nested borders. |
| **Cognitive Load** | Zero extraneous widgets. Media (video/render) occupies 65% of the card area; text occupies 35%. | Strip micro-remotes and nested button shelves from feature cards. |
| **Accessibility (WCAG)** | Text never layered over noisy textures. High-contrast typography (>7:1 ratio). | Categorically isolate scanlines/effects away from readable typography. |

### 2.2 Critical Flaws in Current NNTS Landing Page

1. **Global Scanline & Vignette Toxicity:**
   - Elements `.crt-scanlines-overlay` and `.crt-vignette-overlay` are fixed across `inset: 0` at `z-index: 999`.
   - *Consequence:* All text, code blocks, and interactive buttons suffer from darkened contrast, moiré distortion, and visual fatigue.
   - *Fix:* Complete removal of global overlays. CRT raster and phosphor glow are restricted **strictly inside the TV screen glass container**.

2. **Micro-Remote & Keycap Sprawl in Bento Cards:**
   - Bento Card 1 and Card 2 feature bulky 3D mechanical keychord clusters (`caps lock + C + 1`), duplicate button shelves, URL bars, traffic lights, and metric chips all fighting for attention.
   - *Consequence:* Cognitive overload. Users do not know whether to click keycaps, shelves, or read the description.
   - *Fix:* Replace clunky keycap clusters with a single, elegant floating HUD badge and a clean interactive simulator.

3. **Section 3 Disconnection ("Direct Cathode Channel Guide"):**
   - Section 3 contains two channel buttons that control the TV in Section 1 (off-screen).
   - *Consequence:* Clicking them produces no visible feedback unless the user scrolls back to the top.
   - *Fix:* Remove redundant standalone channel selector or embed channel switching directly into the video player controls.

4. **Audio Synthesizer Real Estate:**
   - The relay sound toggle occupies prominent space in the top navigation and plays synthetic 620Hz Web Audio square waves.
   - *Fix:* Default to silent operation. In Variant 1, keep a subtle tactile toggle inside the TV hardware cluster. In Variant 2, remove audio completely.

---

## 3. Architecture of the Two Variants

### 3.1 Variant Comparison Matrix

```
+-----------------------------------------------------------------------------------+
| VARIANT 1: Refined Retro-Trinitron Cockpit  | VARIANT 2: Clean Modern Showcase    |
| (Preserves personality & tactile charm)     | (Meta-Apple 60fps media showcase)   |
+-----------------------------------------------------------------------------------+
| - Sony Trinitron TV chassis in Hero        | - Monolithic 16:9 glassmorphic player |
| - RM-NNTS remote as optional controller     | - Integrated 60fps video tabs        |
| - Scoped CRT scanlines inside screen only   | - Zero scanlines / zero retro noise  |
| - Clean bento cards (no micro-remotes)     | - Clean bento cards (no micro-remotes)|
| - Retro tactile audio (optional toggle)    | - Pure silent high-end SaaS aesthetic |
+-----------------------------------------------------------------------------------+
```

### 3.2 Switching & Comparison Mechanism
- Implement a persistent, accessible switch in the top header:
  ```html
  <div class="variant-toggle" role="radiogroup" aria-label="Landing Page Variant">
    <button class="variant-btn active" data-variant="retro" id="btn-variant-retro">
      📺 Retro Cockpit
    </button>
    <button class="variant-btn" data-variant="modern" id="btn-variant-modern">
      ⚡ Modern Showcase
    </button>
  </div>
  ```
- State management via `data-landing-variant="retro|modern"` attribute on `<body>`.
- Persistent in `localStorage.getItem("nnts_landing_variant")` and URL parameter support (`?variant=retro` / `?variant=modern`).
- Allows instant side-by-side visual evaluation without page reloads.

---

## 4. Section-by-Section Specification

### 4.1 Header (`<header class="nnts-header">`)
- **Structure:**
  - Left: NNTS wordmark logo (`canonical_nnts_vector_wordmark.png`, 32px height) linking to `#`.
  - Center: Variant Toggle (`📺 Retro Cockpit` / `⚡ Modern Showcase`).
  - Right Action Strip:
    - GitHub repository link (`ellisglass/nnts`) with star count indicator.
    - Primary CTA button: `Download DMG` with `2.1 MB` badge.
- **Visual Tokens:**
  - Height: 64px, `backdrop-filter: blur(16px)`, `background: rgba(10, 10, 14, 0.75)`, `border-bottom: 1px solid rgba(255, 255, 255, 0.08)`.
- **Copywriting:**
  - Logo Alt: `NNTS — macOS Productivity Suite`
  - CTA Button: `Download DMG` | `2.1 MB`

---

### 4.2 Hero Section — Variant 1 (Refined Retro-Trinitron Cockpit)
- **Component Composition:**
  1. **Narrative Headline Block:**
     - Eyebrow: `macOS 14+ Sonoma & Sequoia`
     - Title: `App & Profile Switcher.`<br>`Direct from caps lock.`
     - Subtitle: `Instant Chrome/Brave profiles, first-letter app cycling, and Copy-on-Select.`
     - Action Strip:
       * Primary CTA: `Download for macOS` (Universal Mach-O, 2.1 MB).
       * Interactive Terminal Pill: `$ brew install --cask nnts` (click-to-copy with Sonner toast feedback).
  2. **Refined Trinitron Cockpit Container (`.hero-tv-station`):**
     - **Sony Trinitron TV Chassis (`.retro-tv-chassis`):**
       * Refined cabinet frame, dark titanium finish (`#121218`).
       * **CRT Screen Glass (`.tv-screen-glass`):**
         - CRT raster scanlines layer (strictly scoped inside screen: `opacity: 0.35`).
         - Subtle phosphor glow layer (`radial-gradient`).
         - `<video id="tv-video-player" loop muted playsinline>` playing `screenrec-switch-app.mp4` (CH 1) or `screenrec-select-copy.mp4` (CH 2).
         - Transient OSD HUD overlay (CH 01 / CH 02) auto-hiding after 2.5s.
       * Cabinet Footer: Subtle standby LED (`#39FF14` when on, `#FF3B30` when standby) + Hardware power button.
     - **RM-NNTS Remote (`.tv-remote-handset`):**
       * Slimmed, non-intrusive remote handset docked beside the TV.
       * Functional keys: Power (`⏻`), Mute (`🔇`), Channel 1 (`Profiles`), Channel 2 (`Copy`).
       * Removed unnecessary clunky buttons.

---

### 4.3 Hero Section — Variant 2 (Clean Modern Showcase / Meta-Apple Style)
- **Component Composition:**
  1. **Narrative Headline Block:**
     - Centered, high-impact layout with Space Grotesk Bold (56px/64px).
     - Eyebrow: `Built for macOS Sonoma, Sequoia & Tahoe`
     - Title: `Switch Profiles & Apps.`<br>`Zero Latency.`
     - Subtitle: `Direct window jumps via caps lock, instant first-letter app cycling, and seamless Copy-on-Select.`
     - Action Strip:
       * Primary CTA: `Download DMG` (Free &bull; 2.1 MB).
       * Terminal Pill: `brew install --cask nnts` with clipboard copy.
  2. **Monolithic Media Showcase (`.modern-showcase-container`):**
     - Aspect ratio: 16:9 / 16:10 centered video showcase.
     - Border radius: 28px.
     - Border: `1px solid rgba(255, 255, 255, 0.12)`.
     - Background: `#0B0C10` with soft deep ambient shadow (`0 24px 60px rgba(0, 0, 0, 0.6)`).
     - **Integrated Floating Control Tabs:**
       * Tab 1: `01 // Browser Profiles` (plays `screenrec-switch-app.mp4`).
       * Tab 2: `02 // Copy-on-Select` (plays `screenrec-select-copy.mp4`).
     - **Clean Apple-style Video Player:**
       * High-definition 60fps loop, zero scanlines, zero tube curvature.
       * Minimal floating badge overlay in top-left:
         `<div class="modern-hud-pill">caps lock + C + 1 → Google Chrome (Personal)</div>`.

---

### 4.4 Section 2: Core Superpowers (Bento Grid)
Both variants share the improved, uncluttered Bento Grid layout with 3 dedicated cards:

#### Card 1: Browser Profiles (Chrome & Brave)
- **Eyebrow:** `01 // BROWSER PROFILES`
- **Hotkey Badge:** `<kbd>caps lock</kbd> + <kbd>C/B</kbd> + <kbd>1..4</kbd>`
- **Title:** `Direct Profile Window Jump`
- **Description:** `macOS Cmd+Tab bundles all browser windows into one blind stack. NNTS targets and raises the specific profile in <16ms via native accessibility APIs.`
- **Interactive Simulator Component:**
  - Clean simulated browser window with 3 macOS traffic lights.
  - Floating minimal HUD pill (`Personal • Google Chrome • Window Raised`).
  - Active profile selector buttons (1: Personal, 2: Work, 3: Client, 4: Side Project).
  - *Eliminated:* Clunky 3D keycap clusters and nested remotes.

#### Card 2: First-Letter App Cycling
- **Eyebrow:** `02 // ZERO SEARCH LAG`
- **Hotkey Badge:** `<kbd>caps lock</kbd> + <kbd>[a-z]</kbd>`
- **Title:** `First-Letter App Cycling`
- **Description:** `Skip Spotlight and Raycast indexing pauses. Hold caps lock and tap the first letter; tap again to cycle instantly between apps on the same key (1/2 ↻).`
- **Interactive Simulator Component:**
  - Dual-app card stack showing instant toggle (e.g., `Telegram` $\leftrightarrow$ `Terminal` on `T`, or `Spotify` $\leftrightarrow$ `Settings` on `S`).
  - Active letter chips: `T (1/2 ↻)`, `O (Direct)`, `S (1/2 ↻)`, `F (Direct)`.
  - Smooth spring animation upon switching.
  - *Eliminated:* Bulky mechanical keyboard clusters.

#### Card 3: Linux Copy-on-Select
- **Eyebrow:** `03 // ZERO CMD+C`
- **Counter Badge:** `<span id="copy-counter">0</span> Cmd+C Saved`
- **Title:** `Linux-Style Copy-on-Select`
- **Description:** `Highlight any text with mouse drag or double-click. Releasing mouse copies immediately to your clipboard without pressing Cmd+C.`
- **Interactive Simulator Component:**
  - Interactive terminal code snippet: `brew install --cask nnts`.
  - Live selection detection: selecting text triggers the Sonner cursor toast: `Copied to clipboard`.
  - System pasteboard preview chip updating dynamically.
  - Quick-select snippet chips (`brew install`, `curl script`, `API token`).

---

### 4.5 Section 3: Final Download & Conversion Strip
- **Eyebrow:** `READY IN SECONDS`
- **Title:** `Get NNTS for macOS`
- **Description:** `100% Native Swift 6. Driverless IOHID remapping. Zero background CPU usage.`
- **Action Strip:**
  - Direct Download button: `Download DMG (2.1 MB)` with Apple logo.
  - Homebrew Terminal Pill: `brew install --cask nnts` with one-click copy.
  - Platform Note: `Requires macOS 14.0 Sonoma or later. Apple Silicon & Intel Universal Binary.`

---

### 4.6 Section 4: Footer
- **Left:** NNTS wordmark, version badge (`v2.0.0`), copyright notice.
- **Right Links:**
  - `GitHub` (`https://github.com/ellisglass/nnts`)
  - `Releases` (`https://github.com/ellisglass/nnts/releases`)
  - `MIT License` (`https://github.com/ellisglass/nnts/blob/main/LICENSE`)

---

## 5. Design System & Accessibility Tokens

### 5.1 Color Tokens
```css
:root {
  /* Surface Foundations */
  --bg-canvas: #060709;
  --bg-surface-card: #0F1117;
  --bg-surface-elevated: #161822;
  --bg-glass: rgba(18, 20, 28, 0.75);

  /* Hairline Borders */
  --border-subtle: rgba(255, 255, 255, 0.08);
  --border-highlight: rgba(255, 255, 255, 0.18);
  --border-focus: #00F0FF;

  /* Typography */
  --text-primary: #FFFFFF;
  --text-secondary: #94A3B8;
  --text-muted: #64748B;

  /* Brand Accents */
  --accent-green: #39FF14;
  --accent-cyan: #00F0FF;
  --accent-magenta: #FF2A85;

  /* Radii */
  --radius-card: 28px;
  --radius-pill: 9999px;
  --radius-interactive: 12px;
}
```

### 5.2 Typography Hierarchy
- **Brand Title / Display:** `Space Grotesk`, `font-weight: 700`, letter-spacing: `-0.03em`.
- **Headings (H2):** `Space Grotesk`, `font-weight: 700`, 36px–44px, line-height: 1.15.
- **Subheadings (H3):** `Space Grotesk`, `font-weight: 700`, 22px–26px, line-height: 1.25.
- **Body:** `SF Pro Display`, `-apple-system`, `font-weight: 400/500`, 16px–17px, line-height: 1.55.
- **Code & KBD:** `SF Mono`, `JetBrains Mono`, `font-weight: 600`, 13px–14px.

### 5.3 CRT Scoping Rules
```css
/* CATEGORICALLY FORBIDDEN */
/* .crt-scanlines-overlay { position: fixed; inset: 0; } -> REMOVED */

/* PERMISSIBLE & STRICTLY SCOPED */
.tv-screen-glass {
  position: relative;
  overflow: hidden;
  border-radius: 20px;
}

.tv-screen-glass .tv-scanlines-layer {
  position: absolute;
  inset: 0;
  pointer-events: none;
  background: linear-gradient(rgba(18, 16, 16, 0) 50%, rgba(0, 0, 0, 0.3) 50%);
  background-size: 100% 3px;
  opacity: 0.35;
  z-index: 4;
}
```

---

## 6. Interactive Mechanics & JavaScript Architecture

### 6.1 Video Player Optimization
- Dual-channel media configuration:
  * Channel 1: `assets/media/screenrec-switch-app.mp4`
  * Channel 2: `assets/media/screenrec-select-copy.mp4`
- Optimization parameters:
  * `autoplay`, `loop`, `muted`, `playsinline`, `preload="auto"`.
  * Fallback poster: `assets/images/video-poster-hud.png`.
  * Seamless channel transition: fade video opacity to 0, swap `src`, play, fade opacity to 1 (duration: 180ms).

### 6.2 Interactive Copy-on-Select Sandbox & Sonner Toast
- Text selection listener on `#live-select-zone`:
  * Detects `mouseup` with active selection length > 3 characters.
  * Writes selected string to `navigator.clipboard.writeText()`.
  * Triggers cursor-following HUD toast (`live-cursor-hud-toast`) with text: `Copied to clipboard`.
  * Increments `copy-saved-count` badge counter.
  * Auto-dismisses toast within 1,100ms using Apple-style spring exit.

### 6.3 Dead Code Elimination & Cleanup
- Remove unused relay audio oscillators and clunky degauss sound effects if sound is turned off or in Modern variant.
- Remove redundant Section 3 cathode tuner buttons; integrate channel switching directly into Hero video player.
- Streamline event listeners into a clean modular architecture:
  * `initVariantSwitch()`
  * `initVideoShowcase()`
  * `initBentoSimulators()`
  * `initClipboardTerminal()`

---

## 7. Step-by-Step Implementation Roadmap

| Phase | Tasks & Deliverables | Verification Gates |
| :--- | :--- | :--- |
| **Phase 1: Architecture & Scaffolding** | 1. Implement Variant toggle (`data-landing-variant`).<br>2. Clean up global scanlines/vignettes from `index.html` and `styles.css`. | Text contrast verified $\ge$7:1. No overlay on viewport. |
| **Phase 2: Variant 2 Modern Showcase** | 1. Build `.modern-showcase-container` with 60fps video player.<br>2. Add smooth channel tabs (Profiles vs Copy). | 60fps smooth loop playback; seamless tab switching. |
| **Phase 3: Refined Bento Grid** | 1. Strip micro-remotes and keychord sprawl from Cards 1 & 2.<br>2. Refactor Profile simulator and App Cycler into clean cards. | Zero cluttered keycaps; clean Apple HUD badge display. |
| **Phase 4: JavaScript & Asset Optimization** | 1. Refactor `app.js` into modular controllers.<br>2. Optimize clipboard copy and Sonner toast mechanics.<br>3. Prune dead audio code. | Zero console errors; terminal one-click copy verified. |
| **Phase 5: Quality Gate & Visual Audit** | 1. Run `npx esbuild` minification via `build.sh`.<br>2. Headless visual proof capture (Chrome headless screenshot).<br>3. Local server testing via `serve.py`. | High visual fidelity in both variants; 100% WCAG pass. |
