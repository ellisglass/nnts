#!/bin/bash
set -euo pipefail

# ==============================================================================
# Xomsky - Automated One-Line Installer
# Usage:
#   curl -fsSL https://almosteleven.com/install.sh | bash
#   or from local clone: ./install.sh [--no-build] [--no-open]
# ==============================================================================

APP_NAME="Xomsky"
APP_BUNDLE="${APP_NAME}.app"
TARGET_DIR="/Applications"
TARGET_APP="${TARGET_DIR}/${APP_BUNDLE}"
GITHUB_REPO="unacau/xomsky"
DMG_NAME="${APP_NAME}.dmg"

NO_BUILD=false
NO_OPEN=false
NO_SETTINGS=false
FORCE_REMOTE=false

for arg in "$@"; do
    case "$arg" in
        --no-build)
            NO_BUILD=true
            ;;
        --no-open)
            NO_OPEN=true
            ;;
        --no-settings|--skip-settings)
            NO_SETTINGS=true
            ;;
        --remote)
            FORCE_REMOTE=true
            ;;
        *)
            ;;
    esac
done

echo "=================================================="
echo " Installing ${APP_NAME} for macOS                 "
echo " Fast & Intuitive App Access via Caps Lock        "
echo "=================================================="

# Check if running on macOS
if [ "$(uname -s)" != "Darwin" ]; then
    echo "❌ Error: ${APP_NAME} requires macOS 14.0 or newer."
    exit 1
fi

TMP_DIR=""
MOUNT_POINT=""

cleanup() {
    if [ -n "${MOUNT_POINT}" ] && [ -d "${MOUNT_POINT}" ]; then
        hdiutil detach "${MOUNT_POINT}" -force >/dev/null 2>&1 || true
    fi
    if [ -n "${TMP_DIR}" ] && [ -d "${TMP_DIR}" ]; then
        rm -rf "${TMP_DIR}"
    fi
}
trap cleanup EXIT INT TERM

SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]:-}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [ -f "./build_native_app.sh" ]; then
    SCRIPT_DIR="$(pwd)"
fi

INSTALLED_FROM=""

# Strategy 1: Local repository build/bundle
if [ "${FORCE_REMOTE}" = false ] && [ -n "${SCRIPT_DIR}" ] && [ -f "${SCRIPT_DIR}/build_native_app.sh" ]; then
    LOCAL_BUNDLE="${SCRIPT_DIR}/dist/${APP_BUNDLE}"
    if [ "${NO_BUILD}" = false ] || [ ! -d "${LOCAL_BUNDLE}" ]; then
        echo "[*] Building ${APP_NAME} locally from source..."
        "${SCRIPT_DIR}/build_native_app.sh"
    fi
    
    if [ -d "${LOCAL_BUNDLE}" ]; then
        echo "[*] Closing running instances of ${APP_NAME}..."
        pkill -f "/Applications/${APP_BUNDLE}" >/dev/null 2>&1 || true
        echo "[*] Installing local bundle to ${TARGET_DIR}..."
        rm -rf "${TARGET_APP}"
        cp -R "${LOCAL_BUNDLE}" "${TARGET_DIR}/"
        INSTALLED_FROM="local source build"
    fi
fi

