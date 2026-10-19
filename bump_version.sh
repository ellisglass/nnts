#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 {major|minor|patch}"
    exit 1
fi

BUMP_TYPE=$1
VERSION_FILE="VERSION.txt"
BUILD_FILE="BUILD.txt"
PLIST_FILE="src/NNTS/Info.plist"

if [ ! -f "$VERSION_FILE" ]; then
    echo "1.0.0" > "$VERSION_FILE"
fi

if [ ! -f "$BUILD_FILE" ]; then
    echo "1" > "$BUILD_FILE"
fi

CURRENT_VERSION=$(cat "$VERSION_FILE")
CURRENT_BUILD=$(cat "$BUILD_FILE")

IFS='.' read -r -a parts <<< "$CURRENT_VERSION"
MAJOR="${parts[0]:-0}"
MINOR="${parts[1]:-0}"
PATCH="${parts[2]:-0}"

case "$BUMP_TYPE" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
    *)
        echo "Invalid bump type: $BUMP_TYPE. Use major, minor, or patch."
        exit 1
        ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
NEW_BUILD=$((CURRENT_BUILD + 1))

echo "$NEW_VERSION" > "$VERSION_FILE"
echo "$NEW_BUILD" > "$BUILD_FILE"

# Update Info.plist using plutil
plutil -replace CFBundleShortVersionString -string "$NEW_VERSION" "$PLIST_FILE"
plutil -replace CFBundleVersion -string "$NEW_BUILD" "$PLIST_FILE"

echo "✅ Bumped version: $CURRENT_VERSION -> $NEW_VERSION (Build $NEW_BUILD)"
echo "✅ Updated $VERSION_FILE, $BUILD_FILE, and $PLIST_FILE"
