/**
 * Xomsky — Ethereal Bright Liminal 3D Giant Hamster Experience
 * Ultra-clean, photorealistic giant geometric Bauhaus hamster filling the screen.
 */

// ==========================================================================
// 1. Audio Engine
// ==========================================================================
class ASMRSoundEngine {
  constructor() {
    this.ctx = null;
    this.soundOn = true;
  }
  init() {
    if (!this.ctx) {
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      this.ctx = new AudioCtx();
    }
    if (this.ctx && this.ctx.state === "suspended") this.ctx.resume();
  }
  toggle() {
    this.soundOn = !this.soundOn;
    return this.soundOn;
  }
  playClick() {
    if (!this.soundOn) return;
    try {
      this.init();
      const now = this.ctx.currentTime;
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.type = "sine";
      osc.frequency.setValueAtTime(750, now);
      osc.frequency.exponentialRampToValueAtTime(120, now + 0.035);
      gain.gain.setValueAtTime(0.2, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.04);
      osc.connect(gain); gain.connect(this.ctx.destination);
      osc.start(now); osc.stop(now + 0.045);
    } catch(e) {}
  }
  playChime() {
    if (!this.soundOn) return;
    try {
      this.init();
      const now = this.ctx.currentTime;
      [587.33, 739.99, 880.00, 1108.73].forEach((f, i) => {
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        const st = now + i * 0.045;
        osc.type = "triangle";
        osc.frequency.setValueAtTime(f, st);
        gain.gain.setValueAtTime(0.14, st);
        gain.gain.exponentialRampToValueAtTime(0.001, st + 0.35);
        osc.connect(gain); gain.connect(this.ctx.destination);
        osc.start(st); osc.stop(st + 0.4);
      });
    } catch(e) {}
  }
  playRelayClick(toDark = true) {
    if (!this.soundOn) return;
    try {
      this.init();
      const now = this.ctx.currentTime;
      if (toDark) {
        // Deep mechanical relay click: transient impulse + resonant sub-bass thump (lights out)
        const osc1 = this.ctx.createOscillator();
        const gain1 = this.ctx.createGain();
        osc1.type = "sine";
        osc1.frequency.setValueAtTime(420, now);
        osc1.frequency.exponentialRampToValueAtTime(55, now + 0.08);
        gain1.gain.setValueAtTime(0.35, now);
        gain1.gain.exponentialRampToValueAtTime(0.001, now + 0.12);
        osc1.connect(gain1); gain1.connect(this.ctx.destination);
        osc1.start(now); osc1.stop(now + 0.13);

        const osc2 = this.ctx.createOscillator();
        const gain2 = this.ctx.createGain();
        osc2.type = "triangle";
        osc2.frequency.setValueAtTime(120, now + 0.015);
        osc2.frequency.exponentialRampToValueAtTime(40, now + 0.15);
        gain2.gain.setValueAtTime(0.25, now + 0.015);
        gain2.gain.exponentialRampToValueAtTime(0.001, now + 0.20);
        osc2.connect(gain2); gain2.connect(this.ctx.destination);
        osc2.start(now + 0.015); osc2.stop(now + 0.22);
      } else {
        // Crisp high-frequency switch flick + upward crystalline tone (lights on)
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = "sine";
        osc.frequency.setValueAtTime(440, now);
        osc.frequency.exponentialRampToValueAtTime(880, now + 0.06);
        gain.gain.setValueAtTime(0.20, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.09);
        osc.connect(gain); gain.connect(this.ctx.destination);
        osc.start(now); osc.stop(now + 0.10);
      }
    } catch(e) {}
  }
}

const sound = new ASMRSoundEngine();

// ==========================================================================
// 2. Profile Data
// ==========================================================================
// 2. Profile Data (Matching Native macOS Google Chrome Profiles)
// ==========================================================================
const PROFILES = [
  {
    name: "Igor",
    headerName: "Igor",
    email: "igor@xomsky.app",
    avatarImg: "assets/images/profiles/igor.png",
    avatarBg: "linear-gradient(135deg, #6366F1 0%, #A855F7 100%)",
    avatarEmoji: "👤",
    initial: "I",
    className: "avatar-igor",
    windows: 11,
    tabs: ["Linear Team Core", "Claude 3.7", "Antigravity"],
    url: "https://linear.app/team-core",
    color: "#8B5CF6"
  },
  {
    name: "Al11",
    headerName: "Al11 (Igor)",
    email: "igor@almosteleven.com",
    avatarImg: "assets/images/profiles/ai11.png",
    avatarBg: "linear-gradient(135deg, #3B82F6 0%, #1D4ED8 100%)",
    avatarEmoji: "🔥",
    initial: "A",
    className: "avatar-ai11",
    windows: 6,
    tabs: ["GitHub Pull Requests", "CI Pipeline", "Terminal"],
    url: "https://github.com/unacau/xomsky",
    color: "#3B82F6"
  },
  {
    name: "GCP",
    headerName: "GCP Free Trial",
    email: "gcp-dev@xomsky.app",
    avatarImg: "assets/images/profiles/gcp.png",
    avatarBg: "linear-gradient(135deg, #EC4899 0%, #F43F5E 100%)",
    avatarEmoji: "🕶️",
    initial: "G",
    className: "avatar-gcp",
    windows: 4,
    tabs: ["Google Cloud Console", "Vertex AI", "Billing"],
    url: "https://console.cloud.google.com",
    color: "#EC4899"
  },
  {
    name: "Nastya",
    headerName: "Nastya",
    email: "nastya@xomsky.app",
    avatarImg: "assets/images/profiles/nastya.png",
    avatarBg: "linear-gradient(135deg, #1E293B 0%, #0F172A 100%)",
    avatarEmoji: "🖤",
    initial: "N",
    className: "avatar-nastya",
    windows: 2,
    tabs: ["Figma Design Specs", "Notion Shared", "Spotify"],
    url: "https://figma.com",
    color: "#10B981"
  }
];

// Camera View Presets (Dynamic 3/4 Hero View vs Cute Butt View vs Front View)
const CAM_PRESETS = {
  hero: {
    pos: new THREE.Vector3(-1.25, 1.85, 4.70),
    target: new THREE.Vector3(0.15, 0.98, 0.15)
  },
  optionA: {
    // Wide framing to show both left-flanking 3D Mac window and the hamster with zero top overlap
    pos: new THREE.Vector3(-1.05, 1.50, 4.90),
    target: new THREE.Vector3(-0.45, 0.78, 0.25)
  },
  optionB: {
    // Hamster positioned to leave room for Animos 60fps carousel on the right
    pos: new THREE.Vector3(-1.35, 1.70, 4.70),
    target: new THREE.Vector3(0.25, 0.90, 0.20)
  },
  optionC: {
    // Hamster framed proudly and prominently in the center channel between left copy and right macOS video window
    pos: new THREE.Vector3(-0.35, 1.55, 4.80),
    target: new THREE.Vector3(-0.35, 0.82, 0.15)
  },
  mobileOptionC: {
    // Tighter portrait framing for mobile: centers hamster's face and paws in top 280px viewport
    pos: new THREE.Vector3(-0.35, 1.48, 5.20),
    target: new THREE.Vector3(-0.35, 0.70, 0.15)
  },
  rear: {
    pos: new THREE.Vector3(0.35, 1.85, -4.90),
    target: new THREE.Vector3(-0.35, 0.78, 0.10)
  },
  front: {
    pos: new THREE.Vector3(-0.35, 1.55, 4.80),
    target: new THREE.Vector3(-0.35, 0.64, 0.10)
  }
};

window.setCameraView = setCameraView;

function setLightingPreset(variantName) {
  if (!ambientLight || !keyLight || !fillLight || !rimLightL || !rimLightR) return;
  const isLight = (currentTheme === "light");

  if (variantName === "option-c" || variantName === "option-a") {
    // High-contrast, vibrant studio illumination for Option A & Option C
    keyLight.intensity = isLight ? 1.50 : 1.20;
    fillLight.intensity = isLight ? 0.95 : 0.68;
    rimLightL.intensity = isLight ? 1.40 : 1.95;
    rimLightR.intensity = isLight ? 0.30 : 2.60;
    ambientLight.intensity = isLight ? 1.15 : 0.85;
    if (scene && scene.fog) {
      scene.fog.density = isLight ? 0.016 : 0.014;
    }
  } else {
    // Standard baseline theme lighting
    const t = THEMES[currentTheme] || THEMES.dark;
    keyLight.intensity = t.keyLightIntensity;
    fillLight.intensity = t.fillIntensity;
    rimLightL.intensity = t.rimLIntensity;
    rimLightR.intensity = t.rimRIntensity;
    ambientLight.intensity = t.ambientIntensity;
    if (scene && scene.fog) {
      scene.fog.density = t.fogDensity;
    }
  }
}
window.setLightingPreset = setLightingPreset;

let currentCamView = "hero"; // Default to dynamic 3/4 Hero view (balanced & shows profile + glowing keycap)
let targetCamPos = CAM_PRESETS.hero.pos.clone();
let targetCamLook = CAM_PRESETS.hero.target.clone();
let isCamTransitioning = false;

function setCameraView(viewName, smooth = true) {
  let targetView = viewName;
  if (viewName === "optionC" && window.innerWidth <= 900) {
    targetView = "mobileOptionC";
  }
  currentCamView = targetView;
  const preset = CAM_PRESETS[targetView] || CAM_PRESETS.hero;
  targetCamPos.copy(preset.pos);
  targetCamLook.copy(preset.target);

  if (!smooth && camera && controls) {
    camera.position.copy(preset.pos);
    controls.target.copy(preset.target);
    controls.update();
  } else {
    isCamTransitioning = true;
  }
  updateCamBtnLabel();
}