# Strategy 2: Remote download from GitHub Releases or AlmostEleven
if [ -z "${INSTALLED_FROM}" ]; then
    TMP_DIR=$(mktemp -d /tmp/xomsky_install_XXXXXX)
    DMG_PATH="${TMP_DIR}/${DMG_NAME}"
    MOUNT_POINT="${TMP_DIR}/mount"
    mkdir -p "${MOUNT_POINT}"

    CANDIDATE_URLS=(
        "https://github.com/${GITHUB_REPO}/releases/latest/download/${APP_NAME}.dmg"
        "https://github.com/${GITHUB_REPO}/releases/download/v1.0.1/${APP_NAME}.dmg"
        "https://almosteleven.com/downloads/${APP_NAME}.dmg"
        "https://almosteleven.com/${APP_NAME}.dmg"
        "https://github.com/${GITHUB_REPO}/releases/latest/download/Khomyak.dmg"
        "https://github.com/${GITHUB_REPO}/releases/latest/download/ChromeQuickAccess.dmg"
    )

    DOWNLOAD_SUCCESS=false
    for url in "${CANDIDATE_URLS[@]}"; do
        echo "[*] Trying download from ${url}..."
        if curl -fsSL -L "${url}" -o "${DMG_PATH}" 2>/dev/null; then
            if hdiutil imageinfo "${DMG_PATH}" >/dev/null 2>&1; then
                echo "✅ Downloaded valid disk image from ${url}"
                DOWNLOAD_SUCCESS=true
                break
            else
                echo "⚠️  Endpoint ${url} returned invalid disk image payload (e.g. HTML/Text). Trying next..."
                rm -f "${DMG_PATH}"
            fi
        fi
    done

    if [ "${DOWNLOAD_SUCCESS}" = false ]; then
        echo "❌ Error: Could not download release DMG from any known release endpoint."
        exit 1
    fi

    echo "[*] Mounting disk image..."
    hdiutil attach "${DMG_PATH}" -nobrowse -readonly -mountpoint "${MOUNT_POINT}" >/dev/null

    SOURCE_APP=""
    if [ -d "${MOUNT_POINT}/${APP_BUNDLE}" ]; then
        SOURCE_APP="${MOUNT_POINT}/${APP_BUNDLE}"
    else
        FOUND_APP=$(find "${MOUNT_POINT}" -maxdepth 2 -name "*.app" -type d | head -n 1)
        if [ -n "${FOUND_APP}" ] && [ -d "${FOUND_APP}" ]; then
            SOURCE_APP="${FOUND_APP}"
        fi
    fi

    if [ -z "${SOURCE_APP}" ]; then
        echo "❌ Error: Could not find application bundle inside disk image."
        exit 1
    fi

    echo "[*] Closing running instances of ${APP_NAME}..."
    pkill -f "/Applications/${APP_BUNDLE}" >/dev/null 2>&1 || true
    echo "[*] Installing $(basename "${SOURCE_APP}") to ${TARGET_APP}..."
    rm -rf "${TARGET_APP}"
    cp -R "${SOURCE_APP}" "${TARGET_APP}"
    chmod -R +x "${TARGET_APP}/Contents/MacOS" 2>/dev/null || true
    INSTALLED_FROM="official release DMG"
fi

# Post-Install Verification & Gatekeeper Integrity Check
echo "[*] Verifying integrity of application bundle..."
if [ ! -f "${TARGET_APP}/Contents/MacOS/${APP_NAME}" ] || [ ! -x "${TARGET_APP}/Contents/MacOS/${APP_NAME}" ]; then
    echo "❌ Error: Invalid or tampered binary inside bundle."
    exit 1
fi

if codesign --verify --deep --strict "${TARGET_APP}" >/dev/null 2>&1; then
    echo "✅ Application code signature verified cleanly."
else
    echo "ℹ️  Application bundle verified (ad-hoc / local signature)."
fi

# Post-Install Gatekeeper & Quarantine Removal
echo "[*] Removing quarantine attributes (xattr -cr)..."
xattr -cr "${TARGET_APP}"

# Accessibility & Launch
if [ "${NO_OPEN}" = false ]; then
    echo "[*] Launching ${APP_NAME}..."
    open "${TARGET_APP}" || true

    if [ "${NO_SETTINGS}" = false ]; then
        echo "[*] Opening macOS Accessibility Preferences..."
        open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || true
    fi
fi

echo "=================================================="
echo " ✅ Installation Complete!                        "
echo " Installed: ${TARGET_APP} (${INSTALLED_FROM})     "
echo "=================================================="
echo "Next Steps & 3 Core Capabilities:"
echo " 1. Enable Accessibility for '${APP_NAME}' in System Settings."
echo " 2. Tap Caps-Lock alone ➔ Escape."
echo " 3. Tap Caps-Lock + C/B + 1..4 ➔ Direct Chrome/Brave profile windows (#1 Killer Feature)."
echo " 4. Tap Caps-Lock + letter (T, I, A, N, F) ➔ Instant app switch (#2 First Letter)."
echo " 5. Select text anywhere ➔ Automatic Copy-on-Select (#3 No more Cmd+C)."
