#!/bin/bash
set -euo pipefail

APP_NAME="Xomsky"
DIST_DIR="dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
BUILD_DIR="${DIST_DIR}/build_native"
DMG_PATH="${DIST_DIR}/Xomsky.dmg"

FAST_DEV=false
RELAUNCH=false

for arg in "$@"; do
    case "$arg" in
        --fast|--dev)
            FAST_DEV=true
            ;;
        --run)
            FAST_DEV=true
            RELAUNCH=true
            ;;
        *)
            ;;
    esac
done

if [ "${FAST_DEV}" = true ]; then
    echo "=================================================="
    echo " Building Native ${APP_NAME} (.app) [FAST DEV]   "
    echo " Target: Host ($(uname -m)) macOS 14.0+           "
    echo "=================================================="
else
    echo "=================================================="
    echo " Building Native ${APP_NAME} (.app)               "
    echo " Target: Universal (arm64 & x86_64) macOS 14.0+   "
    echo "=================================================="
fi

rm -rf "${APP_BUNDLE}" "${BUILD_DIR}"
mkdir -p "${MACOS_DIR}" "${CONTENTS_DIR}" "${RESOURCES_DIR}" "${BUILD_DIR}/temp"

SOURCES=(
    "src/ChromeQuickAccess/Engine/KeyCodes.swift"
    "src/ChromeQuickAccess/Engine/XomskyMotion.swift"
    "src/ChromeQuickAccess/Engine/CapsLockEngine.swift"
    "src/ChromeQuickAccess/Engine/ChromeProfileEngine.swift"
    "src/ChromeQuickAccess/Engine/AntigravityEngine.swift"
    "src/ChromeQuickAccess/Engine/AppGroupEngine.swift"
    "src/ChromeQuickAccess/Engine/CopyOnSelectEngine.swift"
    "src/ChromeQuickAccess/Engine/LicenseEngine.swift"
    "src/ChromeQuickAccess/Engine/UpdateEngine.swift"
    "src/ChromeQuickAccess/Engine/TelemetryBuffer.swift"
    "src/ChromeQuickAccess/Engine/DiagnosticBundleService.swift"
    "src/ChromeQuickAccess/Views/CopyToastWindow.swift"
    "src/ChromeQuickAccess/Views/MinimalHUDWindow.swift"
    "src/ChromeQuickAccess/Views/AppSearchPickerWindow.swift"
    "src/ChromeQuickAccess/Views/FeedbackWindow.swift"
    "src/ChromeQuickAccess/AppDelegate.swift"
    "src/ChromeQuickAccess/main.swift"
)

FRAMEWORKS=(
    "-framework" "Cocoa"
    "-framework" "AppKit"
    "-framework" "SwiftUI"
    "-framework" "ApplicationServices"
    "-framework" "CoreGraphics"
    "-framework" "UniformTypeIdentifiers"
    "-framework" "Security"
)

if [ "${FAST_DEV}" = true ]; then
    HOST_ARCH=$(uname -m)
    if [ "${HOST_ARCH}" = "arm64" ]; then
        TARGET_TRIPLE="arm64-apple-macos14.0"
    else
        TARGET_TRIPLE="x86_64-apple-macos14.0"
    fi

    echo "[1/2] Compiling ${HOST_ARCH} slice for local testing..."
    swiftc \
        -parse-as-library \
        -target "${TARGET_TRIPLE}" \
        "${SOURCES[@]}" \
        -o "${MACOS_DIR}/Xomsky" \
        "${FRAMEWORKS[@]}" \
        -Onone

    echo "[2/2] Packaging Info.plist, AppIcon & Code-Signing..."
    cp "src/ChromeQuickAccess/Info.plist" "${CONTENTS_DIR}/Info.plist"
    if [ -f "src/ChromeQuickAccess/Resources/GlitchBackground.png" ]; then
        cp "src/ChromeQuickAccess/Resources/GlitchBackground.png" "${RESOURCES_DIR}/GlitchBackground.png"
    fi

    if [ -f "src/ChromeQuickAccess/Resources/AppIcon.icns" ]; then
        cp "src/ChromeQuickAccess/Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
        
    fi
    codesign --force --sign - --identifier "com.almosteleven.xomsky" -r="designated => identifier \"com.almosteleven.xomsky\"" "${APP_BUNDLE}"

    rm -rf "${BUILD_DIR}"

    if [ "${RELAUNCH}" = true ]; then
        echo "[*] Updating /Applications/${APP_NAME}.app and relaunching..."
        pkill -x "${APP_NAME}" 2>/dev/null || true
        sleep 0.3
        rm -rf "/Applications/${APP_NAME}.app"
        cp -R "${APP_BUNDLE}" "/Applications/${APP_NAME}.app"
        xattr -cr "/Applications/${APP_NAME}.app" 2>/dev/null || true
        open "/Applications/${APP_NAME}.app"
        echo "=================================================="
        echo " 🚀 ${APP_NAME} updated & running in /Applications!"
        echo " Ready to test instantly without password prompts."
        echo "=================================================="
    else
        echo "=================================================="
        echo " ✅ Fast Dev Build Succeeded!"
        echo " App: ${APP_BUNDLE}"
        echo "=================================================="
    fi
    exit 0