function getVariantDefaultCam() {
  const isMobile = window.innerWidth <= 900;
  const curVar = document.documentElement.getAttribute("data-design-variant") || "option-c";
  if (curVar === "option-c") return isMobile ? "mobileOptionC" : "optionC";
  if (curVar === "option-a") return "optionA";
  if (curVar === "option-b") return "optionB";
  return "hero";
}

function toggleCameraView() {
  const defaultCam = getVariantDefaultCam();
  const next = currentCamView === "rear" ? defaultCam : "rear";
  setCameraView(next, true);
  sound.playClick();
}

function updateCamBtnLabel() {
  const icon = document.getElementById("cam-view-icon");
  const text = document.getElementById("cam-view-text");
  const btn = document.getElementById("cam-view-btn");
  if (!btn) return;
  if (currentCamView === "rear") {
    if (icon) icon.textContent = "🐹";
    if (text) text.textContent = "Face View";
    btn.title = "Switch to front view (V)";
  } else {
    if (icon) icon.textContent = "🍑";
    if (text) text.textContent = "Butt View";
    btn.title = "Switch to cute rear butt view (V)";
  }
}

const CATEGORY_DATA = {
  chrome: {
    title: "Google Chrome",
    shortcut: "Caps-Lock + C",
    color: "#3B82F6"
  },
  terminal: {
    title: "Terminal (iTerm2)",
    shortcut: "Caps-Lock + T",
    color: "#10B981",
    lines: [
      "$ swift test",
      "Building for debugging...",
      "✔ Test suite 'ChromeQuickAccessTests' passed (0.042s)",
      "12 tests passed, 0 failures.",
      "igorekishev@MacBook-Pro git:(main) ▋"
    ]
  },
  ide: {
    title: "IDE (Antigravity IDE)",
    shortcut: "Caps-Lock + I",
    color: "#6366F1",
    lines: [
      "// AppGroupEngine.swift — 5-Category Suite",
      "public static let ide = AppGroupEngine(",
      "  category: \"IDE\",",
      "  candidates: [AppCandidate(\"Antigravity IDE\")]",
      ") // sub-16ms CGEventTap window focus"
    ]
  },
  ai: {
    title: "AI Agent (Antigravity)",
    shortcut: "Caps-Lock + A",
    color: "#06B6D4",
    message: "Verified 100% native CGEventTap architecture without background daemons. Context switches execute in 1 display frame."
  },
  notes: {
    title: "Notes (Apple Notes)",
    shortcut: "Caps-Lock + N",
    color: "#F59E0B",
    tasks: [
      "☑ Caps Lock + First Letter App Access",
      "☑ Chrome/Brave Profiles (Caps + C/B + 1-4)",
      "☑ Universal Copy-on-Select",
      "☐ Ship Xomsky v1.0.0 Release"
    ]
  }
};

let activeIndex = 0;
let currentCategory = "chrome";
let userInteracted = false;

// ==========================================================================
// 3. Three.js Scene: Luminous Liminal Space & Midnight Obsidian Studio
// ==========================================================================
let scene, camera, renderer, controls;
let hamsterRoot, cheeksGroup, eyesGroup, snoutGroup;
let eyeLeft, eyeRight;
let glintLBig, glintLSmall, glintRBig, glintRSmall;
let leftEarGroup, rightEarGroup;
let whiskersGroup, tailMesh;
let keyboardGroup;
let interactiveKeyMeshes = [];
let keyMeshMap = {};

const RESTING_GAZE_X = 0.12; // ACM CHI Gaze-Cueing: gentle ~8-10° resting turn toward right-side HUD
const RESTING_GAZE_Y = -0.02;
let mouseX = 0, mouseY = 0;
let targetHeadX = RESTING_GAZE_X, targetHeadY = RESTING_GAZE_Y;
let raycaster, mouseVec;
let mouseMoved = true;

// Dynamic Environment & Lighting References
let floorMesh, floorMat;
let panelMesh, panelMat;
let ambientLight, keyLight, rimLightL, rimLightR, fillLight;
let pillarMat, pillarMeshes = [];
let chassisMesh, chassisMat, plateMesh, plateMat, glowStripMesh, glowStripMat;

// Theme Engine: System Theme Auto-Detection (dark/light) with user manual toggle
function getSystemTheme() {
  return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

function getPreferredTheme() {
  try {
    const urlParams = new URLSearchParams(window.location.search);
    const paramTheme = urlParams.get("theme");
    if (paramTheme === "dark" || paramTheme === "light") {
      return paramTheme;
    }
    const override = localStorage.getItem("xomsky_theme_override");
    if (override === "dark" || override === "light") {
      return override;
    }
  } catch (e) {}
  return getSystemTheme();
}

let currentTheme = getPreferredTheme();

const THEMES = {
  light: {
    bg: 0xFDF8FA,
    fogDensity: 0.022,
    ambientColor: 0xFFF0F5,
    ambientIntensity: 1.05,
    keyLightColor: 0xFFFFFF,
    keyLightIntensity: 1.35,
    rimLColor: 0xF472B6,
    rimLIntensity: 1.25,
    rimRColor: 0xF5A623,
    rimRIntensity: 0.0,
    fillColor: 0xFCE7F3,
    fillIntensity: 0.80,
    floorColor: 0xFFFFFF,
    floorRoughness: 0.15,
    floorMetalness: 0.15,
    panelColor: 0xFFFFFF,
    pillarColor: 0xFDF2F8,
    pillarRoughness: 0.60,
    pillarMetalness: 0.0,
    chassisColor: 0x1E222D,
    chassisRoughness: 0.32,
    chassisMetalness: 0.82,
    plateColor: 0x141820,
    plateRoughness: 0.45,
    plateMetalness: 0.65,
    glowStripColor: 0x38BDF8
  },
  dark: {
    bg: 0x0B1120, // Brandbook Midnight Navy
    fogDensity: 0.030,
    ambientColor: 0x1E293B,
    ambientIntensity: 0.70,
    keyLightColor: 0x94A3B8,
    keyLightIntensity: 0.55,
    rimLColor: 0x818CF8, // Soft Indigo / Moonlight Lavender rim (neutralizes green clash on yellow fur)
    rimLIntensity: 1.50,
    rimRColor: 0xF5A623, // Warm Hamster Gold rim contouring from right
    rimRIntensity: 2.20,
    fillColor: 0x0F172A,
    fillIntensity: 0.35,
    floorColor: 0x070B14, // Smoked Obsidian Mirror Floor
    floorRoughness: 0.08,
    floorMetalness: 0.85,
    panelColor: 0x0F172A, // Softbox shut down
    pillarColor: 0x0B1222,
    pillarRoughness: 0.70,
    pillarMetalness: 0.30,
    chassisColor: 0x0A0F1D,
    chassisRoughness: 0.28,
    chassisMetalness: 0.90,
    plateColor: 0x060911,
    plateRoughness: 0.35,
    plateMetalness: 0.80,
    glowStripColor: 0x38BDF8
  }
};

let themeTransition = {
  active: false,
  progress: 1.0,
  duration: 0.45,
  from: {},
  to: {}
};

function initThreeJS() {
  const container = document.getElementById("canvas-container");
  const width = window.innerWidth;
  const height = window.innerHeight;

  const initTheme = THEMES[currentTheme] || THEMES.dark;

  // Scene & Atmosphere
  scene = new THREE.Scene();
  scene.background = new THREE.Color(initTheme.bg);
  scene.fog = new THREE.FogExp2(initTheme.bg, initTheme.fogDensity);

  // Camera: Placed by default in dynamic 3/4 hero view
  camera = new THREE.PerspectiveCamera(40, width / height, 0.1, 1000);
  camera.position.copy(CAM_PRESETS.hero.pos);

  // Renderer: Thermal & GPU power-optimized for cool silent operation
  renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: "default" });
  renderer.setSize(width, height);
  // Cap at 1.5 for crisp Retina text with 44% lower GPU shader load than 2.0
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.5));
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFShadowMap;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.05;
  window.__renderer = renderer;
  container.appendChild(renderer.domElement);

  // OrbitControls
  controls = new THREE.OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  controls.dampingFactor = 0.06;
  controls.maxPolarAngle = Math.PI / 2 - 0.02;
  controls.minDistance = 2.4;
  controls.maxDistance = 8.0;
  controls.target.copy(CAM_PRESETS.hero.target);
  controls.addEventListener("start", () => { isCamTransitioning = false; });

  // Raycasting
  raycaster = new THREE.Raycaster();
  mouseVec = new THREE.Vector2();

  // Build Scene
  buildBrightLiminalEnvironment();
  buildGiantRealisticHamster();
  buildMechanicalKeyboardDeck();

  // Events
  window.addEventListener("resize", onWindowResize);
  window.addEventListener("mousemove", onMouseMove, { passive: true });
  window.addEventListener("mouseleave", () => {
    targetHeadX = RESTING_GAZE_X;
    targetHeadY = RESTING_GAZE_Y;
  }, { passive: true });
  container.addEventListener("pointerdown", onPointerDown, { passive: true });

  // animate(); // Kickoff handled by IntersectionObserver
}

