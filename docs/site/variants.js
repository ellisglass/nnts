/**
 * NNTS — Interactive UI & Verification Engine (variants.js)
 * Implements:
 * 1. 60fps Authentic macOS Video Demonstrations & Scrubbing
 * 2. Reactive Mascot Companion (real-time HUD toasts & squish physics)
 * 3. Linux Copy-on-Select Live Toast Engine
 * 4. Authentic 60fps Screen Recording Proofs Modal
 * 5. 1-Click Brew Install Copy Strips
 */

(function () {
  "use strict";

  // --- Audio Synthesis for Tactile Feedback (Unified with Global Sound State) ---
  let audioCtx = null;
  function getAudioContext() {
    if (!audioCtx) {
      const AudioContext = window.AudioContext || window.webkitAudioContext;
      if (AudioContext) audioCtx = new AudioContext();
    }
    if (audioCtx && audioCtx.state === "suspended") {
      audioCtx.resume();
    }
    return audioCtx;
  }

  function playTactileClick(type = "soft") {
    // Respect global sound toggle state
    if (window.nntsSound && !window.nntsSound.soundOn) return;

    try {
      const ctx = getAudioContext();
      if (!ctx) return;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.connect(gain);
      gain.connect(ctx.destination);

      const now = ctx.currentTime;
      if (type === "copy") {
        osc.type = "sine";
        osc.frequency.setValueAtTime(880, now);
        osc.frequency.exponentialRampToValueAtTime(1320, now + 0.04);
        gain.gain.setValueAtTime(0.08, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.06);
        osc.start(now);
        osc.stop(now + 0.06);
      } else if (type === "popover") {
        osc.type = "triangle";
        osc.frequency.setValueAtTime(440, now);
        osc.frequency.exponentialRampToValueAtTime(660, now + 0.05);
        gain.gain.setValueAtTime(0.06, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.05);
        osc.start(now);
        osc.stop(now + 0.05);
      } else {
        osc.type = "sine";
        osc.frequency.setValueAtTime(320, now);
        osc.frequency.exponentialRampToValueAtTime(180, now + 0.03);
        gain.gain.setValueAtTime(0.12, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.04);
        osc.start(now);
        osc.stop(now + 0.04);
      }
    } catch (e) {}
  }

  // --- Live Copy-on-Select Toast Engine ---
  let copyToastEl = null;
  let copyToastTimeout = null;

  function initCopyToast() {
    copyToastEl = document.createElement("div");
    copyToastEl.className = "nnts-copy-toast";
    copyToastEl.innerHTML = `<span class="toast-check">✓</span> <span class="toast-text">Copied to Clipboard</span>`;
    document.body.appendChild(copyToastEl);

    document.addEventListener("mouseup", handleTextSelection);
    document.addEventListener("keyup", (e) => {
      if (e.key === "Shift" || e.key === "ArrowLeft" || e.key === "ArrowRight") {
        handleTextSelection(e);
      }
    });
  }

  function handleTextSelection(e) {
    const sel = window.getSelection();
    if (!sel || sel.isCollapsed) return;

    const text = sel.toString().trim();
    if (text.length < 2) return;

    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).catch(() => {});
      }
    } catch (err) {}

    playTactileClick("copy");

    let x = e.clientX;
    let y = e.clientY;

    if (!x || !y) {
      try {
        const range = sel.getRangeAt(0);
        const rect = range.getBoundingClientRect();
        x = rect.left + rect.width / 2;
        y = rect.top - 10;
      } catch (err) {
        x = window.innerWidth / 2;
        y = window.innerHeight / 2;
      }
    }

    showCopyToast(x, y, text);
    handleMascotReaction("copy", 0, "select");
  }

  function showCopyToast(x, y, text) {
    if (!copyToastEl) return;
    if (copyToastTimeout) clearTimeout(copyToastTimeout);

    const toastW = 140;
    const toastH = 34;
    const posX = Math.max(16, Math.min(window.innerWidth - toastW - 16, x - toastW / 2));
    const posY = Math.max(16, y - toastH - 12);

    copyToastEl.style.left = `${posX}px`;
    copyToastEl.style.top = `${posY}px`;
    copyToastEl.classList.add("visible");

    copyToastTimeout = setTimeout(() => {
      copyToastEl.classList.remove("visible");
    }, 1100);
  }

  // --- Option C: Full-Bleed 60fps Video & Reactive Companion Mascot ---
  function initOptionCControls() {
    const videoEl = document.getElementById("cinematic-bg-video");
    const tabs = document.querySelectorAll(".cinematic-video-tabs .cinematic-tab-btn");
    const macroBtns = document.querySelectorAll(".cinematic-macro-strip .macro-tap-btn");
    const companionWidget = document.getElementById("companion-hud-widget");
    const mobileSpacer = document.getElementById("option-c-mobile-spacer");

    // Support deep link or test seek parameter
    if (videoEl) {
      const urlParams = new URLSearchParams(window.location.search);
      const videoParam = urlParams.get("video");
      if (videoParam === "copy") {
        videoEl.src = "assets/media/screenrec-select-copy.mp4";
        tabs.forEach(t => t.classList.toggle("active", (t.getAttribute("data-video-src") || "").includes("select-copy")));
      }
      const seekParam = urlParams.get("seek");
      if (seekParam) {
        videoEl.addEventListener("loadedmetadata", () => {
          videoEl.currentTime = parseFloat(seekParam);
        }, { once: true });
        if (videoEl.readyState >= 1) {
          videoEl.currentTime = parseFloat(seekParam);
        }
      }
    }

    // Video Tabs
    tabs.forEach((tab) => {
      tab.addEventListener("click", () => {
        tabs.forEach(t => t.classList.remove("active"));
        tab.classList.add("active");
        const src = tab.getAttribute("data-video-src");
        if (videoEl && src) {
          videoEl.src = src;
          videoEl.load();
          videoEl.play().catch(() => {});
          playTactileClick("popover");
        }
      });
    });

    // Macro Hotkey Simulator with Video Scrub & Mobile Haptics
    macroBtns.forEach((btn) => {
      btn.addEventListener("click", () => {
        const key = btn.getAttribute("data-key");
        const seekTime = btn.getAttribute("data-seek");
        playTactileClick("soft");
        if (navigator.vibrate) navigator.vibrate(15);

        // Highlight active button briefly
        macroBtns.forEach(b => b.classList.remove("active"));
        btn.classList.add("active");
        setTimeout(() => btn.classList.remove("active"), 800);

        if (key === "1") {
          if (videoEl && seekTime) {
            ensureVideoTrack("assets/media/screenrec-switch-app.mp4", parseFloat(seekTime));
          }
          if (typeof window.activateCategory === "function") {
            window.activateCategory("chrome", 0, "1", true);
          }
          handleMascotReaction("chrome", 0, "1");
        } else if (key === "2") {
          if (videoEl && seekTime) {
            ensureVideoTrack("assets/media/screenrec-switch-app.mp4", parseFloat(seekTime));
          }
          if (typeof window.activateCategory === "function") {
            window.activateCategory("chrome", 1, "2", true);
          }
          handleMascotReaction("chrome", 1, "2");
        } else if (key === "t") {
          if (videoEl && seekTime) {
            ensureVideoTrack("assets/media/screenrec-switch-app.mp4", parseFloat(seekTime));
          }
          if (typeof window.activateCategory === "function") {
            window.activateCategory("terminal", 0, "t", true);
          }
          handleMascotReaction("terminal", 0, "t");
        } else if (key === "copy") {
          ensureVideoTrack("assets/media/screenrec-select-copy.mp4", 0);
          const text = "Instant copy-on-select demo";
          showCopyToast(window.innerWidth / 2, window.innerHeight / 2, text);
          handleMascotReaction("copy", 0, "select");
        }
      });
    });

    function ensureVideoTrack(targetSrc, seekTime = 0) {
      if (!videoEl) return;
      const currentSrc = videoEl.getAttribute("src") || (videoEl.querySelector("source") ? videoEl.querySelector("source").getAttribute("src") : "");
      if (!currentSrc.includes(targetSrc)) {
        videoEl.src = targetSrc;
        videoEl.load();
      }
      videoEl.currentTime = seekTime;
      videoEl.play().catch(() => {});
      
      // Update tab active states
      tabs.forEach((tab) => {
        const tSrc = tab.getAttribute("data-video-src");
        tab.classList.toggle("active", tSrc === targetSrc);
      });
    }

    // Companion Widget & Avatar Click (Squish Physics)
    function triggerCompanionSquish(e) {
      if (e) e.stopPropagation();
      if (navigator.vibrate) navigator.vibrate([20, 40]);
      if (typeof window.triggerHamsterSquish === "function") {
        window.triggerHamsterSquish();
      }
      playTactileClick("copy");
      handleMascotReaction("companion", 0, "click");
    }

    if (companionWidget) {
      companionWidget.addEventListener("click", triggerCompanionSquish);
    }
    if (mobileSpacer) {
      mobileSpacer.addEventListener("click", triggerCompanionSquish);
    }

    // Mobile Sticky Copy Brew Button
    const mobileCopyBtn = document.getElementById("mobile-sticky-copy-btn");
    if (mobileCopyBtn) {
      mobileCopyBtn.addEventListener("click", (e) => {
        if (e) e.preventDefault();
        const text = "brew install unacau/tap/nnts";
        try {
          if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(text).catch(() => {});
          }
        } catch (err) {}
        playTactileClick("copy");
        showCopyToast(window.innerWidth / 2, window.innerHeight - 80, text);
        const orig = mobileCopyBtn.innerHTML;
        mobileCopyBtn.innerHTML = `<span>✓</span> <span>copied</span>`;
        setTimeout(() => {
          mobileCopyBtn.innerHTML = orig;
        }, 1400);
      });
    }

    // Mobile Copy-on-Select Touch Sandbox
    const copySandbox = document.getElementById("mobile-copy-sandbox");
    if (copySandbox) {
      copySandbox.addEventListener("mouseup", () => {
        const sel = window.getSelection();
        if (sel && !sel.isCollapsed && sel.toString().trim().length > 1) {
          const rect = copySandbox.getBoundingClientRect();
          showCopyToast(rect.left + rect.width / 2, rect.top - 12, sel.toString().trim());
        }
      });
    }

    // Sticky Mobile Bottom Bar Visibility on Scroll
    const stickyBar = document.getElementById("mobile-sticky-bar");
    if (stickyBar) {
      window.addEventListener("scroll", () => {
        if (window.innerWidth <= 900) {
          const show = window.scrollY > 200;
          stickyBar.classList.toggle("visible", show);
        } else {
          stickyBar.classList.remove("visible");
        }
      }, { passive: true });
    }
  }

  // Reactive Companion Mascot Reactions
  function handleMascotReaction(category, index, keyId) {
    const speech = document.getElementById("companion-speech");
    const widget = document.getElementById("companion-hud-widget");

    if (widget) {
      widget.classList.remove("companion-bounce");
      void widget.offsetWidth;
      widget.classList.add("companion-bounce");
      setTimeout(() => widget.classList.remove("companion-bounce"), 450);
    }

    if (!speech) return;

    let msg = "⚡ 0ms Latency Response!";
    if (category === "chrome") {
      const names = ["Personal (Igor)", "Work (Al11)", "GCP Free Trial", "Team"];
      const targetName = names[index] || "Profile";
      msg = `⚡ Teleported to Profile ${index + 1} (${targetName}) in 0ms!`;
    } else if (category === "terminal") {
      msg = `💻 Raised Terminal in 0ms! (Caps + T)`;
    } else if (category === "ide") {
      msg = `🛠️ Focused IDE Workspace in 0ms! (Caps + I)`;
    } else if (category === "ai") {
      msg = `🤖 Antigravity AI Agent ready! (Caps + A)`;
    } else if (category === "notes") {
      msg = `📝 Opened Notes scratchpad in 0ms! (Caps + N)`;
    } else if (category === "copy") {
      msg = `📋 Text copied directly to clipboard!`;
    } else if (category === "companion") {
      msg = `🐹 Squeeeak! 100% native Swift 6.`;
    }

    speech.textContent = msg;
    speech.classList.remove("active");
    void speech.offsetWidth;
    speech.classList.add("active");
  }

  // --- Authentic 60fps Video Proofs Modal ---
  function initProofsModal() {
    const openBtn = document.querySelector(".open-proofs-btn");
    const modal = document.getElementById("proofs-modal");
    const closeBtn = document.getElementById("proofs-close-btn");
    const modalVideo = document.getElementById("proofs-video");
    const tabs = document.querySelectorAll(".proofs-tab-btn");

    if (!modal) return;

    function openModal(videoSrc) {
      modal.classList.add("active");
      if (modalVideo) {
        if (videoSrc) modalVideo.src = videoSrc;
        modalVideo.currentTime = 0;
        modalVideo.load();
        modalVideo.play().catch(() => {});
      }
      playTactileClick("popover");
    }

    function closeModal() {
      modal.classList.remove("active");
      if (modalVideo) {
        modalVideo.pause();
      }
      playTactileClick("soft");
    }

    if (openBtn) {
      openBtn.addEventListener("click", () => {
        const src = openBtn.getAttribute("data-video-src") || "assets/media/screenrec-switch-app.mp4";
        openModal(src);
      });
    }

    if (closeBtn) {
      closeBtn.addEventListener("click", closeModal);
    }

    modal.addEventListener("click", (e) => {
      if (e.target === modal) {
        closeModal();
      }
    });

    window.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && modal.classList.contains("active")) {
        closeModal();
      }
    });

    tabs.forEach((tab) => {
      tab.addEventListener("click", () => {
        tabs.forEach(t => t.classList.remove("active"));
        tab.classList.add("active");
        const src = tab.getAttribute("data-src");
        if (modalVideo && src) {
          modalVideo.src = src;
          modalVideo.currentTime = 0;
          modalVideo.load();
          modalVideo.play().catch(() => {});
          playTactileClick("popover");
        }
      });
    });
  }

  // --- Brew Install Strip Copy Across Variants ---
  function initInstallStrips() {
    document.querySelectorAll(".hero-install-strip, .terminal-install-bar").forEach((strip) => {
      strip.addEventListener("click", (e) => {
        const cmdEl = strip.querySelector(".hero-install-cmd, .terminal-cmd");
        const text = cmdEl ? cmdEl.textContent.trim() : "brew install unacau/tap/nnts";

        try {
          if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(text).catch(() => {});
          }
        } catch (err) {}

        playTactileClick("copy");

        const rect = strip.getBoundingClientRect();
        const x = e.clientX || (rect.left + rect.width / 2);
        const y = e.clientY || (rect.top - 10);
        showCopyToast(x, y, text);

        const btn = strip.querySelector(".hero-install-copy-btn, .copy-cmd-btn");
        if (btn) {
          const origHtml = btn.innerHTML;
          btn.innerHTML = `<span>✓</span> <span>Copied!</span>`;
          btn.style.color = "#10B981";
          setTimeout(() => {
            btn.innerHTML = origHtml;
            btn.style.color = "";
          }, 1400);
        }
      });
    });
  }

  // --- Initialization Lifecycle ---
  document.addEventListener("DOMContentLoaded", () => {
    initCopyToast();
    initOptionCControls();
    initProofsModal();
    initInstallStrips();
  });

  // Export globally
  window.nntsInteractions = {
    playTactileClick,
    showCopyToast,
    handleMascotReaction
  };
  window.nntsVariants = window.nntsInteractions;
})();
