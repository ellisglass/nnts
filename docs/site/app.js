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

      // Section 2 Pain Cards -> Tune TV & Scroll Up
      const rackItems = document.querySelectorAll(".rack-item");
      rackItems.forEach((item) => {
        item.addEventListener("click", () => {
          this.tuneChannel(1);
          const st = document.getElementById("hero-tv-station");
          if (st) st.scrollIntoView({ behavior: "smooth", block: "center" });
        });
      });
    }
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
  // 4. 1-CLICK BREW INSTALL COPY
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
    setupCopyOnSelectSimulator();
    setupBrewInstallCopy();
    setupKeyboardListener(tv);
  });
})();