// --------------------------------------------------------------------------
// Luminous Liminal Environment
// --------------------------------------------------------------------------
function buildBrightLiminalEnvironment() {
  const t = THEMES[currentTheme] || THEMES.dark;
  // Force Space Gray / Dark colors for the keyboard
  const chassisColorOverride = 0x2A2A2E;
  const plateColorOverride = 0x1C1C1F;

  // Luminous Marble / Smoked Obsidian Floor
  const floorGeo = new THREE.PlaneGeometry(250, 250);
  floorMat = new THREE.MeshStandardMaterial({
    color: t.floorColor,
    roughness: t.floorRoughness,
    metalness: t.floorMetalness
  });
  floorMesh = new THREE.Mesh(floorGeo, floorMat);
  floorMesh.position.y = -0.6;
  floorMesh.rotation.x = -Math.PI / 2;
  floorMesh.receiveShadow = true;
  scene.add(floorMesh);

  // Overhead Luminous Softbox Panel
  const panelGeo = new THREE.BoxGeometry(12, 0.1, 5);
  panelMat = new THREE.MeshBasicMaterial({ color: t.panelColor });
  panelMesh = new THREE.Mesh(panelGeo, panelMat);
  panelMesh.position.set(0, 7.5, 0);
  scene.add(panelMesh);

  // Ambient Light: Bright Radiant or Deep Midnight Indigo
  ambientLight = new THREE.AmbientLight(t.ambientColor, t.ambientIntensity);
  scene.add(ambientLight);

  // Studio Key Light
  keyLight = new THREE.DirectionalLight(t.keyLightColor, t.keyLightIntensity);
  keyLight.position.set(4, 8, 6);
  keyLight.castShadow = true;
  keyLight.shadow.mapSize.width = 2048;
  keyLight.shadow.mapSize.height = 2048;
  keyLight.shadow.bias = -0.0004;
  scene.add(keyLight);

  // Dual Sculpting Rim Lights
  // Left Rim Light (Pink in light, Electric Cyan in dark)
  rimLightL = new THREE.DirectionalLight(t.rimLColor, t.rimLIntensity);
  rimLightL.position.set(-5, 4.5, -5);
  scene.add(rimLightL);

  // Right Rim Light (Warm Hamster Gold in dark)
  rimLightR = new THREE.DirectionalLight(t.rimRColor, t.rimRIntensity);
  rimLightR.position.set(5, 4.0, -4);
  scene.add(rimLightR);

  // Front Soft Fill
  fillLight = new THREE.PointLight(t.fillColor, t.fillIntensity, 12);
  fillLight.position.set(0, 1.2, 3.5);
  scene.add(fillLight);

  // Rear Soft Fill (Illuminating the cute butt view)
  const rearFill = new THREE.PointLight(t.fillColor, t.fillIntensity * 0.95, 14);
  rearFill.position.set(1.2, 2.5, -5.2);
  scene.add(rearFill);
}

// --------------------------------------------------------------------------
// Giant Geometric Bauhaus Hamster with Green LED Keycap (Liminal Experience)
// --------------------------------------------------------------------------
function buildGiantRealisticHamster() {
  hamsterRoot = new THREE.Group();
  hamsterRoot.position.set(-0.35, -0.48, 0);
  hamsterRoot.scale.set(0.68, 0.68, 0.68);

  // Bauhaus Palette Materials
  const bauhausYellowMat = new THREE.MeshStandardMaterial({
    color: 0xF59E0B, // Rich warm amber / golden-yellow
    roughness: 0.38,
    metalness: 0.04
  });

  const bauhausCreamMat = new THREE.MeshStandardMaterial({
    color: 0xFEF3C7, // Warm Bauhaus ivory / cream
    roughness: 0.40,
    metalness: 0.02
  });

  const bauhausRedMat = new THREE.MeshStandardMaterial({
    color: 0xEF4444, // Vibrant Bauhaus signal red
    emissive: 0x991B1B,
    emissiveIntensity: 0.30,
    roughness: 0.25,
    metalness: 0.05
  });

  const bauhausOutlineMat = new THREE.MeshBasicMaterial({
    color: 0x111827 // Deep ink black graphic outline
  });

  const eyeObsidianMat = new THREE.MeshStandardMaterial({
    color: 0x0A0A0C, // Glossy deep obsidian black
    roughness: 0.05,
    metalness: 0.30
  });

  const whitePawMat = new THREE.MeshStandardMaterial({
    color: 0xFFFFFF,
    roughness: 0.35,
    metalness: 0.02
  });

  const pinkPadMat = new THREE.MeshStandardMaterial({
    color: 0xF43F5E, // Vibrant cute rose pink
    roughness: 0.30,
    metalness: 0.05
  });

  // 1. Cheeks & Head Group (Kinetic Squish Pivot)
  cheeksGroup = new THREE.Group();
  cheeksGroup.position.set(0, 0.92, 0.1);

  // Upper Head Spheres (Two overlapping yellow volumes)
  const headGeo = new THREE.SphereGeometry(0.72, 36, 36);
  headGeo.scale(1.15, 0.98, 0.65);

  const headL = new THREE.Mesh(headGeo, bauhausYellowMat);
  headL.position.set(-0.48, 0.22, 0);
  headL.castShadow = true;
  cheeksGroup.add(headL);

  const headR = new THREE.Mesh(headGeo, bauhausYellowMat);
  headR.position.set(0.48, 0.22, 0);
  headR.castShadow = true;
  cheeksGroup.add(headR);

  // Central Vertical Cream Forehead & Muzzle Bridge
  const centerWedgeGeo = new THREE.SphereGeometry(0.68, 36, 36);
  centerWedgeGeo.scale(0.82, 1.12, 0.72);
  const centerWedge = new THREE.Mesh(centerWedgeGeo, bauhausCreamMat);
  centerWedge.position.set(0, 0.18, 0.12);
  centerWedge.castShadow = true;
  cheeksGroup.add(centerWedge);

  // Lower Giant Puffed Cheeks (Overlapping yellow & cream circles)
  const lowerCheekGeo = new THREE.SphereGeometry(0.56, 32, 32);
  lowerCheekGeo.scale(1.18, 0.92, 0.68);

  const lowerCheekL = new THREE.Mesh(lowerCheekGeo, bauhausYellowMat);
  lowerCheekL.position.set(-0.66, -0.15, 0.2);
  lowerCheekL.castShadow = true;
  cheeksGroup.add(lowerCheekL);

  const lowerCheekR = new THREE.Mesh(lowerCheekGeo, bauhausYellowMat);
  lowerCheekR.position.set(0.66, -0.15, 0.2);
  lowerCheekR.castShadow = true;
  cheeksGroup.add(lowerCheekR);

  // Inner Cream Cheeks Patches
  const innerPatchGeo = new THREE.SphereGeometry(0.46, 32, 32);
  innerPatchGeo.scale(0.98, 0.95, 0.75);

  const innerL = new THREE.Mesh(innerPatchGeo, bauhausCreamMat);
  innerL.position.set(-0.28, -0.16, 0.32);
  cheeksGroup.add(innerL);

  const innerR = new THREE.Mesh(innerPatchGeo, bauhausCreamMat);
  innerR.position.set(0.28, -0.16, 0.32);
  cheeksGroup.add(innerR);

  // Center Chin Pad
  const chinGeo = new THREE.SphereGeometry(0.36, 24, 24);
  chinGeo.scale(1.12, 0.85, 0.75);
  const chin = new THREE.Mesh(chinGeo, bauhausCreamMat);
  chin.position.set(0, -0.32, 0.32);
  cheeksGroup.add(chin);

  hamsterRoot.add(cheeksGroup);

  // 2. Symmetrical Bauhaus Geometric Circular Ears
  const earOuterGeo = new THREE.CylinderGeometry(0.38, 0.38, 0.08, 36);
  earOuterGeo.rotateX(Math.PI / 2);
  const earInnerGeo = new THREE.CylinderGeometry(0.25, 0.25, 0.09, 36);
  earInnerGeo.rotateX(Math.PI / 2);
  const earRingGeo = new THREE.TorusGeometry(0.38, 0.018, 16, 48);
  const earInnerRingGeo = new THREE.TorusGeometry(0.25, 0.015, 16, 48);

  leftEarGroup = new THREE.Group();
  leftEarGroup.position.set(-0.70, 1.86, -0.05);
  leftEarGroup.rotation.z = 0.25;
  const lOuter = new THREE.Mesh(earOuterGeo, bauhausYellowMat);
  const lInner = new THREE.Mesh(earInnerGeo, bauhausCreamMat);
  lInner.position.z = 0.008;
  const lRing = new THREE.Mesh(earRingGeo, bauhausOutlineMat);
  lRing.position.z = 0.042;
  const lInnerRing = new THREE.Mesh(earInnerRingGeo, bauhausOutlineMat);
  lInnerRing.position.z = 0.046;
  leftEarGroup.add(lOuter, lInner, lRing, lInnerRing);
  hamsterRoot.add(leftEarGroup);

  rightEarGroup = new THREE.Group();
  rightEarGroup.position.set(0.70, 1.86, -0.05);
  rightEarGroup.rotation.z = -0.25;
  const rOuter = new THREE.Mesh(earOuterGeo, bauhausYellowMat);
  const rInner = new THREE.Mesh(earInnerGeo, bauhausCreamMat);
  rInner.position.z = 0.008;
  const rRing = new THREE.Mesh(earRingGeo, bauhausOutlineMat);
  rRing.position.z = 0.042;
  const rInnerRing = new THREE.Mesh(earInnerRingGeo, bauhausOutlineMat);
  rInnerRing.position.z = 0.046;
  rightEarGroup.add(rOuter, rInner, rRing, rInnerRing);
  hamsterRoot.add(rightEarGroup);

  // 3. Expressive Focus Eyes (Clean Graphic Contour + Deep Obsidian Pupil + Dual Specular Glints)
  eyesGroup = new THREE.Group();
  eyesGroup.position.set(0, 1.28, 0.72);

  const eyeBaseGeo = new THREE.CylinderGeometry(0.35, 0.35, 0.04, 48);
  eyeBaseGeo.rotateX(Math.PI / 2);
  const eyeRingOuterGeo = new THREE.TorusGeometry(0.35, 0.016, 16, 64);
  const eyeSphereGeo = new THREE.SphereGeometry(0.23, 32, 32);
  const glintBigGeo = new THREE.SphereGeometry(0.065, 16, 16);
  const glintSmallGeo = new THREE.SphereGeometry(0.032, 16, 16);
  const glintMat = new THREE.MeshBasicMaterial({ color: 0xFFFFFF });

  // Left Eye Sub-Assembly
  const eyeLGroup = new THREE.Group();
  eyeLGroup.position.set(-0.38, 0, 0.04);
  eyeLGroup.rotation.y = -0.08;

  const eyeBaseL = new THREE.Mesh(eyeBaseGeo, bauhausCreamMat);
  eyeLGroup.add(eyeBaseL);

  const ringOutL = new THREE.Mesh(eyeRingOuterGeo, bauhausOutlineMat);
  ringOutL.position.z = 0.025;
  eyeLGroup.add(ringOutL);

  eyeLeft = new THREE.Mesh(eyeSphereGeo, eyeObsidianMat);
  eyeLeft.position.z = 0.07;
  eyeLGroup.add(eyeLeft);

  glintLBig = new THREE.Mesh(glintBigGeo, glintMat);
  glintLBig.position.set(-0.06, 0.06, 0.24);
  eyeLGroup.add(glintLBig);

  glintLSmall = new THREE.Mesh(glintSmallGeo, glintMat);
  glintLSmall.position.set(0.07, -0.06, 0.24);
  eyeLGroup.add(glintLSmall);

  eyesGroup.add(eyeLGroup);

  // Right Eye Sub-Assembly
  const eyeRGroup = new THREE.Group();
  eyeRGroup.position.set(0.38, 0, 0.04);
  eyeRGroup.rotation.y = 0.08;

  const eyeBaseR = new THREE.Mesh(eyeBaseGeo, bauhausCreamMat);
  eyeRGroup.add(eyeBaseR);

  const ringOutR = new THREE.Mesh(eyeRingOuterGeo, bauhausOutlineMat);
  ringOutR.position.z = 0.025;
  eyeRGroup.add(ringOutR);

  eyeRight = new THREE.Mesh(eyeSphereGeo, eyeObsidianMat);
  eyeRight.position.z = 0.07;
  eyeRGroup.add(eyeRight);

  glintRBig = new THREE.Mesh(glintBigGeo, glintMat);
  glintRBig.position.set(-0.06, 0.06, 0.24);
  eyeRGroup.add(glintRBig);

  glintRSmall = new THREE.Mesh(glintSmallGeo, glintMat);
  glintRSmall.position.set(0.07, -0.06, 0.24);
  eyeRGroup.add(glintRSmall);

  eyesGroup.add(eyeRGroup);

  hamsterRoot.add(eyesGroup);

  // 4. Red Inverted Triangle Nose & Bauhaus Curved Smiling Mouth
  snoutGroup = new THREE.Group();
  snoutGroup.position.set(0, 0.98, 0.78);

  // Inverted Flat Triangular Prism (horizontal top, downward pointing vertex)
  const noseShape = new THREE.Shape();
  const nw = 0.20;
  const nh = 0.22;
  noseShape.moveTo(-nw, nh * 0.45);
  noseShape.lineTo(nw, nh * 0.45);
  noseShape.lineTo(0, -nh * 0.65);
  noseShape.closePath();

  const noseGeo = new THREE.ExtrudeGeometry(noseShape, { depth: 0.06, bevelEnabled: false });
  const noseMat = new THREE.MeshBasicMaterial({ color: 0xFF2A2A });
  const noseMesh = new THREE.Mesh(noseGeo, noseMat);
  noseMesh.position.z = -0.03;
  snoutGroup.add(noseMesh);

  // Clean dark outline around the red triangle
  const noseEdges = new THREE.EdgesGeometry(noseGeo);
  const noseLine = new THREE.LineSegments(noseEdges, new THREE.LineBasicMaterial({ color: 0x111827, linewidth: 2 }));
  noseLine.position.z = -0.03;
  snoutGroup.add(noseLine);

  // Curved Black Smile Lines (Bauhaus W-mouth)
  const curveL = new THREE.QuadraticBezierCurve3(
    new THREE.Vector3(-0.32, -0.15, -0.05),
    new THREE.Vector3(-0.16, -0.28, 0.02),
    new THREE.Vector3(0, -0.14, 0.04)
  );
  const smileL = new THREE.Mesh(new THREE.TubeGeometry(curveL, 20, 0.022, 8, false), bauhausOutlineMat);
  snoutGroup.add(smileL);

  const curveR = new THREE.QuadraticBezierCurve3(
    new THREE.Vector3(0, -0.14, 0.04),
    new THREE.Vector3(0.16, -0.28, 0.02),
    new THREE.Vector3(0.32, -0.15, -0.05)
  );
  const smileR = new THREE.Mesh(new THREE.TubeGeometry(curveR, 20, 0.022, 8, false), bauhausOutlineMat);
  snoutGroup.add(smileR);

  hamsterRoot.add(snoutGroup);

  // 5. Pure White Paws with Pink Pads Resting on Keycap
  const pawGeo = new THREE.SphereGeometry(0.19, 24, 24);
  pawGeo.scale(1.15, 0.95, 1.15);
  const padGeo = new THREE.SphereGeometry(0.042, 16, 16);

  // Left Paw
  const leftPawGroup = new THREE.Group();
  leftPawGroup.position.set(-0.36, 0.28, 0.86);
  leftPawGroup.rotation.x = 0.20;
  const leftPawMesh = new THREE.Mesh(pawGeo, whitePawMat);
  leftPawGroup.add(leftPawMesh);
  [
    [-0.08, -0.07, 0.15],
    [0.0, -0.09, 0.17],
    [0.08, -0.07, 0.15]
  ].forEach(p => {
    const pad = new THREE.Mesh(padGeo, pinkPadMat);
    pad.position.set(...p);
    leftPawGroup.add(pad);
  });
  hamsterRoot.add(leftPawGroup);

  // Right Paw
  const rightPawGroup = new THREE.Group();
  rightPawGroup.position.set(0.36, 0.28, 0.86);
  rightPawGroup.rotation.x = 0.20;
  const rightPawMesh = new THREE.Mesh(pawGeo, whitePawMat);
  rightPawGroup.add(rightPawMesh);
  [
    [-0.08, -0.07, 0.15],
    [0.0, -0.09, 0.17],
    [0.08, -0.07, 0.15]
  ].forEach(p => {
    const pad = new THREE.Mesh(padGeo, pinkPadMat);
    pad.position.set(...p);
    rightPawGroup.add(pad);
  });
  hamsterRoot.add(rightPawGroup);

  // 6. Soft Hind Feet Resting on Floor
  const footGeo = new THREE.SphereGeometry(0.24, 20, 20);
  footGeo.scale(1.2, 0.5, 1.5);
  const leftFoot = new THREE.Mesh(footGeo, bauhausYellowMat);
  leftFoot.position.set(-0.74, -0.08, 0.28);
  hamsterRoot.add(leftFoot);

  const rightFoot = new THREE.Mesh(footGeo, bauhausYellowMat);
  rightFoot.position.set(0.74, -0.08, 0.28);
  hamsterRoot.add(rightFoot);

  tailMesh = null;

  scene.add(hamsterRoot);
}

