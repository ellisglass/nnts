/**
 * NNTS — RETRO TRINITRON CRT & RM-NNTS REMOTE CONTROL ENGINE
 * Authentic Web Audio Synthesizer, TV Power Switcher, and 60FPS Video Channel Tuner.
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

        // Mechanical relay impulse
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

    playTvPowerOn() {
      if (!this.soundEnabled) return;
      try {
        this.init();
        if (!this.ctx) return;
        const now = this.ctx.currentTime;

        // 1. Heavy mechanical power switch clunk
        const clunk = this.ctx.createOscillator();
        const clunkGain = this.ctx.createGain();
        clunk.type = "sine";
        clunk.frequency.setValueAtTime(160, now);
        clunk.frequency.exponentialRampToValueAtTime(30, now + 0.09);
        clunkGain.gain.setValueAtTime(0.4, now);
        clunkGain.gain.exponentialRampToValueAtTime(0.001, now + 0.1);
        clunk.connect(clunkGain);
        clunkGain.connect(this.ctx.destination);
        clunk.start(now);
        clunk.stop(now + 0.11);

        // 2. High-pitch CRT flyback transformer whine & degauss sweep
        const whine = this.ctx.createOscillator();
        const whineGain = this.ctx.createGain();
        whine.type = "sawtooth";
        whine.frequency.setValueAtTime(120, now + 0.02);
        whine.frequency.exponentialRampToValueAtTime(1200, now + 0.14);
        whine.frequency.exponentialRampToValueAtTime(2600, now + 0.28);
        whineGain.gain.setValueAtTime(0.02, now + 0.02);
        whineGain.gain.linearRampToValueAtTime(0.14, now + 0.12);
        whineGain.gain.exponentialRampToValueAtTime(0.001, now + 0.38);
        whine.connect(whineGain);
        whineGain.connect(this.ctx.destination);
        whine.start(now + 0.02);
        whine.stop(now + 0.4);
      } catch (e) {}
    }

    playTvPowerOff() {
      if (!this.soundEnabled) return;
      try {
        this.init();
        if (!this.ctx) return;
        const now = this.ctx.currentTime;

        // Power disconnect click + capacitor discharge chirp
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = "triangle";
        osc.frequency.setValueAtTime(420, now);
        osc.frequency.exponentialRampToValueAtTime(45, now + 0.06);
        gain.gain.setValueAtTime(0.3, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.07);
        osc.connect(gain);
        gain.connect(this.ctx.destination);
        osc.start(now);
        osc.stop(now + 0.08);
      } catch (e) {}
    }

    playDegaussChirp() {
      if (!this.soundEnabled) return;
      try {
        this.init();
        if (!this.ctx) return;
        const now = this.ctx.currentTime;

        // CRT channel switch frequency sweep
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
  // 2. RETRO TRINITRON TV & RM-NNTS REMOTE CONTROLLER
  // ==========================================================================
  const TV_CHANNELS = {
    1: {
      id: 1,
      ch: "CH 01",
      name: "Profiles & Quick Apps",
      desc: "Caps + C/B + 1..4 to raise profile window",
      src: "assets/media/screenrec-switch-app.mp4",
      badge: "REC 60FPS"
    },
    2: {
      id: 2,
      ch: "CH 02",
      name: "Copy-on-Select",
      desc: "Drag selection to copy text automatically",
      src: "assets/media/screenrec-select-copy.mp4",
      badge: "REC 60FPS"
    }
  };

  class RetroTvController {
    constructor() {
      this.isPowerOn = false;
      this.currentChannel = 1;
      this.isMuted = true;
      this.osdTimer = null;

      // DOM Elements
      this.video = document.getElementById("tv-video-player");
      this.screenGlass = document.getElementById("tv-screen-glass");
      this.standbyScreen = document.getElementById("tv-standby-screen");
      this.osdOverlay = document.getElementById("tv-osd-overlay");
      this.osdNum = document.getElementById("tv-osd-num");
      this.osdChannelLabel = document.getElementById("tv-osd-channel-label");
      this.osdSubLabel = document.getElementById("tv-osd-sub-label");
      this.powerLed = document.getElementById("tv-power-led");
      this.ledCaption = document.getElementById("tv-led-caption");
      this.footerMode = document.getElementById("tv-footer-mode");
      this.irEye = document.getElementById("tv-ir-eye");

      // Remote Elements
      this.remotePowerBtn = document.getElementById("remote-power-btn");
      this.remoteMuteBtn = document.getElementById("remote-mute-btn");
      this.remoteMuteIcon = document.getElementById("remote-mute-icon");
      this.remoteIrLed = document.getElementById("remote-ir-led");
      this.remoteTxLed = document.getElementById("remote-tx-led");
      this.remoteNum1 = document.getElementById("remote-num-1");
      this.remoteNum2 = document.getElementById("remote-num-2");
      this.remoteChUp = document.getElementById("remote-ch-up");
      this.remoteChDown = document.getElementById("remote-ch-down");

      // TV Hardware Controls
      this.hwPowerBtn = document.getElementById("tv-hardware-power-btn");
      this.hwCh1 = document.getElementById("tv-hw-ch-1");
      this.hwCh2 = document.getElementById("tv-hw-ch-2");

      // Section Tuner Controls
      this.secTuner1 = document.getElementById("section-tuner-1");
      this.secTuner2 = document.getElementById("section-tuner-2");
    }

    init() {
      this.bindEvents();
    }

    flashIr() {
      if (this.remoteIrLed) {
        this.remoteIrLed.classList.add("firing");
        setTimeout(() => this.remoteIrLed.classList.remove("firing"), 130);
      }
      if (this.remoteTxLed) {
        this.remoteTxLed.classList.add("active");
        setTimeout(() => this.remoteTxLed.classList.remove("active"), 130);
      }
      if (this.irEye) {
        this.irEye.classList.add("pulse");
        setTimeout(() => this.irEye.classList.remove("pulse"), 130);
      }
    }

    showOsd(chObj) {
      if (!this.osdOverlay || !chObj) return;
      if (this.osdNum) this.osdNum.textContent = chObj.ch || `CH 0${chObj.id}`;
      if (this.osdChannelLabel) this.osdChannelLabel.textContent = chObj.name;
      if (this.osdSubLabel) this.osdSubLabel.textContent = chObj.desc;

      this.osdOverlay.style.opacity = "1";
      this.osdOverlay.style.transform = "translateY(0)";
      if (this.osdTimer) clearTimeout(this.osdTimer);
      this.osdTimer = setTimeout(() => {
        this.osdOverlay.style.opacity = "0";
        this.osdOverlay.style.transform = "translateY(-4px)";
      }, 3400);
    }

    setPower(turnOn) {
      if (turnOn) {
        this.isPowerOn = true;
        this.flashIr();
        audio.playTvPowerOn();

        // Update TV Indicators
        if (this.powerLed) {
          this.powerLed.classList.remove("standby");
          this.powerLed.classList.add("active");
        }
        if (this.ledCaption) this.ledCaption.textContent = "ACTIVE";
        if (this.footerMode) this.footerMode.textContent = `TV: CH 0${this.currentChannel} (ACTIVE)`;

        // Update Remote Power Button
        if (this.remotePowerBtn) {
          this.remotePowerBtn.classList.remove("pulsing");
          this.remotePowerBtn.classList.add("active");
        }

        // Screen Turn On Animation
        if (this.screenGlass) {
          this.screenGlass.classList.remove("crt-screen-power-off");
          this.screenGlass.classList.add("crt-screen-power-on");
        }

        // Hide Standby Screen
        if (this.standbyScreen) {
          this.standbyScreen.style.display = "none";
        }

        // Play Video
        if (this.video) {
          const chObj = TV_CHANNELS[this.currentChannel];
          if (this.video.getAttribute("src") !== chObj.src) {
            this.video.src = chObj.src;
          }
          this.video.muted = this.isMuted;
          this.video.play().catch(() => {});
        }

        this.showOsd(TV_CHANNELS[this.currentChannel]);
      } else {
        this.isPowerOn = false;
        this.flashIr();
        audio.playTvPowerOff();

        if (this.osdOverlay) {
          this.osdOverlay.style.opacity = "0";
          this.osdOverlay.style.transform = "translateY(-4px)";
        }

        // Screen Turn Off Collapse Animation
        if (this.screenGlass) {
          this.screenGlass.classList.remove("crt-screen-power-on");
          this.screenGlass.classList.add("crt-screen-power-off");
        }

        setTimeout(() => {
          if (this.video) {
            this.video.pause();
          }
          if (this.standbyScreen) {
            this.standbyScreen.style.display = "flex";
          }
          if (this.screenGlass) {
            this.screenGlass.classList.remove("crt-screen-power-off");
          }
          if (this.powerLed) {
            this.powerLed.classList.remove("active");
            this.powerLed.classList.add("standby");
          }
          if (this.ledCaption) this.ledCaption.textContent = "STANDBY";
          if (this.footerMode) this.footerMode.textContent = "TV: STANDBY";
          if (this.remotePowerBtn) {
            this.remotePowerBtn.classList.remove("active");
            this.remotePowerBtn.classList.add("pulsing");
          }
        }, 250);
      }
    }

    togglePower() {
      this.setPower(!this.isPowerOn);
    }

    tuneChannel(chId) {
      this.flashIr();
      audio.playRelayClick();
      audio.playDegaussChirp();

      if (!this.isPowerOn) {
        this.setPower(true);
      }

      this.currentChannel = chId;
      const chObj = TV_CHANNELS[chId];
      if (!chObj) return;

      // CRT Channel Switch Flicker
      if (this.screenGlass) {
        this.screenGlass.style.filter = "brightness(1.5) contrast(1.2)";
        setTimeout(() => {
          this.screenGlass.style.filter = "none";
        }, 70);
      }

      // Switch Video
      if (this.video) {
        if (this.video.getAttribute("src") !== chObj.src) {
          this.video.src = chObj.src;
        }
        this.video.play().catch(() => {});
      }

      // Update Remote Channel Buttons
      if (this.remoteNum1) {
        this.remoteNum1.classList.toggle("active", chId === 1);
      }
      if (this.remoteNum2) {
        this.remoteNum2.classList.toggle("active", chId === 2);
      }

      // Update TV Hardware Channel Buttons
      if (this.hwCh1) {
        this.hwCh1.classList.toggle("active", chId === 1);
      }
      if (this.hwCh2) {
        this.hwCh2.classList.toggle("active", chId === 2);
      }

      // Update Section Tuner Buttons
      if (this.secTuner1) {
        this.secTuner1.classList.toggle("active", chId === 1);
      }
      if (this.secTuner2) {
        this.secTuner2.classList.toggle("active", chId === 2);
      }

      if (this.footerMode) {
        this.footerMode.textContent = `TV: CH 0${chId} (ACTIVE)`;
      }

      this.showOsd(chObj);
    }

    nextChannel() {
      this.tuneChannel(this.currentChannel === 1 ? 2 : 1);
    }

    toggleMute() {
      this.flashIr();
      audio.playRelayClick();
      this.isMuted = !this.isMuted;
      if (this.video) {
        this.video.muted = this.isMuted;
      }
      if (this.remoteMuteIcon) {
        this.remoteMuteIcon.textContent = this.isMuted ? "🔇" : "🔊";
      }
    }

    bindEvents() {
      // Remote Power Button
      if (this.remotePowerBtn) {
        this.remotePowerBtn.addEventListener("click", () => this.togglePower());
      }

      // Remote Mute Button
      if (this.remoteMuteBtn) {
        this.remoteMuteBtn.addEventListener("click", () => this.toggleMute());
      }

      // Remote Channel Buttons
      if (this.remoteNum1) {
        this.remoteNum1.addEventListener("click", () => this.tuneChannel(1));
      }
      if (this.remoteNum2) {
        this.remoteNum2.addEventListener("click", () => this.tuneChannel(2));
      }
      if (this.remoteChUp) {
        this.remoteChUp.addEventListener("click", () => this.nextChannel());
      }
      if (this.remoteChDown) {
        this.remoteChDown.addEventListener("click", () => this.nextChannel());
      }

      // TV Hardware Power Button
      if (this.hwPowerBtn) {
        this.hwPowerBtn.addEventListener("click", () => this.togglePower());
      }

      // TV Hardware Channel Buttons
      if (this.hwCh1) {
        this.hwCh1.addEventListener("click", () => this.tuneChannel(1));
      }
      if (this.hwCh2) {
        this.hwCh2.addEventListener("click", () => this.tuneChannel(2));
      }

      // Standby Screen Click -> Turn TV ON
      if (this.standbyScreen) {
        this.standbyScreen.addEventListener("click", () => this.setPower(true));
      }

      // Video Screen Click -> Toggle Channel
      if (this.video) {
        this.video.addEventListener("click", () => this.nextChannel());
      }

      // Section Tuner Buttons
      if (this.secTuner1) {
        this.secTuner1.addEventListener("click", () => {
          this.tuneChannel(1);
          const st = document.getElementById("hero-tv-station");
          if (st) st.scrollIntoView({ behavior: "smooth", block: "center" });
        });
      }
      if (this.secTuner2) {
        this.secTuner2.addEventListener("click", () => {
          this.tuneChannel(2);
          const st = document.getElementById("hero-tv-station");
          if (st) st.scrollIntoView({ behavior: "smooth", block: "center" });
        });
      }
    }
  }

  // ==========================================================================
  // 3. INTERACTIVE BENTO LAB (SECTION 2: CORE SUPERPOWERS)
  // ==========================================================================
  function setupBentoLabInteractions() {
    // A. Radial Mouse Glow on Bento Cards
    const bentoCards = document.querySelectorAll("[data-bento-card]");
    bentoCards.forEach((card) => {
      card.addEventListener("mousemove", (e) => {
        const rect = card.getBoundingClientRect();
        card.style.setProperty("--mouse-x", `${e.clientX - rect.left}px`);
        card.style.setProperty("--mouse-y", `${e.clientY - rect.top}px`);
      });
    });

    // B. Card 1: Browser Profile Switcher
    const profileBtns = document.querySelectorAll(".bento-profile-btn");
    const activeProfileKey = document.getElementById("active-profile-key");
    const simUrl = document.getElementById("sim-profile-url");
    const simAvatar = document.getElementById("sim-profile-avatar");
    const simName = document.getElementById("sim-profile-name");
    const simTag = document.getElementById("sim-page-tag");
    const simTitle = document.getElementById("sim-page-title");
    const simWindow = document.getElementById("sim-metric-window");
    const simViewport = document.getElementById("sim-profile-viewport");
    const appleHud = document.getElementById("apple-hud-overlay");
    const hudAvatar = document.getElementById("hud-profile-avatar");
    const hudName = document.getElementById("hud-profile-title");
    const hudKey = document.getElementById("hud-profile-key");
    let hudTimer = null;

    function flashAppleHud(profileId, name, img) {
      if (!appleHud) return;
      if (hudAvatar && img) hudAvatar.src = img;
      if (hudName) hudName.textContent = name;
      if (hudKey) hudKey.textContent = profileId;

      appleHud.classList.remove("is-visible");
      void appleHud.offsetWidth;
      appleHud.classList.add("is-visible");

      if (hudTimer) clearTimeout(hudTimer);
      hudTimer = setTimeout(() => {
        appleHud.classList.remove("is-visible");
      }, 1200);
    }

    const keychordCaps = document.getElementById("keychord-cap-caps");
    const keychordC = document.getElementById("keychord-cap-c");
    const keychordDigit = document.getElementById("keychord-cap-digit");
    const keychordDigitLabel = document.getElementById("keychord-digit-label");

    function animateKeychordPress() {
      const caps = [keychordCaps, keychordC, keychordDigit].filter(Boolean);
      caps.forEach((cap) => {
        cap.classList.add("is-pressed");
        setTimeout(() => cap.classList.remove("is-pressed"), 140);
      });
    }

    if (keychordDigit) {
      keychordDigit.addEventListener("click", () => {
        const activeIdx = Array.from(profileBtns).findIndex((b) => b.classList.contains("active"));
        const nextIdx = (activeIdx + 1) % profileBtns.length;
        if (profileBtns[nextIdx]) profileBtns[nextIdx].click();
      });
    }

    if (keychordC) {
      keychordC.addEventListener("click", () => {
        audio.playRelayClick();
        keychordC.classList.add("is-pressed");
        setTimeout(() => keychordC.classList.remove("is-pressed"), 140);
      });
    }

    if (keychordCaps) {
      keychordCaps.addEventListener("click", () => {
        audio.playRelayClick();
        keychordCaps.classList.add("is-pressed");
        setTimeout(() => keychordCaps.classList.remove("is-pressed"), 140);
      });
    }

    profileBtns.forEach((btn) => {
      btn.addEventListener("click", () => {
        const profileId = btn.dataset.profile;
        const name = btn.dataset.name;
        const url = btn.dataset.url;
        const img = btn.dataset.img;

        profileBtns.forEach((b) => b.classList.remove("active"));
        btn.classList.add("active");

        if (activeProfileKey) activeProfileKey.textContent = profileId;
        if (keychordDigitLabel) keychordDigitLabel.textContent = profileId;
        if (simUrl) simUrl.textContent = url;
        if (simAvatar) simAvatar.src = img;
        if (simName) simName.textContent = name;
        if (simTag) simTag.textContent = `PROFILE 0${profileId} ACTIVE`;
        if (simTitle) simTitle.innerHTML = `${name} Workspace &bull; Direct Switch`;
        if (simWindow) simWindow.textContent = `Chrome: ${name} (ID #${profileId})`;

        if (simViewport) {
          simViewport.classList.remove("flash-pulse");
          void simViewport.offsetWidth;
          simViewport.classList.add("flash-pulse");
        }

        animateKeychordPress();
        flashAppleHud(profileId, name, img);
        audio.playRelayClick();
      });
    });

    // C. Card 2: Keymaster 3D Quick Apps Keychord & First-Letter Cycler
    const quickCapCaps = document.getElementById("quickapp-cap-caps");
    const quickCapLetter = document.getElementById("quickapp-cap-letter");
    const quickLetterLabel = document.getElementById("quickapp-letter-label");
    const quickLetterSub = document.getElementById("quickapp-letter-sub");
    const activeAppBadge = document.getElementById("active-app-letter");
    const cycleIndicator = document.getElementById("bento-cycle-indicator");
    const letterBtns = document.querySelectorAll(".bento-letter-btn");
    const app1 = document.getElementById("cycler-app-1");
    const app2 = document.getElementById("cycler-app-2");
    const icon1 = document.getElementById("cycler-icon-1");
    const name1 = document.getElementById("cycler-name-1");
    const slot1 = document.getElementById("cycler-slot-1");
    const check1 = document.getElementById("cycler-check-1");
    const icon2 = document.getElementById("cycler-icon-2");
    const name2 = document.getElementById("cycler-name-2");
    const slot2 = document.getElementById("cycler-slot-2");
    const check2 = document.getElementById("cycler-check-2");

    let currentLetter = "T";
    let currentMode = "cycle";
    let currentAppSlot = 1;

    function animateQuickChordPress() {
      const caps = [quickCapCaps, quickCapLetter].filter(Boolean);
      caps.forEach((cap) => {
        cap.classList.add("is-pressed");
        setTimeout(() => cap.classList.remove("is-pressed"), 140);
      });
    }

    function triggerCycleStep() {
      if (currentMode !== "cycle") {
        animateQuickChordPress();
        audio.playRelayClick();
        return;
      }

      currentAppSlot = currentAppSlot === 1 ? 2 : 1;
      animateQuickChordPress();

      if (currentAppSlot === 1) {
        if (app1) {
          app1.classList.add("active");
          if (check1) check1.textContent = "✓";
          if (slot1) slot1.innerHTML = "Slot 1/2 &bull; Active";
        }
        if (app2) {
          app2.classList.remove("active");
          if (check2) check2.textContent = "";
          if (slot2) slot2.innerHTML = "Slot 2/2 &bull; Next";
        }
        if (cycleIndicator) cycleIndicator.textContent = "1 / 2 ↻ CYCLE";
      } else {
        if (app1) {
          app1.classList.remove("active");
          if (check1) check1.textContent = "";
          if (slot1) slot1.innerHTML = "Slot 1/2 &bull; Next";
        }
        if (app2) {
          app2.classList.add("active");
          if (check2) check2.textContent = "✓";
          if (slot2) slot2.innerHTML = "Slot 2/2 &bull; Active";
        }
        if (cycleIndicator) cycleIndicator.textContent = "2 / 2 ↻ CYCLE";
      }
      audio.playRelayClick();
    }

    function selectLetter(btn) {
      letterBtns.forEach((b) => b.classList.remove("active"));
      btn.classList.add("active");

      const letter = btn.dataset.letter;
      const a1 = btn.dataset.app1;
      const i1 = btn.dataset.icon1;
      const a2 = btn.dataset.app2;
      const i2 = btn.dataset.icon2;
      const mode = btn.dataset.mode;

      currentLetter = letter;
      currentMode = mode;
      currentAppSlot = 1;

      if (quickLetterLabel) quickLetterLabel.textContent = letter;
      if (activeAppBadge) activeAppBadge.textContent = letter;

      if (mode === "cycle") {
        if (quickLetterSub) quickLetterSub.textContent = "CYCLE ↻";
        if (cycleIndicator) cycleIndicator.textContent = "1 / 2 ↻ CYCLE";

        if (app1) {
          app1.style.display = "flex";
          app1.classList.add("active");
          if (name1) name1.textContent = a1;
          if (icon1) icon1.src = i1;
          if (slot1) slot1.innerHTML = "Slot 1/2 &bull; Active";
          if (check1) check1.textContent = "✓";
        }
        if (app2) {
          app2.style.display = "flex";
          app2.classList.remove("active");
          if (name2) name2.textContent = a2;
          if (icon2) icon2.src = i2;
          if (slot2) slot2.innerHTML = "Slot 2/2 &bull; Next";
          if (check2) check2.textContent = "";
        }
      } else {
        if (quickLetterSub) quickLetterSub.textContent = "DIRECT";
        if (cycleIndicator) cycleIndicator.textContent = "DIRECT FOCUS";

        if (app1) {
          app1.style.display = "flex";
          app1.classList.add("active");
          if (name1) name1.textContent = a1;
          if (icon1) icon1.src = i1;
          if (slot1) slot1.innerHTML = "Direct Jump &bull; Active";
          if (check1) check1.textContent = "✓";
        }
        if (app2) {
          app2.style.display = "none";
        }
      }

      animateQuickChordPress();
      audio.playRelayClick();
    }

    letterBtns.forEach((btn) => {
      btn.addEventListener("click", () => selectLetter(btn));
    });

    if (quickCapLetter) {
      quickCapLetter.addEventListener("click", triggerCycleStep);
    }

    if (quickCapCaps) {
      quickCapCaps.addEventListener("click", () => {
        audio.playRelayClick();
        quickCapCaps.classList.add("is-pressed");
        setTimeout(() => quickCapCaps.classList.remove("is-pressed"), 140);
      });
    }

    window.addEventListener("keydown", (e) => {
      if (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA") return;
      if (e.metaKey || e.ctrlKey || e.altKey) return;
      const k = e.key.toUpperCase();
      const targetBtn = Array.from(letterBtns).find((b) => b.dataset.letter === k);
      if (targetBtn) {
        if (currentLetter === k) {
          triggerCycleStep();
        } else {
          selectLetter(targetBtn);
        }
      }
    });

    // D. Card 3: Linux-Style Copy-on-Select Sandbox & Tactile Pasteboard
    const selectZone = document.getElementById("live-select-zone");
    const sandboxToast = document.getElementById("sandbox-live-toast");
    const sandboxToastText = document.getElementById("sandbox-toast-text");
    const cursorToast = document.getElementById("live-cursor-toast");
    const counterNum = document.getElementById("copy-saved-count");
    const counterBadge = document.getElementById("copy-saved-counter-badge");
    const pasteboardBox = document.getElementById("live-pasteboard-box");
    const pasteboardVal = document.getElementById("pasteboard-val");
    const pasteboardStatus = document.getElementById("pasteboard-status");
    const copyPills = document.querySelectorAll(".bento-copy-pill");

    let copyCount = 0;
    let toastTimer = null;

    function triggerCopyFeedback(copiedText) {
      copyCount += 1;
      if (counterNum) counterNum.textContent = copyCount.toString();
      if (counterBadge) {
        counterBadge.classList.remove("pulse");
        void counterBadge.offsetWidth;
        counterBadge.classList.add("pulse");
      }

      if (pasteboardVal) {
        pasteboardVal.textContent = copiedText;
      }

      if (pasteboardBox) {
        pasteboardBox.classList.add("is-updated");
        setTimeout(() => pasteboardBox.classList.remove("is-updated"), 350);
      }

      if (pasteboardStatus) {
        const ms = Math.floor(Math.random() * 4 + 2);
        pasteboardStatus.textContent = `● SYNCED (${ms}ms)`;
        setTimeout(() => {
          pasteboardStatus.textContent = "● READY";
        }, 1500);
      }

      audio.playCopyChime();

      if (sandboxToast) {
        if (sandboxToastText) {
          sandboxToastText.textContent = copiedText.length > 24 
            ? `Copied: "${copiedText.slice(0, 22)}..."` 
            : `Copied: "${copiedText}"`;
        }
        sandboxToast.classList.add("is-visible");
        if (toastTimer) clearTimeout(toastTimer);
        toastTimer = setTimeout(() => {
          sandboxToast.classList.remove("is-visible");
        }, 1200);
      }
    }

    if (copyPills.length > 0) {
      copyPills.forEach((pill) => {
        pill.addEventListener("click", () => {
          copyPills.forEach((p) => p.classList.remove("active"));
          pill.classList.add("active");
          const clipText = pill.dataset.clip || "brew install --cask nnts";
          if (selectZone) {
            selectZone.innerHTML = `
              <div class="editor-line">
                <span class="code-comment">// Highlight any part of this line:</span>
              </div>
              <div class="editor-line">
                <span class="code-kw">${clipText}</span> <span class="code-comment">/* auto-copies */</span>
              </div>
            `;
          }
          triggerCopyFeedback(clipText);
        });
      });
    }

    if (selectZone) {
      selectZone.addEventListener("mouseup", (e) => {
        const selection = window.getSelection().toString().trim();
        if (selection.length >= 2) {
          triggerCopyFeedback(selection);

          if (cursorToast) {
            const toastWidth = 140;
            const toastHeight = 36;
            const safeX = Math.min(e.clientX, window.innerWidth - toastWidth - 16);
            const safeY = Math.min(e.clientY, window.innerHeight - toastHeight - 16);
            cursorToast.style.left = `${safeX}px`;
            cursorToast.style.top = `${safeY}px`;
            cursorToast.classList.add("is-visible");
            setTimeout(() => {
              cursorToast.classList.remove("is-visible");
            }, 1100);
          }
        }
      });
    }
  }

  // ==========================================================================
  // 4. 1-CLICK BREW INSTALL COPY
  // ==========================================================================
  function setupBrewInstallCopy() {
    const brewPill = document.getElementById("brew-copy-pill");
    const brewBtn = document.getElementById("brew-copy-btn");
    const stripPill = document.getElementById("strip-brew-pill");
    const stripBtn = document.getElementById("strip-brew-btn");

    function copyBrew(el, btnEl) {
      const cmd = "brew install --cask nnts";
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
  // 5. GLOBAL KEYBOARD HOOKS
  // ==========================================================================
  function setupKeyboardListener(tv) {
    window.addEventListener("keydown", (e) => {
      // Avoid intercepting when user types in inputs
      if (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA") return;

      const key = e.key.toLowerCase();
      if (key === "p" || key === " ") {
        if (key === " ") e.preventDefault();
        tv.togglePower();
      } else if (key === "1") {
        tv.tuneChannel(1);
      } else if (key === "2") {
        tv.tuneChannel(2);
      } else if (key === "m") {
        tv.toggleMute();
      } else if (key === "arrowup" || key === "arrowdown") {
        e.preventDefault();
        tv.nextChannel();
      }
    });
  }

  // ==========================================================================
  // 6. INITIALIZATION & BINDINGS
  // ==========================================================================
  document.addEventListener("DOMContentLoaded", () => {
    // 1. Audio Button Toggle
    const audioBtn = document.getElementById("audio-toggle-btn");
    const updateAudioButtonUI = (enabled) => {
      if (!audioBtn) return;
      if (enabled) {
        audioBtn.classList.remove("is-muted");
        audioBtn.classList.add("is-active");
        audioBtn.setAttribute("title", "Tactile Relay Audio: ON (Click to mute)");
        audioBtn.setAttribute("aria-label", "Mute Audio");
      } else {
        audioBtn.classList.add("is-muted");
        audioBtn.classList.remove("is-active");
        audioBtn.setAttribute("title", "Tactile Relay Audio: OFF (Click to unmute)");
        audioBtn.setAttribute("aria-label", "Unmute Audio");
      }
    };

    if (audioBtn) {
      updateAudioButtonUI(audio.soundEnabled);
      audioBtn.addEventListener("click", () => {
        const state = audio.toggle();
        updateAudioButtonUI(state);
        if (state) audio.playRelayClick();
      });
    }

    // 2. TV & Remote Controller
    const tv = new RetroTvController();
    tv.init();

    // Check URL parameters for power=1 or channel=2
    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.get("channel") === "2") {
      tv.tuneChannel(2);
    }
    if (urlParams.get("power") === "1" || urlParams.get("on") === "1") {
      tv.setPower(true);
    }

    // 3. Simulators & Proofs
    setupBentoLabInteractions();
    setupBrewInstallCopy();
    setupKeyboardListener(tv);
  });
})();
