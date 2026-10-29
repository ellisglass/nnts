# Video Spec: NNTS Profile Search & Rapid Switch (Real-Life Edition)

GOAL: The viewer sees the authentic real-life NNTS experience: searching and pinning unassigned Chrome/Chromium profiles via the native Settings & Quick Apps picker window, followed by lightning-fast switching across 3 profiles with `caps lock + 1..8` and the signature Minimal HUD.
OUTPUT: HyperFrames, 1920 x 1080, 30 fps
TIME: 18.0s x 30 fps = 540 frames

LOOK:
  ground: #0d0f14 with subtle radial vignette (#1a1e2b -> #0d0f14);
  ink: #F8F5EE (Warm Cream, 100%), rgba(248, 245, 238, 0.70) secondary;
  accents: 
    - Cadmium Yellow / Amber: #FFB300 (Primary focus ring & slot digits)
    - Apple Emerald / Phosphor Green: #00E676 (Live status LED pip & verified pins)
    - Dark Titanium: #121218 (Chassis base)
  display face: Space Grotesk Bold, 56px - 72px, tracking -0.02em;
  mono/keyboard face: Space Grotesk Bold, 28px - 34px;
  medium: 100% faithful to native macOS Swift architecture (`MinimalHUDWindow.swift`, `AppSearchPickerWindow.swift`, `ShortcutsSettingsTab.swift`);
  light and depth: shadow offset (0, 32px), blur 75px, opacity 0.75, specular 1.5px glass border;

OBJECTS:
  - Native NNTS Search & Picker Window: Traffic lights (red/yellow/green), "Settings & Quick Apps", PRO ACTIVE emerald seal, search bar with live placeholder and typing of "Client", real circular profile avatar, "caps lock + 3" badge, and interactive "+ Pin to Slot 3" button with tactile snap to "✓ Pinned".
  - Signature NNTS Minimal HUD Window: 580x400px liquid glass card with 36px continuous curvature, Google Chrome header, 3 large profile avatars (Personal, Work, Client) with Apple Emerald live status pip, slot keycaps 1..3 in Cadmium Yellow, and magnetic focus ring.
  - Background macOS Chrome Windows: 3 distinct Chrome windows physically raising and swapping z-index as profiles are selected.
  - Telemetry Hotkey Indicator: Real tactile keycaps showing `caps lock` held + digit `1`, `2`, `3`.

MOTION:
  eases by role:
    enter: back.out(1.2)
    move: power2.out / back.out(1.5) for magnetic glide
    exit: power2.in
    click/snap: power1.inOut (0.12s) -> back.out(2) (0.18s)
  timings:
    0.0s - 7.5s: Search & Pin "Client" to Slot 3
    7.5s - 14.5s: Rapid sequential switching across Personal (1) -> Work (2) -> Client (3) -> release caps lock to focus
    14.5s - 18.0s: Outro payoff with Space Grotesk Bold, mascot, and `brew install --cask nnts`

BANNED:
  - "Caps", "CAPS", "Caps Lock", "Caps lock" (strictly lowercase `caps lock` only)
  - Generic/fake cyan HUD mocks (strictly authentic Bauhaus / macOS 2026 tokens only)
  - Text under 28px floor (unless marked data-layout-ignore for mock textures)
  - Empty first frame