// --------------------------------------------------------------------------
// 3D Mechanical Keyboard Command Deck (60% Layout with Highlighted Keys)
// --------------------------------------------------------------------------
const keycapTextureCache = {};

function createKeycapTexture(label, isInteractive, accentColor, hasLed, isCaps) {
  const cacheKey = `${label}_${isInteractive}_${accentColor || ""}_${hasLed || ""}_${isCaps || ""}`;
  if (keycapTextureCache[cacheKey]) return keycapTextureCache[cacheKey];

  const canvas = document.createElement("canvas");
  canvas.width = 128;
  canvas.height = 128;
  const ctx = canvas.getContext("2d");

  // Keycap base gradient
  const bgGrad = ctx.createLinearGradient(0, 0, 0, 128);
  if (isCaps) {
    bgGrad.addColorStop(0, "#1E1B4B");
    bgGrad.addColorStop(1, "#0F172A");
  } else if (isInteractive) {
    bgGrad.addColorStop(0, "#1E293B");
    bgGrad.addColorStop(1, "#0F172A");
  } else {
    bgGrad.addColorStop(0, "#182030");
    bgGrad.addColorStop(1, "#0F1420");
  }
  ctx.fillStyle = bgGrad;
  ctx.beginPath();
  ctx.roundRect(4, 4, 120, 120, 14);
  ctx.fill();

  // Chamfered Inner Bevel Border
  ctx.strokeStyle = isInteractive ? (accentColor || "#38BDF8") : "rgba(255, 255, 255, 0.12)";
  ctx.lineWidth = isInteractive ? 4 : 2;
  ctx.stroke();

  // Top Inset Highlight
  ctx.strokeStyle = "rgba(255, 255, 255, 0.18)";
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.roundRect(8, 8, 112, 112, 10);
  ctx.stroke();

  // Glowing LED for Caps Lock
  if (hasLed) {
    ctx.fillStyle = "#22C55E";
    ctx.beginPath();
    ctx.arc(24, 24, 5, 0, Math.PI * 2);
    ctx.fill();
  }

  // Golden Upward Arrow for Caps Lock
  if (isCaps) {
    ctx.save();
    ctx.translate(64, 50);
    ctx.beginPath();
    ctx.moveTo(0, -21);
    ctx.lineTo(18, -4);
    ctx.lineTo(8, -4);
    ctx.lineTo(8, 16);
    ctx.lineTo(-8, 16);
    ctx.lineTo(-8, -4);
    ctx.lineTo(-18, -4);
    ctx.closePath();
    ctx.fillStyle = "#F59E0B";
    ctx.fill();
    ctx.strokeStyle = "#0F172A";
    ctx.lineWidth = 2.5;
    ctx.stroke();
    ctx.restore();

    ctx.fillStyle = "#FFFFFF";
    ctx.font = "bold 14px -apple-system, BlinkMacSystemFont, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("caps", 64, 92);
  } else {
    // Standard or Highlighted Legend
    ctx.fillStyle = isInteractive ? (accentColor || "#FFFFFF") : "#94A3B8";
    ctx.font = isInteractive ? "bold 38px -apple-system, BlinkMacSystemFont, monospace" : "bold 30px -apple-system, BlinkMacSystemFont, monospace";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(label, 64, 64);
  }

  const texture = new THREE.CanvasTexture(canvas);
  texture.center.set(0.5, 0.5);
  texture.rotation = Math.PI;
  texture.anisotropy = 4;
  keycapTextureCache[cacheKey] = texture;
  return texture;
}