fi

echo "[1/5] Compiling arm64 slice (Apple Silicon)..."
mkdir -p "${BUILD_DIR}/temp"
swiftc \
    -parse-as-library \
    -target arm64-apple-macos14.0 \
    "${SOURCES[@]}" \
    -o "${BUILD_DIR}/temp/binary_arm64" \
    "${FRAMEWORKS[@]}" \
    -O

echo "[2/5] Compiling x86_64 slice (Intel)..."
mkdir -p "${BUILD_DIR}/temp"
swiftc \
    -parse-as-library \
    -target x86_64-apple-macos14.0 \
    "${SOURCES[@]}" \
    -o "${BUILD_DIR}/temp/binary_x86_64" \
    "${FRAMEWORKS[@]}" \
    -O

echo "[3/5] Creating Universal Mach-O Binary with lipo..."
lipo -create -output "${MACOS_DIR}/Xomsky" \
    "${BUILD_DIR}/temp/binary_arm64" \
    "${BUILD_DIR}/temp/binary_x86_64"

echo "[4/5] Packaging Info.plist, AppIcon & Code-Signing..."
cp "src/ChromeQuickAccess/Info.plist" "${CONTENTS_DIR}/Info.plist"
    if [ -f "src/ChromeQuickAccess/Resources/GlitchBackground.png" ]; then
        cp "src/ChromeQuickAccess/Resources/GlitchBackground.png" "${RESOURCES_DIR}/GlitchBackground.png"
    fi

if [ -f "src/ChromeQuickAccess/Resources/AppIcon.icns" ]; then
    cp "src/ChromeQuickAccess/Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
        
fi
if [ -f "src/ChromeQuickAccess/Resources/dmg_background.png" ]; then
    cp "src/ChromeQuickAccess/Resources/dmg_background.png" "${RESOURCES_DIR}/dmg_background.png"
fi

codesign --force --sign - --identifier "com.almosteleven.xomsky" -r="designated => identifier \"com.almosteleven.xomsky\"" "${APP_BUNDLE}"
codesign -vvv "${APP_BUNDLE}"

echo "[5/5] Generating DMG Installer..."
rm -f "${DMG_PATH}"
DMG_STAGE="${BUILD_DIR}/dmg_stage"
rm -rf "${DMG_STAGE}"
mkdir -p "${DMG_STAGE}/.background"
cp -R "${APP_BUNDLE}" "${DMG_STAGE}/"
ln -s /Applications "${DMG_STAGE}/Applications"
if [ -f "src/ChromeQuickAccess/Resources/dmg_background.png" ]; then
    cp "src/ChromeQuickAccess/Resources/dmg_background.png" "${DMG_STAGE}/.background/background.png"
fi
hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_STAGE}" -ov -format UDZO "${DMG_PATH}"

rm -rf "${BUILD_DIR}"

echo "=================================================="
echo " ✅ Standalone Build Succeeded!"
echo " App: ${APP_BUNDLE}"
echo " DMG: ${DMG_PATH}"
echo " Archs: $(lipo -archs "${MACOS_DIR}/Xomsky")"
echo "=================================================="
