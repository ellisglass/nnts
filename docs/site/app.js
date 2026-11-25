(function () {
  "use strict";

  class TactileAudioEngine {
    constructor() {
      this.ctx = null;
      this.soundEnabled = localStorage.getItem("nnts_sound_enabled") !== "false";
    }

    init() {
      if (!this.ctx) {
        const AudioContext = window.AudioContext || window.webkitAudioContext;
        if (AudioContext) this.ctx = new AudioContext();
      }
      if (this.ctx && this.ctx.state === "suspended") {
        this.ctx.resume();
      }
    }

    toggle() {
      this.soundEnabled = !this.soundEnabled;
      localStorage.setItem("nnts_sound_enabled", String(this.soundEnabled));
      return this.soundEnabled;
    }

    playRelayClick() {
      if (!this.soundEnabled) return;
      try {
        this.init();
        if (!this.ctx) return;
        const now = this.ctx.currentTime;
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = "sine";
        osc.frequency.setValueAtTime(580, now);
        osc.frequency.exponentialRampToValueAtTime(80, now + 0.04);
        gain.gain.setValueAtTime(0.18, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.045);
        osc.connect(gain);
        gain.connect(this.ctx.destination);
        osc.start(now);
        osc.stop(now + 0.05);
      } catch (_) {}
    }

    playDegaussChirp() {
      if (!this.soundEnabled) return;
      try {
        this.init();
        if (!this.ctx) return;
        const now = this.ctx.currentTime;
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = "sawtooth";
        osc.frequency.setValueAtTime(220, now);
        osc.frequency.exponentialRampToValueAtTime(1180, now + 0.06);
        gain.gain.setValueAtTime(0.06, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.07);
        osc.connect(gain);
        gain.connect(this.ctx.destination);
        osc.start(now);
        osc.stop(now + 0.08);
      } catch (_) {}
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
          gain.gain.setValueAtTime(0.1, now + idx * 0.03);
          gain.gain.exponentialRampToValueAtTime(0.001, now + idx * 0.03 + 0.08);
          osc.connect(gain);
          gain.connect(this.ctx.destination);
          osc.start(now + idx * 0.03);
          osc.stop(now + idx * 0.03 + 0.09);
        });
      } catch (_) {}
    }
  }

  const audio = new TactileAudioEngine();

  const CHANNELS = {
    1: {
      id: 1,
      ch: "CH 01",
      name: "Browser Profiles (1-8)",
      desc: "caps lock + C/B + 1..8 via kAXMenuBar",
      src: "assets/media/channel_01_profiles.mp4"
    },
    2: {
      id: 2,
      ch: "CH 02",
      name: "Quick Apps Deck",
      desc: "caps lock + [a-z] with 1/N repeat cycle",
      src: "assets/media/channel_02_quickapps.mp4"
    },
    3: {
      id: 3,
      ch: "CH 03",
      name: "Copy-on-Select CRT",
      desc: "Drag selection copies automatically",
      src: "assets/media/channel_03_copy_select.mp4"
    },
    4: {
      id: 4,
      ch: "CH 04",
      name: "Pro Channel // Scrambled",
      desc: "8 profiles, A-Z apps, In Terminals, auto Finder Tidy",
      src: "assets/media/channel_04_pro_scrambled.mp4"
    }
  };

  function setupTvController() {
    const video = document.getElementById("tv-video-player");
    const standby = document.getElementById("tv-standby-screen");
    const osd = document.getElementById("tv-osd-overlay");
    const osdNum = document.getElementById("tv-osd-num");
    const osdLabel = document.getElementById("tv-osd-channel-label");
    const osdSub = document.getElementById("tv-osd-sub-label");
    const powerLed = document.getElementById("tv-power-led");
    const irLed = document.getElementById("remote-ir-led");
    const txLed = document.getElementById("remote-tx-led");
    const tvEye = document.getElementById("tv-ir-eye");

    const powerBtns = [
      document.getElementById("remote-power-btn"),
      document.getElementById("tv-hardware-power-btn")
    ].filter(Boolean);
    const wakeBtn = document.getElementById("standby-wake-btn");
    const muteBtn = document.getElementById("remote-mute-btn");
    const chUp = document.getElementById("remote-ch-up");
    const chDown = document.getElementById("remote-ch-down");

    const remoteNumBtns = [1, 2, 3, 4].map((n) => document.getElementById(`remote-num-${n}`));
    const tvTabBtns = Array.from(document.querySelectorAll("[data-tv-channel]"));

    let isPowerOn = true;
    let currentChannel = 1;
    let isMuted = true;
    let osdTimer = null;

    function pulseIr() {
      [irLed, txLed, tvEye].forEach((el) => {
        if (!el) return;
        const cls = el === irLed ? "firing" : el === txLed ? "active" : "pulse";
        el.classList.add(cls);
        setTimeout(() => el.classList.remove(cls), 130);
      });
    }

    function showOsd(chObj) {
      if (!osd || !chObj) return;
      osdNum.textContent = chObj.ch;
      osdLabel.textContent = chObj.name;
      osdSub.textContent = chObj.desc;
      osd.style.opacity = "1";
      osd.style.transform = "translateY(0)";
      if (osdTimer) clearTimeout(osdTimer);
      osdTimer = setTimeout(() => {
        osd.style.opacity = "0";
        osd.style.transform = "translateY(-4px)";
      }, 3000);
    }

    function setPower(turnOn) {
      isPowerOn = turnOn;
      pulseIr();
      audio.playRelayClick();
      const rp = document.getElementById("remote-power-btn");
      if (turnOn) {
        if (powerLed) powerLed.classList.add("active");
        if (rp) rp.classList.add("active");
        if (standby) standby.style.display = "none";
        if (video) {
          video.muted = isMuted;
          video.play().catch(() => {});
        }
        showOsd(CHANNELS[currentChannel]);
      } else {
        if (powerLed) powerLed.classList.remove("active");
        if (rp) rp.classList.remove("active");
        if (video) video.pause();
        if (standby) standby.style.display = "flex";
        if (osd) osd.style.opacity = "0";
      }
    }

    function tune(chId) {
      const chObj = CHANNELS[chId];
      if (!chObj) return;
      currentChannel = chId;
      pulseIr();
      audio.playRelayClick();
      audio.playDegaussChirp();
      if (!isPowerOn) setPower(true);

      if (video && video.getAttribute("src") !== chObj.src) {
        video.src = chObj.src;
        video.play().catch(() => {});
      }

      remoteNumBtns.forEach((btn, idx) => {
        if (btn) btn.classList.toggle("active", idx + 1 === chId);
      });
      tvTabBtns.forEach((btn) => {
        const active = Number(btn.dataset.tvChannel) === chId;
        btn.classList.toggle("active", active);
        btn.setAttribute("aria-selected", String(active));
      });
      showOsd(chObj);
    }

    powerBtns.forEach((btn) => btn.addEventListener("click", () => setPower(!isPowerOn)));
    if (wakeBtn) wakeBtn.addEventListener("click", () => setPower(true));
    if (muteBtn) {
      muteBtn.addEventListener("click", () => {
        pulseIr();
        audio.playRelayClick();
        isMuted = !isMuted;
        if (video) video.muted = isMuted;
      });
    }

    remoteNumBtns.forEach((btn, idx) => {
      if (btn) btn.addEventListener("click", () => tune(idx + 1));
    });
    tvTabBtns.forEach((btn) => {
      btn.addEventListener("click", () => tune(Number(btn.dataset.tvChannel)));
    });

    if (chUp) chUp.addEventListener("click", () => tune(currentChannel === 4 ? 1 : currentChannel + 1));
    if (chDown) chDown.addEventListener("click", () => tune(currentChannel === 1 ? 4 : currentChannel - 1));

    showOsd(CHANNELS[1]);

    window.addEventListener("keydown", (e) => {
      if (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA") return;
      const k = e.key.toLowerCase();
      if (k === "p") setPower(!isPowerOn);
      else if (k === "1" || k === "2" || k === "3" || k === "4") tune(Number(k));
    });
  }

  function setupWorkbench() {
    const tabBtns = Array.from(document.querySelectorAll("[data-wb-tab]"));
    const panels = {
      profiles: document.getElementById("wb-panel-profiles"),
      apps: document.getElementById("wb-panel-apps"),
      copy: document.getElementById("wb-panel-copy")
    };
    const hudImg = document.getElementById("wb-hud-preview-img");
    const modeChips = Array.from(document.querySelectorAll("[data-screen-src]"));

    const defaultScreenForTab = {
      profiles: "assets/media/hud_profiles_v1.png",
      apps: "assets/media/hud_quickapps_v1.png",
      copy: "assets/media/hud_copy_v1.png"
    };

    function setDeviceScreen(src) {
      if (hudImg) hudImg.src = src;
      modeChips.forEach((chip) => {
        chip.classList.toggle("active", chip.dataset.screenSrc === src);
      });
    }

    tabBtns.forEach((btn) => {
      btn.addEventListener("click", () => {
        const key = btn.dataset.wbTab;
        tabBtns.forEach((b) => {
          const isMatch = b.dataset.wbTab === key;
          b.classList.toggle("active", isMatch);
          b.setAttribute("aria-selected", String(isMatch));
        });
        Object.entries(panels).forEach(([k, panel]) => {
          if (panel) panel.classList.toggle("active", k === key);
        });
        if (defaultScreenForTab[key]) setDeviceScreen(defaultScreenForTab[key]);
        audio.playRelayClick();
      });
    });

    modeChips.forEach((chip) => {
      chip.addEventListener("click", () => {
        setDeviceScreen(chip.dataset.screenSrc);
        audio.playRelayClick();
      });
    });

    // Profiles Tester
    const slotChips = Array.from(document.querySelectorAll(".slot-chip"));
    const profChord = document.getElementById("wb-prof-chord");
    const profLatency = document.getElementById("wb-prof-latency");
    slotChips.forEach((chip) => {
      chip.addEventListener("click", () => {
        slotChips.forEach((c) => c.classList.remove("active"));
        chip.classList.add("active");
        if (profChord) profChord.textContent = `caps lock + C + ${chip.dataset.slot}`;
        if (profLatency) {
          const tier = chip.dataset.tier === "pro" ? "Pro Slot" : "Free Slot";
          profLatency.textContent = `${chip.dataset.ms} (${tier})`;
        }
        setDeviceScreen(chip.dataset.tier === "pro" ? "assets/media/hud_profiles_v1.png" : "assets/media/hud_profiles_v1.png");
        audio.playRelayClick();
      });
    });

    // Quick Apps Cycler
    const letterKeys = Array.from(document.querySelectorAll(".letter-key"));
    const appChord = document.getElementById("wb-app-chord");
    const appTarget = document.getElementById("wb-app-target");
    const tapAgainBtn = document.getElementById("wb-tap-again-btn");
    let currentApp = { letter: "A", a1: "Antigravity", a2: "Antigravity IDE", step: 1 };

    function renderAppState() {
      if (appChord) appChord.textContent = `caps lock + ${currentApp.letter}`;
      if (appTarget) {
        if (currentApp.a2) {
          const activeName = currentApp.step === 1 ? currentApp.a1 : currentApp.a2;
          appTarget.textContent = `${activeName} (${currentApp.step}/2 cycle)`;
        } else {
          appTarget.textContent = `${currentApp.a1} (Direct launch)`;
        }
      }
    }

    letterKeys.forEach((btn) => {
      btn.addEventListener("click", () => {
        letterKeys.forEach((b) => b.classList.remove("active"));
        btn.classList.add("active");
        currentApp = {
          letter: btn.dataset.letter,
          a1: btn.dataset.a1,
          a2: btn.dataset.a2,
          step: 1
        };
        renderAppState();
        audio.playRelayClick();
      });
    });

    if (tapAgainBtn) {
      tapAgainBtn.addEventListener("click", () => {
        if (currentApp.a2) {
          currentApp.step = currentApp.step === 1 ? 2 : 1;
        }
        renderAppState();
        audio.playRelayClick();
      });
    }

    // Copy-on-Select Sandbox
    const selectZone = document.getElementById("live-select-zone");
    const pasteVal = document.getElementById("pasteboard-val");
    const pasteStatus = document.getElementById("pasteboard-status");
    const savedCounter = document.getElementById("copy-saved-count");
    const cursorToast = document.getElementById("live-cursor-toast");
    let copyTotal = 0;

    if (selectZone) {
      selectZone.addEventListener("mouseup", (e) => {
        const sel = window.getSelection().toString().trim();
        if (sel.length < 2) return;
        copyTotal += 1;
        if (savedCounter) savedCounter.textContent = `${copyTotal} ${copyTotal === 1 ? "copy" : "copies"} in demo`;
        if (pasteVal) pasteVal.textContent = sel;
        if (pasteStatus) pasteStatus.textContent = "COPIED";
        audio.playCopyChime();

        if (cursorToast) {
          cursorToast.style.left = `${Math.min(e.clientX + 10, window.innerWidth - 110)}px`;
          cursorToast.style.top = `${Math.min(e.clientY - 34, window.innerHeight - 44)}px`;
          cursorToast.classList.add("is-visible");
          setTimeout(() => cursorToast.classList.remove("is-visible"), 1000);
        }
      });
    }
  }

  function setupBrewCopy() {
    const brewPill = document.getElementById("brew-copy-pill");
    const label = document.getElementById("brew-copy-label");
    if (!brewPill) return;

    brewPill.addEventListener("click", () => {
      const cmd = "brew install ellisglass/tap/nnts";
      navigator.clipboard.writeText(cmd).then(() => {
        audio.playCopyChime();
        if (label) {
          label.textContent = "Copied";
          setTimeout(() => { label.textContent = "Copy"; }, 1800);
        }
      }).catch(() => {});
    });
  }

  function setupAudioToggle() {
    const btn = document.getElementById("audio-toggle-btn");
    if (!btn) return;
    const sync = (enabled) => {
      btn.classList.toggle("is-active", enabled);
      btn.classList.toggle("is-muted", !enabled);
      btn.title = enabled ? "Tactile Synth Audio: On" : "Tactile Synth Audio: Off";
    };
    sync(audio.soundEnabled);
    btn.addEventListener("click", () => {
      const state = audio.toggle();
      sync(state);
      if (state) audio.playRelayClick();
    });
  }

  function init() {
    setupAudioToggle();
    setupTvController();
    setupWorkbench();
    setupBrewCopy();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