function buildMechanicalKeyboardDeck() {
  keyboardGroup = new THREE.Group();
  keyboardGroup.scale.set(0.48, 0.48, 0.48); // Scaled proportionally with hamster
  keyboardGroup.position.set(-0.35, -0.44, 0.95); // Resting cleanly on the floor in front of paws
  keyboardGroup.rotation.y = 0; // Spacebar facing user straight
  keyboardGroup.rotation.x = 0.12; // Ergonomic ~7° Apple tilt

  const t = THEMES[currentTheme] || THEMES.dark;
  const chassisColorOverride = 0x1E222D; // Space Gray / Dark Obsidian
  const plateColorOverride = 0x141820;

  // 1. Keyboard Chassis (Dark Anodized Aluminum / Slate)
  const chassisGeo = new THREE.BoxGeometry(2.78, 0.11, 1.10);
  chassisMat = new THREE.MeshStandardMaterial({
    color: chassisColorOverride,
    roughness: t.chassisRoughness,
    metalness: t.chassisMetalness
  });
  chassisMesh = new THREE.Mesh(chassisGeo, chassisMat);
  chassisMesh.position.y = -0.055;
  chassisMesh.castShadow = true;
  chassisMesh.receiveShadow = true;
  keyboardGroup.add(chassisMesh);

  // Top Plate Inset
  const plateGeo = new THREE.BoxGeometry(2.70, 0.03, 1.02);
  plateMat = new THREE.MeshStandardMaterial({
    color: plateColorOverride,
    roughness: t.plateRoughness,
    metalness: t.plateMetalness
  });
  plateMesh = new THREE.Mesh(plateGeo, plateMat);
  plateMesh.position.y = 0.005;
  keyboardGroup.add(plateMesh);

  // Neon Underglow Strips (Front edge facing viewer and rear edge facing hamster)
  const glowStripGeo = new THREE.BoxGeometry(2.68, 0.015, 0.015);
  glowStripMat = new THREE.MeshBasicMaterial({ color: t.glowStripColor });
  glowStripMesh = new THREE.Mesh(glowStripGeo, glowStripMat);
  glowStripMesh.position.set(0, -0.01, -0.54); // Facing viewer along front deck edge
  keyboardGroup.add(glowStripMesh);

  const glowStripRear = new THREE.Mesh(glowStripGeo, glowStripMat);
  glowStripRear.position.set(0, -0.01, 0.54); // Facing hamster under spacebar
  keyboardGroup.add(glowStripRear);

  // 2. Key Matrix Layout
  const unitSize = 0.155;
  const keyGap = 0.022;
  const step = unitSize + keyGap; // ~0.177
  const startZ = -0.36;

  // Key creation helper
  function addKey(x, z, widthUnits, label, options = {}) {
    const keyWidth = unitSize * widthUnits + keyGap * (widthUnits - 1);
    const keyDepth = unitSize;
    const keyHeight = 0.075;

    const topTex = createKeycapTexture(
      label,
      options.isInteractive,
      options.accentColor,
      options.hasLed,
      options.isCaps
    );

    const sideMat = new THREE.MeshStandardMaterial({
      color: options.isCaps ? 0x1A2238 : (options.isInteractive ? 0x1E293B : 0x121824),
      roughness: 0.4,
      metalness: 0.3
    });

    const topMat = new THREE.MeshStandardMaterial({
      map: topTex,
      roughness: 0.28,
      metalness: 0.25,
      emissive: options.accentColor ? new THREE.Color(options.accentColor) : new THREE.Color(0x000000),
      emissiveIntensity: options.isInteractive ? 0.35 : 0.0
    });

    // Box materials: [+X, -X, +Y(top), -Y, +Z, -Z]
    const keyMesh = new THREE.Mesh(
      new THREE.BoxGeometry(keyWidth, keyHeight, keyDepth),
      [sideMat, sideMat, topMat, sideMat, sideMat, sideMat]
    );

    const baseY = 0.055;
    keyMesh.position.set(x, baseY, z);
    keyMesh.castShadow = true;
    keyMesh.receiveShadow = true;

    keyMesh.userData = {
      label: label,
      basePosY: baseY,
      isInteractive: !!options.isInteractive,
      category: options.category || null,
      subIndex: options.subIndex !== undefined ? options.subIndex : null,
      keyId: options.keyId || label.toLowerCase(),
      accentColor: options.accentColor || null
    };

    if (options.hasLed) {
      const ledLight = new THREE.PointLight(0x22C55E, 0.4, 0.25);
      ledLight.position.set(-keyWidth * 0.26, keyHeight * 0.6, -keyDepth * 0.2);
      keyMesh.add(ledLight);
      keyMesh.userData.ledLight = ledLight;
    }

    if (options.isInteractive) {
      interactiveKeyMeshes.push(keyMesh);
      keyMeshMap[keyMesh.userData.keyId] = keyMesh;
    }

    keyboardGroup.add(keyMesh);
    return keyMesh;
  }

  // Row 0: Numbers Row (Z = -0.36)
  let curX = -1.22;
  addKey(curX + 0.5 * step, startZ, 1.0, "Esc");
  curX += step;
  
  // Highlighted Profile slots 1..4
  addKey(curX + 0.5 * step, startZ, 1.0, "1", { isInteractive: true, category: "chrome", subIndex: 0, keyId: "1", accentColor: "#F43F5E" });
  curX += step;
  addKey(curX + 0.5 * step, startZ, 1.0, "2", { isInteractive: true, category: "chrome", subIndex: 1, keyId: "2", accentColor: "#10B981" });
  curX += step;
  addKey(curX + 0.5 * step, startZ, 1.0, "3", { isInteractive: true, category: "chrome", subIndex: 2, keyId: "3", accentColor: "#F59E0B" });
  curX += step;
  addKey(curX + 0.5 * step, startZ, 1.0, "4", { isInteractive: true, category: "chrome", subIndex: 3, keyId: "4", accentColor: "#06B6D4" });
  curX += step;

  ["5", "6", "7", "8", "9", "0", "-", "="].forEach(k => {
    addKey(curX + 0.5 * step, startZ, 1.0, k);
    curX += step;
  });
  addKey(curX + 0.75 * step, startZ, 1.5, "Bksp");

  // Row 1: QWERTY Row (Z = -0.18)
  curX = -1.22;
  addKey(curX + 0.7 * step, startZ + step, 1.4, "Tab");
  curX += 1.4 * step;

  ["Q", "W", "E", "R"].forEach(k => {
    addKey(curX + 0.5 * step, startZ + step, 1.0, k);
    curX += step;
  });

  // Highlighted T for Terminal
  addKey(curX + 0.5 * step, startZ + step, 1.0, "T", { isInteractive: true, category: "terminal", keyId: "t", accentColor: "#10B981" });
  curX += step;

  ["Y", "U"].forEach(k => {
    addKey(curX + 0.5 * step, startZ + step, 1.0, k);
    curX += step;
  });

  // Highlighted I for IDE
  addKey(curX + 0.5 * step, startZ + step, 1.0, "I", { isInteractive: true, category: "ide", keyId: "i", accentColor: "#6366F1" });
  curX += step;

  ["O", "P", "[", "]", "\\"].forEach(k => {
    addKey(curX + 0.5 * step, startZ + step, 1.0, k);
    curX += step;
  });

  // Row 2: Home Row (Z = 0.0)
  curX = -1.22;
  // Highlighted Caps Lock with green LED & golden arrow
  addKey(curX + 0.875 * step, startZ + step * 2, 1.75, "Caps", { isInteractive: true, isCaps: true, hasLed: true, category: "caps", keyId: "caps", accentColor: "#F59E0B" });
  curX += 1.75 * step;

  // Highlighted A for AI Agent
  addKey(curX + 0.5 * step, startZ + step * 2, 1.0, "A", { isInteractive: true, category: "ai", keyId: "a", accentColor: "#06B6D4" });
  curX += step;

  ["S", "D", "F", "G", "H", "J", "K", "L", ";", "'"].forEach(k => {
    if (k === "F") {
      addKey(curX + 0.5 * step, startZ + step * 2, 1.0, "F", { isInteractive: true, category: "finder", keyId: "f", accentColor: "#0284C7" });
    } else if (k === "S") {
      addKey(curX + 0.5 * step, startZ + step * 2, 1.0, "S", { isInteractive: true, category: "settings", keyId: "s", accentColor: "#64748B" });
    } else {
      addKey(curX + 0.5 * step, startZ + step * 2, 1.0, k);
    }
    curX += step;
  });
  addKey(curX + 0.9 * step, startZ + step * 2, 1.8, "Enter");

  // Row 3: Shift Row (Z = 0.18)
  curX = -1.22;
  addKey(curX + 1.05 * step, startZ + step * 3, 2.1, "Shift");
  curX += 2.1 * step;

  ["Z", "X"].forEach(k => {
    addKey(curX + 0.5 * step, startZ + step * 3, 1.0, k);
    curX += step;
  });

  // Highlighted C for Chrome Profiles
  addKey(curX + 0.5 * step, startZ + step * 3, 1.0, "C", { isInteractive: true, category: "chrome", keyId: "c", accentColor: "#3B82F6" });
  curX += step;

  addKey(curX + 0.5 * step, startZ + step * 3, 1.0, "V");
  curX += step;

  // Dynamic B for Brave Profiles
  addKey(curX + 0.5 * step, startZ + step * 3, 1.0, "B", { isInteractive: true, category: "chrome", keyId: "b", accentColor: "#FB542B" });
  curX += step;

  // Highlighted N for Notes
  addKey(curX + 0.5 * step, startZ + step * 3, 1.0, "N", { isInteractive: true, category: "notes", keyId: "n", accentColor: "#F59E0B" });
  curX += step;

  ["M", ",", ".", "/"].forEach(k => {
    addKey(curX + 0.5 * step, startZ + step * 3, 1.0, k);
    curX += step;
  });
  addKey(curX + 1.05 * step, startZ + step * 3, 2.1, "Shift");

  // Row 4: Spacebar Row (Z = 0.36)
  curX = -1.22;
  ["Ctrl", "Opt", "Cmd"].forEach(k => {
    addKey(curX + 0.625 * step, startZ + step * 4, 1.25, k);
    curX += 1.25 * step;
  });

  // Spacebar
  addKey(curX + 2.75 * step, startZ + step * 4, 5.5, "Xomsky Space");
  curX += 5.5 * step;

  ["Cmd", "Opt", "Fn", "Ctrl"].forEach(k => {
    addKey(curX + 0.625 * step, startZ + step * 4, 1.25, k);
    curX += 1.25 * step;
  });

  scene.add(keyboardGroup);
}

