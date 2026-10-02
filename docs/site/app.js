/**
 * NNTS — CYBER-BRUTALIST TRINITRON CRT INTERACTIVE ENGINE
 * Authentic Audio Synthesizer, Live Cathode Simulator, and Copy-on-Select Engine.
 */

(function () {
  "use strict";

  // ==========================================================================
  // 1. TACTILE AUDIO SYNTHESIZER (WEB AUDIO API)
  // ==========================================================================
  class TactileAudioEngine {
    constructor() {
      this.ctx = null;
      this.soundEnabled = localStorage.getItem("nnts_sound_enabled") !== "false";
    }

    init() {
      if (!this.ctx) {
        const AudioContext = window.AudioContext || window.webkitAudioContext;
        if (AudioContext) {
          this.ctx = new AudioContext();
        }
      }
      if (this.ctx && this.ctx.state === "suspended") {
        this.ctx.resume();
      }
    }

    toggle() {
      this.soundEnabled = !this.soundEnabled;
      localStorage.setItem("nnts_sound_enabled", this.soundEnabled.toString());
      return this.soundEnabled;
    }

    playRelayClick() {
      if (!this.soundEnabled) return;
      try {
        this.init();
        if (!this.ctx) return;
        const now = this.ctx.currentTime;

        // Mechanical relay switch: sharp high impulse + resonant click
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = "sine";
        osc.frequency.setValueAtTime(620, now);
        osc.frequency.exponentialRampToValueAtTime(75, now + 0.04);
        gain.gain.setValueAtTime(0.22, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.045);
        osc.connect(gain);
        gain.connect(this.ctx.destination);
        osc.start(now);
        osc.stop(now + 0.05);

        // Low tactile thump
        const thump = this.ctx.createOscillator();
        const thumpGain = this.ctx.createGain();
        thump.type = "triangle";
        thump.frequency.setValueAtTime(140, now);
        thump.frequency.exponentialRampToValueAtTime(35, now + 0.07);
        thumpGain.gain.setValueAtTime(0.28, now);
        thumpGain.gain.exponentialRampToValueAtTime(0.001, now + 0.08);
        thump.connect(thumpGain);
        thumpGain.connect(this.ctx.destination);
        thump.start(now);
        thump.stop(now + 0.09);
      } catch (e) {}
    }

    playDegaussChirp() {
      if (!this.soundEnabled) return;
      try {
        this.init();
        if (!this.ctx) return;
        const now = this.ctx.currentTime;

        // Cathode ray tube channel switch frequency sweep
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = "sawtooth";
        osc.frequency.setValueAtTime(240, now);
        osc.frequency.exponentialRampToValueAtTime(1280, now + 0.06);
        gain.gain.setValueAtTime(0.08, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.07);
        osc.connect(gain);
        gain.connect(this.ctx.destination);
        osc.start(now);
        osc.stop(now + 0.08);
      } catch (e) {}
    }

    playCopyChime() {
      if (!this.soundEnabled) return;
      try {
        this.init();
        if (!this.ctx) return;
        const now = this.ctx.currentTime;

        [880, 1320].forEach((freq, idx) => {
          const osc = this.ctx.createOscillator();
          const gain = this.ctx.createGain();
          osc.type = "sine";
          osc.frequency.setValueAtTime(freq, now + idx * 0.03);
          gain.gain.setValueAtTime(0.12, now + idx * 0.03);
          gain.gain.exponentialRampToValueAtTime(0.001, now + idx * 0.03 + 0.08);
          osc.connect(gain);
          gain.connect(this.ctx.destination);
          osc.start(now + idx * 0.03);
          osc.stop(now + idx * 0.03 + 0.09);
        });
      } catch (e) {}
    }
  }

  const audio = new TactileAudioEngine();

  // ==========================================================================
  // 2. INTERACTIVE TRINITRON COCKPIT CHANNELS DATA & CONTROLLER
  // ==========================================================================
  const CHANNELS_DATABASE = [
    {
      id: 1,
      key: "C",
      modeTag: "TV [C]",
      channelStr: "CH 01 / 05",
      appTitle: "Google Chrome",
      subTitle: "Work Profile",
      osdTitle: "CHROME • WORK PROFILE",
      hotkeyHtml: "<kbd>Caps</kbd> + <kbd>C</kbd> + <kbd>1</kbd>",
      iconSrc: "assets/images/icon_chrome.png",
      avatarSrc: "assets/images/profiles/igor.png",
      hasAvatar: true
    },
    {
      id: 2,
      key: "C",
      modeTag: "TV [C]",
      channelStr: "CH 02 / 05",
      appTitle: "Google Chrome",
      subTitle: "Personal Profile",
      osdTitle: "CHROME • PERSONAL PROFILE",
      hotkeyHtml: "<kbd>Caps</kbd> + <kbd>C</kbd> + <kbd>2</kbd>",
      iconSrc: "assets/images/icon_chrome.png",
      avatarSrc: "assets/images/profiles/nastya.png",
      hasAvatar: true
    },
    {
      id: 3,
      key: "B",
      modeTag: "TV [B]",
      channelStr: "CH 03 / 05",
      appTitle: "Brave Browser",
      subTitle: "Client Profile",
      osdTitle: "BRAVE • CLIENT PROFILE",
      hotkeyHtml: "<kbd>Caps</kbd> + <kbd>B</kbd> + <kbd>3</kbd>",
      iconSrc: "assets/images/icon_chrome.png",
      avatarSrc: "assets/images/profiles/gcp.png",
      hasAvatar: true
    },
    {
      id: 4,
      key: "T",
      modeTag: "TV [T]",
      channelStr: "CH 04 / 05",
      appTitle: "Telegram / Terminal",
      subTitle: "Dev & Comms",
      osdTitle: "APPS • KEY [T] CYCLING",
      hotkeyHtml: "<kbd>Caps</kbd> + <kbd>T</kbd>",
      iconSrc: "assets/images/icon_telegram.png",
      avatarSrc: "assets/images/icon_terminal.png",
      hasAvatar: true
    },
    {
      id: 5,
      key: "O",
      modeTag: "TV [O]",
      channelStr: "CH 05 / 05",
      appTitle: "Obsidian Notes",
      subTitle: "Vault",
      osdTitle: "APP • OBSIDIAN VAULT",
      hotkeyHtml: "<kbd>Caps</kbd> + <kbd>O</kbd>",
      iconSrc: "assets/images/icon_obsidian.png",
      avatarSrc: null,
      hasAvatar: false
    }
  ];

  let currentChannelIndex = 0; // 0-indexed (Channel 1)

  function updateCockpitUI(channelObj) {
    const osdModeTag = document.getElementById("osd-mode-tag");
    const osdTitleText = document.getElementById("osd-title-text");
    const osdChIndicator = document.getElementById("osd-ch-indicator");
    const crtMainIcon = document.getElementById("crt-main-icon");
    const crtProfileBadge = document.getElementById("crt-profile-badge");
    const crtAvatarImg = document.getElementById("crt-avatar-img");
    const crtHeroLabel = document.getElementById("crt-hero-label");
    const crtHeroSublabel = document.getElementById("crt-hero-sublabel");
    const crtHeroHotkey = document.getElementById("crt-hero-hotkey");
    const crtScreenFace = document.getElementById("crt-screen-face");
    const crtAppCard = document.getElementById("crt-app-card");

    if (osdModeTag) osdModeTag.textContent = channelObj.modeTag;
    if (osdTitleText) osdTitleText.textContent = channelObj.osdTitle;
    if (osdChIndicator) osdChIndicator.textContent = channelObj.channelStr;
    if (crtHeroLabel) crtHeroLabel.textContent = channelObj.appTitle;
    if (crtHeroSublabel) crtHeroSublabel.textContent = channelObj.subTitle;

    if (crtHeroHotkey && channelObj.hotkeyHtml) {
      crtHeroHotkey.innerHTML = channelObj.hotkeyHtml;
    }

    if (crtMainIcon) crtMainIcon.src = channelObj.iconSrc;

    if (crtProfileBadge) {
      if (channelObj.hasAvatar && channelObj.avatarSrc) {
        crtProfileBadge.style.display = "block";
        if (crtAvatarImg) crtAvatarImg.src = channelObj.avatarSrc;
      } else {
        crtProfileBadge.style.display = "none";
      }
    }

    // Trigger CRT Screen Glitch / Cathode Flicker Effect
    if (crtScreenFace) {
      crtScreenFace.style.filter = "brightness(1.4) contrast(1.2)";
      setTimeout(() => {
        crtScreenFace.style.filter = "none";
      }, 70);
    }

    if (crtAppCard) {
      crtAppCard.style.transform = "scale(0.97)";
      setTimeout(() => {
        crtAppCard.style.transform = "scale(1)";
      }, 90);
    }

    // Update Channel Dock buttons
    const dockBtns = document.querySelectorAll(".channel-dock-btn, .lean-channel-chip");
    dockBtns.forEach((btn) => {
      const chNum = parseInt(btn.getAttribute("data-channel"), 10);
      if (chNum === channelObj.id) {
        btn.classList.add("active");
      } else {
        btn.classList.remove("active");
      }
    });
  }

  function tuneToChannel(channelId) {
    const target = CHANNELS_DATABASE.find((c) => c.id === channelId);
    if (!target) return;
    currentChannelIndex = CHANNELS_DATABASE.indexOf(target);
    audio.playRelayClick();
    audio.playDegaussChirp();
    updateCockpitUI(target);
  }

  // ==========================================================================
  // 3. COPY ON SELECT LIVE SIMULATOR
  // ==========================================================================
  function setupCopyOnSelectSimulator() {
    const selectZone = document.getElementById("live-select-zone");
    const toast = document.getElementById("live-cursor-toast");
    const chip = document.getElementById("tester-copy-chip");
    if (!selectZone || !toast) return;

    selectZone.addEventListener("mouseup", (e) => {
      const selection = window.getSelection().toString().trim();
      if (selection.length >= 3) {
        audio.playCopyChime();

        // Show floating HUD cursor toast
        toast.style.left = `${e.clientX}px`;
        toast.style.top = `${e.clientY}px`;
        toast.style.display = "inline-flex";

        // Reset toast animation
        toast.style.animation = "none";
        toast.offsetHeight; // trigger reflow
        toast.style.animation = "toast-fade 1.2s forwards";

        if (chip) {
          chip.classList.add("visible");
        }

        setTimeout(() => {
          toast.style.display = "none";
        }, 1200);
      }
    });
  }

  // ==========================================================================
  // 4. 60FPS VIDEO PROOFS CHANNEL SWITCHER
  // ==========================================================================
  function setupVideoProofsSwitcher() {
    const videoBtns = document.querySelectorAll(".video-tuner-btn");
    const player = document.getElementById("proof-video-player");
    if (!player || !videoBtns.length) return;

    videoBtns.forEach((btn) => {
      btn.addEventListener("click", () => {
        videoBtns.forEach((b) => b.classList.remove("active"));
        btn.classList.add("active");

        const src = btn.getAttribute("data-src");
        if (src && player.getAttribute("src") !== src) {
          audio.playRelayClick();
          player.src = src;
          player.play().catch(() => {});
        }
      });
    });
  }

  // ==========================================================================
  // 5. 1-CLICK BREW INSTALL COPY
  // ==========================================================================
  function setupBrewInstallCopy() {
    const brewPill = document.getElementById("brew-copy-pill");
    const brewBtn = document.getElementById("brew-copy-btn");
    const stripPill = document.getElementById("strip-brew-pill");
    const stripBtn = document.getElementById("strip-brew-btn");

    function copyBrew(el, btnEl) {
      const cmd = "brew install --cask xomsky";
      navigator.clipboard.writeText(cmd).then(() => {
        audio.playCopyChime();
        if (btnEl) {
          const original = btnEl.innerHTML;
          btnEl.innerHTML = "✓ Copied!";
          setTimeout(() => {
            btnEl.innerHTML = original;
          }, 2000);
        }
      }).catch(() => {});
    }

    if (brewPill) {
      brewPill.addEventListener("click", () => copyBrew(brewPill, brewBtn));
    }
    if (stripPill) {
      stripPill.addEventListener("click", () => copyBrew(stripPill, stripBtn));
    }
  }

  // ==========================================================================
  // 6. KEYBOARD EVENT LISTENERS (PHYSICAL KEY HOOK)
  // ==========================================================================
  function setupKeyboardListener() {
    window.addEventListener("keydown", (e) => {
      // Avoid intercepting when user types in inputs
      if (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA") return;

      const key = e.key.toLowerCase();
      if (key === "1") {
        tuneToChannel(1);
      } else if (key === "2") {
        tuneToChannel(2);
      } else if (key === "3") {
        tuneToChannel(3);
      } else if (key === "4") {
        tuneToChannel(4);
      } else if (key === "5") {
        tuneToChannel(5);
      } else if (key === "c") {
        tuneToChannel(currentChannelIndex === 0 ? 2 : 1);
      } else if (key === "b") {
        tuneToChannel(3);
      } else if (key === "t") {
        tuneToChannel(4);
      } else if (key === "o") {
        tuneToChannel(5);
      }
    });
  }

  // ==========================================================================
  // 7. INITIALIZATION & BINDINGS
  // ==========================================================================
  document.addEventListener("DOMContentLoaded", () => {
    // 1. Audio Button Toggle
    const audioBtn = document.getElementById("audio-toggle-btn");
    const audioLabel = document.getElementById("audio-label");
    if (audioBtn) {
      
      audioBtn.addEventListener("click", () => {
        const state = audio.toggle();
        
        if (state) audio.playRelayClick();
      });
    }

    // 2. Channel Dock Bindings
    const dockBtns = document.querySelectorAll(".channel-dock-btn, .lean-channel-chip");
    dockBtns.forEach((btn) => {
      btn.addEventListener("click", () => {
        const ch = parseInt(btn.getAttribute("data-channel"), 10);
        if (ch) tuneToChannel(ch);
      });
    });

    // 3. Remote Control Prop Direct Click Cycling
    const rcUnit = document.querySelector(".lean-rc-unit");
    if (rcUnit) {
      rcUnit.style.cursor = "pointer";
      rcUnit.setAttribute("title", "Click remote to cycle channels");
      rcUnit.addEventListener("click", () => {
        const nextIdx = (currentChannelIndex + 1) % CHANNELS_DATABASE.length;
        tuneToChannel(CHANNELS_DATABASE[nextIdx].id);
      });
    }

    // 5. Profiles Rack Items Clickable
    const rackItems = document.querySelectorAll(".rack-item");
    rackItems.forEach((item, idx) => {
      item.addEventListener("click", () => {
        rackItems.forEach((r) => r.classList.remove("active"));
        item.classList.add("active");
        if (idx < 3) tuneToChannel(idx + 1);
      });
    });

    // 6. Live Simulators & Proofs
    setupCopyOnSelectSimulator();
    setupVideoProofsSwitcher();
    setupBrewInstallCopy();
    setupKeyboardListener();

    // Initial render
    updateCockpitUI(CHANNELS_DATABASE[0]);
  });
})();