// ==========================================================================
// 4. Category Activation & Physical 3D Keycap Reactions
// ==========================================================================
function getActiveBrowserProfiles() {
  return PROFILES;
}

const ANTIGRAVITY_APPS = [
  { name: "Antigravity", icon: "assets/images/icon_antigravity.png", sub: "Agent Studio" },
  { name: "Antigravity IDE", icon: "assets/images/icon_antigravity_ide.png", sub: "Workspace IDE" }
];

let isSquishing = false;
let squishTime = 0;

function triggerHamsterSquish() {
  isSquishing = true;
  squishTime = 0;
  sound.playChime();
}

function activateCategory(category = "chrome", subIndex = null, keyId = null, fromUser = false) {
  if (fromUser) userInteracted = true;
  currentCategory = category;

  if (category === "chrome") {
    const profs = getActiveBrowserProfiles();
    if (subIndex !== null && subIndex !== undefined) {
      activeIndex = parseInt(subIndex, 10);
    } else {
      activeIndex = (activeIndex + 1) % profs.length;
    }
  } else if (category === "ai") {
    if (subIndex !== null && subIndex !== undefined) {
      activeIndex = parseInt(subIndex, 10);
    } else {
      activeIndex = (activeIndex + 1) % ANTIGRAVITY_APPS.length;
    }
  }

  sound.playClick();
  triggerHamsterSquish();

  // Physical 3D key depression animation
  const defaultBrowserKey = currentActiveBrowser === "brave" ? "b" : "c";
  const targetKeyId = keyId || (category === "chrome" ? (subIndex !== null ? String(subIndex + 1) : defaultBrowserKey) : keyId);
  const keyMesh = keyMeshMap[targetKeyId] || (category === "chrome" ? keyMeshMap[defaultBrowserKey] : keyMeshMap[category ? category[0] : "c"]);

  if (keyMesh) {
    keyMesh.position.y = keyMesh.userData.basePosY - 0.045;
    if (keyMesh.material && keyMesh.material[2]) {
      keyMesh.material[2].emissiveIntensity = 2.8;
    }

    setTimeout(() => {
      if (keyMesh) {
        keyMesh.position.y = keyMesh.userData.basePosY;
        if (keyMesh.material && keyMesh.material[2]) {
          keyMesh.material[2].emissiveIntensity = 0.35;
        }
      }
    }, 130);
  }

  // Synchronize Mascot Reaction in UI
  if (window.xomskyInteractions && typeof window.xomskyInteractions.handleMascotReaction === "function") {
    window.xomskyInteractions.handleMascotReaction(currentCategory, activeIndex, targetKeyId);
  } else if (window.xomskyVariants && typeof window.xomskyVariants.handleMascotReaction === "function") {
    window.xomskyVariants.handleMascotReaction(currentCategory, activeIndex, targetKeyId);
  }
}

// --------------------------------------------------------------------------
// Mouse & Raycasting Handlers
// --------------------------------------------------------------------------
let hoveredKeyMesh = null;

let _cachedCanvasContainer = null;
function onMouseMove(e) {
  if (!_cachedCanvasContainer) _cachedCanvasContainer = document.getElementById("canvas-container");
  if (!_cachedCanvasContainer || !camera) return;

  mouseX = (e.clientX / window.innerWidth) * 2 - 1;
  mouseY = -(e.clientY / window.innerHeight) * 2 + 1;
  targetHeadX = RESTING_GAZE_X + mouseX * 0.20;
  targetHeadY = RESTING_GAZE_Y + mouseY * 0.15;

  mouseVec.x = mouseX;
  mouseVec.y = mouseY;
  mouseMoved = true;
}

function onPointerDown(e) {
  userInteracted = true;
  mouseVec.x = (e.clientX / window.innerWidth) * 2 - 1;
  mouseVec.y = -(e.clientY / window.innerHeight) * 2 + 1;

  raycaster.setFromCamera(mouseVec, camera);

  // 1. Raycast interactive keys
  const keyHits = raycaster.intersectObjects(interactiveKeyMeshes, true);
  if (keyHits.length > 0) {
    const hitKey = keyHits[0].object;
    const uData = hitKey.userData;
    activateCategory(uData.category, uData.subIndex, uData.keyId, true);
    return;
  }

  // 2. Raycast hamster for squish squeeze
  const hamsterHits = raycaster.intersectObjects(hamsterRoot ? hamsterRoot.children : [], true);
  if (hamsterHits.length > 0) {
    triggerHamsterSquish();
  }
}

function onWindowResize() {
  const w = window.innerWidth;
  const h = window.innerHeight;
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
  renderer.setSize(w, h);

  const curVar = document.documentElement.getAttribute("data-design-variant") || "option-c";
  if (curVar === "option-c" && currentCamView !== "rear") {
    const targetCam = w <= 900 ? "mobileOptionC" : "optionC";
    if (currentCamView !== targetCam) {
      setCameraView(targetCam, true);
    }
  }
}

// --------------------------------------------------------------------------
// Theme Transition & Dynamic Lighting Engine
// --------------------------------------------------------------------------
function applyTheme(themeName, animate = true, persist = false) {
  currentTheme = themeName;
  const target = THEMES[themeName] || THEMES.dark;

  // Update DOM tokens & persistence
  document.documentElement.setAttribute("data-theme", themeName);
  const themeIcon = document.getElementById("theme-icon");
  if (themeIcon) themeIcon.textContent = themeName === "dark" ? "☀️" : "🌙";
  if (persist) {
    try {
      localStorage.setItem("xomsky_theme_override", themeName);
      localStorage.setItem("xomsky_theme", themeName);
    } catch(e) {}
  }

  if (!scene || !floorMat) return;

  if (!animate) {
    scene.background.setHex(target.bg);
    if (scene.fog) {
      scene.fog.color.setHex(target.bg);
      scene.fog.density = target.fogDensity;
    }
    if (ambientLight) {
      ambientLight.color.setHex(target.ambientColor);
      ambientLight.intensity = target.ambientIntensity;
    }
    if (keyLight) {
      keyLight.color.setHex(target.keyLightColor);
      keyLight.intensity = target.keyLightIntensity;
    }
    if (rimLightL) {
      rimLightL.color.setHex(target.rimLColor);
      rimLightL.intensity = target.rimLIntensity;
    }
    if (rimLightR) {
      rimLightR.color.setHex(target.rimRColor);
      rimLightR.intensity = target.rimRIntensity;
    }
    if (fillLight) {
      fillLight.color.setHex(target.fillColor);
      fillLight.intensity = target.fillIntensity;
    }
    if (floorMat) {
      floorMat.color.setHex(target.floorColor);
      floorMat.roughness = target.floorRoughness;
      floorMat.metalness = target.floorMetalness;
    }
    if (panelMat) panelMat.color.setHex(target.panelColor);
    if (pillarMat) {
      pillarMat.color.setHex(target.pillarColor);
      pillarMat.roughness = target.pillarRoughness;
      pillarMat.metalness = target.pillarMetalness;
    }
    if (chassisMat) {
      chassisMat.color.setHex(target.chassisColor);
      chassisMat.roughness = target.chassisRoughness;
      chassisMat.metalness = target.chassisMetalness;
    }
    if (plateMat) {
      plateMat.color.setHex(target.plateColor);
      plateMat.roughness = target.plateRoughness;
      plateMat.metalness = target.plateMetalness;
    }
    if (glowStripMat) glowStripMat.color.setHex(target.glowStripColor);
    return;
  }

  // Animate lerp transition
  themeTransition.from = {
    bgColor: scene.background.clone(),
    fogDensity: scene.fog ? scene.fog.density : target.fogDensity,
    ambientColor: ambientLight ? ambientLight.color.clone() : new THREE.Color(target.ambientColor),
    ambientIntensity: ambientLight ? ambientLight.intensity : target.ambientIntensity,
    keyLightColor: keyLight ? keyLight.color.clone() : new THREE.Color(target.keyLightColor),
    keyLightIntensity: keyLight ? keyLight.intensity : target.keyLightIntensity,
    rimLColor: rimLightL ? rimLightL.color.clone() : new THREE.Color(target.rimLColor),
    rimLIntensity: rimLightL ? rimLightL.intensity : target.rimLIntensity,
    rimRColor: rimLightR ? rimLightR.color.clone() : new THREE.Color(target.rimRColor),
    rimRIntensity: rimLightR ? rimLightR.intensity : target.rimRIntensity,
    fillColor: fillLight ? fillLight.color.clone() : new THREE.Color(target.fillColor),
    fillIntensity: fillLight ? fillLight.intensity : target.fillIntensity,
    floorColor: floorMat ? floorMat.color.clone() : new THREE.Color(target.floorColor),
    floorRoughness: floorMat ? floorMat.roughness : target.floorRoughness,
    floorMetalness: floorMat ? floorMat.metalness : target.floorMetalness,
    panelColor: panelMat ? panelMat.color.clone() : new THREE.Color(target.panelColor),
    pillarColor: pillarMat ? pillarMat.color.clone() : new THREE.Color(target.pillarColor),
    pillarRoughness: pillarMat ? pillarMat.roughness : target.pillarRoughness,
    pillarMetalness: pillarMat ? pillarMat.metalness : target.pillarMetalness,
    chassisColor: chassisMat ? chassisMat.color.clone() : new THREE.Color(target.chassisColor),
    chassisRoughness: chassisMat ? chassisMat.roughness : target.chassisRoughness,
    chassisMetalness: chassisMat ? chassisMat.metalness : target.chassisMetalness,
    plateColor: plateMat ? plateMat.color.clone() : new THREE.Color(target.plateColor),
    plateRoughness: plateMat ? plateMat.roughness : target.plateRoughness,
    plateMetalness: plateMat ? plateMat.metalness : target.plateMetalness
  };

  themeTransition.to = {
    bgColor: new THREE.Color(target.bg),
    fogDensity: target.fogDensity,
    ambientColor: new THREE.Color(target.ambientColor),
    ambientIntensity: target.ambientIntensity,
    keyLightColor: new THREE.Color(target.keyLightColor),
    keyLightIntensity: target.keyLightIntensity,
    rimLColor: new THREE.Color(target.rimLColor),
    rimLIntensity: target.rimLIntensity,
    rimRColor: new THREE.Color(target.rimRColor),
    rimRIntensity: target.rimRIntensity,
    fillColor: new THREE.Color(target.fillColor),
    fillIntensity: target.fillIntensity,
    floorColor: new THREE.Color(target.floorColor),
    floorRoughness: target.floorRoughness,
    floorMetalness: target.floorMetalness,
    panelColor: new THREE.Color(target.panelColor),
    pillarColor: new THREE.Color(target.pillarColor),
    pillarRoughness: target.pillarRoughness,
    pillarMetalness: target.pillarMetalness,
    chassisColor: new THREE.Color(target.chassisColor),
    chassisRoughness: target.chassisRoughness,
    chassisMetalness: target.chassisMetalness,
    plateColor: new THREE.Color(target.plateColor),
    plateRoughness: target.plateRoughness,
    plateMetalness: target.plateMetalness
  };

  const curVar = document.documentElement.getAttribute("data-design-variant") || "option-c";
  if (curVar === "option-c" || curVar === "option-a") {
    const isLight = (themeName === "light");
    themeTransition.to.keyLightIntensity = isLight ? 1.50 : 1.20;
    themeTransition.to.fillLightIntensity = isLight ? 0.95 : 0.68;
    themeTransition.to.rimLIntensity = isLight ? 1.40 : 1.95;
    themeTransition.to.rimRIntensity = isLight ? 0.30 : 2.60;
    themeTransition.to.ambientIntensity = isLight ? 1.15 : 0.85;
    themeTransition.to.fogDensity = isLight ? 0.016 : 0.014;
  }

  themeTransition.progress = 0;
  themeTransition.active = true;
}

function switchTheme(targetTheme = null) {
  const next = targetTheme || (currentTheme === "dark" ? "light" : "dark");
  sound.playRelayClick(next === "dark");
  applyTheme(next, true, true);
}

// --------------------------------------------------------------------------
// Animation Loop (Thermal & Battery Conscious)
// --------------------------------------------------------------------------
let clock = new THREE.Clock();
let lastFrameTime = 0;
const TARGET_FPS = 60;
const FRAME_INTERVAL = 1000 / TARGET_FPS; // ~16.67ms cap
let isTabVisible = !document.hidden;
let isCanvasVisible = true;
let isAnimating = false;

// Completely stop GPU drawing when browser tab is inactive/minimized
document.addEventListener("visibilitychange", () => {
  isTabVisible = !document.hidden;
  if (isTabVisible && isCanvasVisible && !isAnimating) {
    lastFrameTime = performance.now();
    isAnimating = true;
    requestAnimationFrame(animate);
  }
});

// Completely stop GPU drawing when canvas is scrolled out of view
document.addEventListener("DOMContentLoaded", () => {
  // Suspend WebGL when user scrolls down into founder-story / footer (works on all screen heights >= 720p)
  const founderSection = document.getElementById("founder-story");
  if (founderSection) {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        // When founder story enters viewport (>15%), suspend WebGL canvas (0% GPU)
        isCanvasVisible = !entry.isIntersecting;
        if (isCanvasVisible && isTabVisible && !isAnimating) {
          lastFrameTime = performance.now();
          isAnimating = true;
          requestAnimationFrame(animate);
        }
      });
    }, { threshold: 0.15 });
    observer.observe(founderSection);
  }
});

function animate(currentTime = performance.now()) {
  if (!isTabVisible || !isCanvasVisible) {
    isAnimating = false;
    return; // 0% GPU when in background or off-screen
  }
  isAnimating = true;

  requestAnimationFrame(animate);

  // Throttle 120Hz ProMotion displays to a rock-solid 60fps to prevent fan noise & GPU heat
  const elapsed = currentTime - lastFrameTime;
  if (elapsed < FRAME_INTERVAL) return;
  lastFrameTime = currentTime - (elapsed % FRAME_INTERVAL);

  const delta = Math.min(clock.getDelta(), 0.1);
  const time = clock.getElapsedTime();

  controls.update();

  // Hover Raycasting (only when mouse has moved)
  if (camera && mouseVec && mouseMoved) {
    mouseMoved = false;
    const container = document.getElementById("canvas-container");
    raycaster.setFromCamera(mouseVec, camera);
    const keyHits = raycaster.intersectObjects(interactiveKeyMeshes, true);

    if (keyHits.length > 0) {
      if (container && container.style.cursor !== "pointer") container.style.cursor = "pointer";
      const hitKey = keyHits[0].object;
      if (hoveredKeyMesh !== hitKey) {
        if (hoveredKeyMesh && hoveredKeyMesh.material && hoveredKeyMesh.material[2]) {
          hoveredKeyMesh.material[2].emissiveIntensity = 0.35;
        }
        hoveredKeyMesh = hitKey;
        if (hoveredKeyMesh.material && hoveredKeyMesh.material[2]) {
          hoveredKeyMesh.material[2].emissiveIntensity = 1.2;
        }
      }
    } else {
      if (container && container.style.cursor !== "grab") container.style.cursor = "grab";
      if (hoveredKeyMesh && hoveredKeyMesh.material && hoveredKeyMesh.material[2]) {
        hoveredKeyMesh.material[2].emissiveIntensity = 0.35;
        hoveredKeyMesh = null;
      }
    }
  }

  // Dynamic Theme Transition Interpolation (Cubic Ease)
  if (themeTransition.active) {
    themeTransition.progress += delta / themeTransition.duration;
    const p = Math.min(1.0, themeTransition.progress);
    const ease = p < 0.5 ? 4 * p * p * p : 1 - Math.pow(-2 * p + 2, 3) / 2;

    const f = themeTransition.from;
    const t = themeTransition.to;

    scene.background.copy(f.bgColor).lerp(t.bgColor, ease);
    if (scene.fog) {
      scene.fog.color.copy(f.bgColor).lerp(t.bgColor, ease);
      scene.fog.density = THREE.MathUtils.lerp(f.fogDensity, t.fogDensity, ease);
    }
    if (ambientLight) {
      ambientLight.color.copy(f.ambientColor).lerp(t.ambientColor, ease);
      ambientLight.intensity = THREE.MathUtils.lerp(f.ambientIntensity, t.ambientIntensity, ease);
    }
    if (keyLight) {
      keyLight.color.copy(f.keyLightColor).lerp(t.keyLightColor, ease);
      keyLight.intensity = THREE.MathUtils.lerp(f.keyLightIntensity, t.keyLightIntensity, ease);
    }
    if (rimLightL) {
      rimLightL.color.copy(f.rimLColor).lerp(t.rimLColor, ease);
      rimLightL.intensity = THREE.MathUtils.lerp(f.rimLIntensity, t.rimLIntensity, ease);
    }
    if (rimLightR) {
      rimLightR.color.copy(f.rimRColor).lerp(t.rimRColor, ease);
      rimLightR.intensity = THREE.MathUtils.lerp(f.rimRIntensity, t.rimRIntensity, ease);
    }
    if (fillLight) {
      fillLight.color.copy(f.fillColor).lerp(t.fillColor, ease);
      fillLight.intensity = THREE.MathUtils.lerp(f.fillIntensity, t.fillIntensity, ease);
    }
    if (floorMat) {
      floorMat.color.copy(f.floorColor).lerp(t.floorColor, ease);
      floorMat.roughness = THREE.MathUtils.lerp(f.floorRoughness, t.floorRoughness, ease);
      floorMat.metalness = THREE.MathUtils.lerp(f.floorMetalness, t.floorMetalness, ease);
    }
    if (panelMat) {
      panelMat.color.copy(f.panelColor).lerp(t.panelColor, ease);
    }
    if (pillarMat) {
      pillarMat.color.copy(f.pillarColor).lerp(t.pillarColor, ease);
      pillarMat.roughness = THREE.MathUtils.lerp(f.pillarRoughness, t.pillarRoughness, ease);
      pillarMat.metalness = THREE.MathUtils.lerp(f.pillarMetalness, t.pillarMetalness, ease);
    }
    if (chassisMat) {
      chassisMat.color.copy(f.chassisColor).lerp(t.chassisColor, ease);
      chassisMat.roughness = THREE.MathUtils.lerp(f.chassisRoughness, t.chassisRoughness, ease);
      chassisMat.metalness = THREE.MathUtils.lerp(f.chassisMetalness, t.chassisMetalness, ease);
    }
    if (plateMat) {
      plateMat.color.copy(f.plateColor).lerp(t.plateColor, ease);
      plateMat.roughness = THREE.MathUtils.lerp(f.plateRoughness, t.plateRoughness, ease);
      plateMat.metalness = THREE.MathUtils.lerp(f.plateMetalness, t.plateMetalness, ease);
    }

    if (p >= 1.0) {
      themeTransition.active = false;
    }
  }

  // Giant Hamster Breathing Motion (Calm, deep, smooth liminal breathing)
  const BASE_SCALE = 0.68;
  const BASE_Y = -0.48;
  const breath = Math.sin(time * 1.2) * 0.005;
  if (!isSquishing && hamsterRoot) {
    hamsterRoot.scale.set(BASE_SCALE + breath * 0.03, BASE_SCALE - breath * 0.04, BASE_SCALE + breath * 0.03);
  }

  // Smooth Camera Perspective Glide (Switch between Butt View & Front View)
  if (isCamTransitioning && camera && controls) {
    camera.position.lerp(targetCamPos, delta * 5.5);
    controls.target.lerp(targetCamLook, delta * 5.5);
    controls.update();
    if (camera.position.distanceTo(targetCamPos) < 0.04) {
      camera.position.copy(targetCamPos);
      controls.target.copy(targetCamLook);
      controls.update();
      isCamTransitioning = false;
    }
  }

  // Soft & Gentle Tactile Squish / Micro-Hop on Keypress
  if (isSquishing && cheeksGroup) {
    squishTime += delta * 8.0;
    const factor = Math.sin(squishTime) * Math.exp(-squishTime * 0.50);
    cheeksGroup.scale.set(1.0 + factor * 0.16, 1.0 - factor * 0.10, 1.0 + factor * 0.12);
    if (tailMesh) {
      tailMesh.rotation.z = Math.sin(squishTime * 3.0) * factor * 0.35; // cute tail wag
    }
    if (hamsterRoot) {
      hamsterRoot.rotation.z = Math.sin(squishTime * 1.5) * factor * 0.035; // gentle, cute wobble
      hamsterRoot.position.y = BASE_Y + Math.abs(Math.sin(squishTime * 1.2)) * factor * 0.05; // subtle micro-hop
    }
    if (squishTime > Math.PI * 2.0) {
      isSquishing = false;
      cheeksGroup.scale.set(1, 1, 1);
      if (tailMesh) tailMesh.rotation.z = 0;
      if (hamsterRoot) {
        hamsterRoot.rotation.z = 0;
        hamsterRoot.position.y = BASE_Y;
      }
    }
  }

  // Rare, gentle nose micro-twitch
  if (snoutGroup) {
    const twitch = Math.sin(time * 6.0) * 0.003 * (Math.sin(time * 0.3) > 0.85 ? 1 : 0);
    snoutGroup.position.y = 0.96 + twitch;
    if (whiskersGroup) whiskersGroup.rotation.z = twitch * 0.5;
  }

  // Rare, gentle ear micro-twitch
  if (leftEarGroup && rightEarGroup) {
    const earTwitch = Math.sin(time * 5.0) * 0.012 * (Math.sin(time * 0.25) > 0.90 ? 1 : 0);
    leftEarGroup.rotation.z = 0.25 + earTwitch;
    rightEarGroup.rotation.z = -0.25 - earTwitch;
  }

  // Eyes Cursor Tracking & Blinking (Gaze-Cueing toward HUD)
  if (eyesGroup) {
    eyesGroup.rotation.y += (targetHeadX - eyesGroup.rotation.y) * 0.08;
    eyesGroup.rotation.x += (-targetHeadY - eyesGroup.rotation.x) * 0.08;
    if (snoutGroup) {
      snoutGroup.rotation.y += (targetHeadX * 0.35 - snoutGroup.rotation.y) * 0.08;
    }

    // Smooth organic blink cycle every 4.2s with cosine easing (duration ~0.15s)
    const blinkPeriod = 4.2;
    const blinkDuration = 0.15;
    const blinkTime = (time + 2.0) % blinkPeriod;
    let blinkScale = 1.0;
    if (blinkTime < blinkDuration) {
      const progress = blinkTime / blinkDuration; // 0 to 1
      const dip = Math.sin(progress * Math.PI); // 0 -> 1 -> 0
      blinkScale = Math.max(0.04, 1.0 - dip * 0.96);
    }
    eyeLeft.scale.y = blinkScale;
    eyeRight.scale.y = blinkScale;
    if (glintLBig && glintRBig && glintLSmall && glintRSmall) {
      glintLBig.scale.y = blinkScale;
      glintRBig.scale.y = blinkScale;
      glintLSmall.scale.y = blinkScale;
      glintRSmall.scale.y = blinkScale;
    }
  }

  renderer.render(scene, camera);
}

// --------------------------------------------------------------------------
// Initialization
// --------------------------------------------------------------------------
document.addEventListener("DOMContentLoaded", () => {
  initThreeJS();
  applyTheme(currentTheme, false, false);

  // Auto-adapt to OS system theme changes if user hasn't set an explicit manual override
  if (window.matchMedia) {
    window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", (e) => {
      try {
        const hasOverride = localStorage.getItem("xomsky_theme_override");
        if (!hasOverride) {
          applyTheme(e.matches ? "dark" : "light", true, false);
        }
      } catch (err) {
        applyTheme(e.matches ? "dark" : "light", true, false);
      }
    });
  }

  // Theme Toggle Button
  const themeBtn = document.getElementById("theme-toggle");
  if (themeBtn) {
    themeBtn.addEventListener("click", () => {
      switchTheme();
    });
  }

  // Sound Toggle Button
  const soundBtn = document.getElementById("sound-toggle");
  if (soundBtn) {
    soundBtn.addEventListener("click", () => {
      const isAudible = sound.toggle();
      const soundIcon = document.getElementById("sound-icon");
      if (soundIcon) soundIcon.textContent = isAudible ? "🔊" : "🔇";
      if (isAudible) sound.playClick();
    });
  }

  // 1-Click Terminal Install Copy
  const copyInstallBtn = document.getElementById("copy-install-btn");
  const installCmd = document.getElementById("install-cmd");
  if (copyInstallBtn && installCmd) {
    const copyAction = () => {
      const text = installCmd.textContent.trim();
      const onCopied = () => {
        const textSpan = copyInstallBtn.querySelector(".copy-text");
        if (textSpan) textSpan.textContent = "Copied! ✓";
        copyInstallBtn.classList.add("copied");
        sound.playChime();
        setTimeout(() => {
          if (textSpan) textSpan.textContent = "Copy";
          copyInstallBtn.classList.remove("copied");
        }, 2200);
      };

      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(onCopied).catch(() => {
          const ta = document.createElement("textarea");
          ta.value = text;
          document.body.appendChild(ta);
          ta.select();
          document.execCommand("copy");
          document.body.removeChild(ta);
          onCopied();
        });
      } else {
        const ta = document.createElement("textarea");
        ta.value = text;
        document.body.appendChild(ta);
        ta.select();
        document.execCommand("copy");
        document.body.removeChild(ta);
        onCopied();
      }
    };

    copyInstallBtn.addEventListener("click", copyAction);
    installCmd.addEventListener("click", copyAction);
  }

  // Camera Perspective Toggle (🍑 Butt View vs 🐹 Face View)
  const camBtn = document.getElementById("cam-view-btn");
  if (camBtn) {
    camBtn.addEventListener("click", toggleCameraView);
  }
  updateCamBtnLabel();

  // Clean Global Keyboard Navigation: [V], [M], [1..4], [C], [B], [T], [I], [A], [N], [Space]
  window.addEventListener("keydown", (e) => {
    if (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA") return;
    if (e.altKey || e.metaKey || e.ctrlKey) return;

    const key = e.key.toLowerCase();
    if (key === "m") {
      switchTheme();
    } else if (key === "v") {
      toggleCameraView();
    } else if (key === "b" && currentActiveBrowser === "brave") {
      e.preventDefault();
      const profiles = getActiveBrowserProfiles();
      activateCategory("chrome", (activeIndex + 1) % profiles.length, "b", true);
    } else if ((key === "c" && currentActiveBrowser === "chrome") || key === " ") {
      e.preventDefault();
      const profiles = getActiveBrowserProfiles();
      activateCategory("chrome", (activeIndex + 1) % profiles.length, "c", true);
    } else if (["1", "2", "3", "4"].includes(key)) {
      activateCategory("chrome", parseInt(key, 10) - 1, key, true);
    } else if (key === "t") {
      activateCategory("terminal", 0, "t", true);
    } else if (key === "i") {
      activateCategory("ide", 0, "i", true);
    } else if (key === "a") {
      activateCategory("ai", 0, "a", true);
    } else if (key === "n") {
      activateCategory("notes", 0, "n", true);
    } else if (key === "capslock") {
      activateCategory("caps", 0, "caps", true);
    }
  });
});

// Export globally
window.xomskySound = sound;
window.activateCategory = activateCategory;
window.triggerHamsterSquish = triggerHamsterSquish;
window.setCameraView = setCameraView;
window.switchTheme = switchTheme;
window.toggleCameraView = toggleCameraView;
