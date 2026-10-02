#!/bin/bash
set -euo pipefail

# ==============================================================================
# NNTS - Release Management Utility
# Supports both Cloud-Native Tag Releases (GHA) and Local Distribution
# ==============================================================================

VERSION=$(cat VERSION.txt | tr -d '[:space:]')
BUILD=$(cat BUILD.txt | tr -d '[:space:]')
APP_NAME="NNTS"
DMG_FILE="dist/NNTS.dmg"
CHECKSUM_FILE="dist/checksums.txt"
REPO="unacau/nnts"
TAG="v$VERSION"

MODE="cloud"
DRY_RUN=0

print_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
  --push           Create git tag '$TAG' and push to origin (triggers GitHub Actions release).
  --tag-only       Create git tag '$TAG' locally without pushing.
  --local          Build locally, generate checksums, and publish via local 'gh' CLI.
  --sync-tap       Synchronize unacau/homebrew-tap with the current version and release DMG.
  --dry-run        Perform pre-flight verification without creating tags or publishing.
  -h, --help       Show this help message.

Default behavior:
  Runs pre-flight verification and guides you through triggering the automated
  GitHub Actions cloud release pipeline.
EOF
}

sync_homebrew_tap() {
    local version="$1"
    local dmg_path="dist/NNTS.dmg"
    local sha=""

    if [ -f "$dmg_path" ]; then
        sha=$(shasum -a 256 "$dmg_path" | awk '{print $1}')
    else
        echo "Fetching checksum from GitHub release v${version}..."
        sha=$(curl -sL "https://github.com/$REPO/releases/download/v${version}/checksums.txt" | awk '{print $1}' || echo "")
    fi

    if [ -z "$sha" ]; then
        echo "❌ Could not determine SHA-256 checksum for NNTS.dmg"
        return 1
    fi

    if [ -f "Casks/nnts.rb" ]; then
        echo "🚀 Updating local formula Casks/nnts.rb..."
        sed -i '' -e "s/version \".*\"/version \"${version}\"/" Casks/nnts.rb || sed -i -e "s/version \".*\"/version \"${version}\"/" Casks/nnts.rb
        sed -i '' -e "s/sha256 \".*\"/sha256 \"${sha}\"/" Casks/nnts.rb || sed -i -e "s/sha256 \".*\"/sha256 \"${sha}\"/" Casks/nnts.rb
    fi

    if command -v gh >/dev/null 2>&1; then
        echo "🚀 Updating remote tap unacau/homebrew-tap via gh API..."
        local file_sha
        file_sha=$(gh api repos/unacau/homebrew-tap/contents/Casks/nnts.rb --jq .sha 2>/dev/null || echo "")
        local content
        if [ -f "Casks/nnts.rb" ]; then
            content=$(cat Casks/nnts.rb | base64)
        else
            content=""
        fi

        if [ -n "$file_sha" ] && [ -n "$content" ]; then
            gh api -X PUT repos/unacau/homebrew-tap/contents/Casks/nnts.rb \
                -F message="chore(cask): update nnts to v${version}" \
                -F content="$content" \
                -F sha="$file_sha" >/dev/null
            echo "✅ unacau/homebrew-tap updated successfully to v${version}!"
        else
            echo "⚠️ Could not read Casks/nnts.rb from unacau/homebrew-tap via gh API."
        fi
    else
        echo "⚠️ gh CLI not found; unable to update unacau/homebrew-tap."
    fi
}

for arg in "$@"; do
    case "$arg" in
        --push)
            MODE="push"
            ;;
        --tag-only)
            MODE="tag"
            ;;
        --local)
            MODE="local"
            ;;
        --sync-tap)
            MODE="sync-tap"
            ;;
        --dry-run)
            DRY_RUN=1
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg"
            print_usage
            exit 1
            ;;
    esac
done

echo "=================================================="
echo " Preparing Release $TAG (Build $BUILD)"
echo " App: $APP_NAME"
echo " Mode: $MODE (Dry Run: $DRY_RUN)"
echo "=================================================="

# 1. Pre-Flight Quality Gate & Health Check
echo "[1/3] Running Pre-Flight Quality Gate & Diagnostics..."
./scripts/health_check.sh

if [ $DRY_RUN -eq 1 ]; then
    echo "=================================================="
    echo " 🔎 Dry run complete. Pre-flight health passed!"
    echo " Would target Tag: $TAG (v$VERSION, Build $BUILD)"
    echo "=================================================="
    exit 0
fi

# 2. Execution based on selected mode
case "$MODE" in
    push)
        echo "[2/3] Tagging release $TAG..."
        if git rev-parse "$TAG" >/dev/null 2>&1; then
            echo "ℹ️ Tag $TAG already exists locally."
        else
            git tag -a "$TAG" -m "Release $TAG (Build $BUILD)"
            echo "✅ Created git tag $TAG."
        fi

        echo "[3/3] Pushing tag to origin to trigger GitHub Actions release..."
        git push origin "$TAG"
        echo "=================================================="
        echo " 🚀 Release Pipeline Triggered via GitHub Actions!"
        echo " Track progress at: https://github.com/$REPO/actions"
        echo "=================================================="
        ;;

    tag)
        echo "[2/3] Creating git tag $TAG locally..."
        if git rev-parse "$TAG" >/dev/null 2>&1; then
            echo "ℹ️ Tag $TAG already exists locally."
        else
            git tag -a "$TAG" -m "Release $TAG (Build $BUILD)"
            echo "✅ Tag $TAG created."
        fi
        echo "[3/3] Done. Push whenever ready with:"
        echo "      git push origin $TAG"
        ;;

    local)
        echo "[2/3] Building Universal Application, DMG & Checksums locally..."
        ./build_native_app.sh
        mkdir -p dist
        cd dist
        shasum -a 256 NNTS.dmg > checksums.txt
        echo "✅ Checksum computed: $(cat checksums.txt)"
        cd ..

        echo "[3/3] Publishing via local GitHub CLI (gh)..."
        if command -v gh >/dev/null 2>&1; then
            if ! gh release create "$TAG" "$DMG_FILE" "$CHECKSUM_FILE" \
                --title "$TAG - $APP_NAME & Productivity Suite" \
                --notes "Release $TAG (Build $BUILD) of $APP_NAME featuring driverless Caps-Lock remapping, multi-profile Chrome cycling, Antigravity switcher, and universal Copy-on-Select." \
                --repo "$REPO" 2>/dev/null; then
                echo "ℹ️ gh release already exists for $TAG. Updating release assets with --clobber..."
                gh release upload "$TAG" "$DMG_FILE" "$CHECKSUM_FILE" --repo "$REPO" --clobber
            fi
        else
            echo "ℹ️ GitHub CLI (gh) not installed. Artifacts available at $DMG_FILE and $CHECKSUM_FILE."
        fi

        echo "Synchronizing Homebrew Tap..."
        sync_homebrew_tap "$VERSION"

        echo "=================================================="
        echo " ✅ Local Release $TAG Completed!"
        echo " Artifacts: $DMG_FILE, $CHECKSUM_FILE"
        echo "=================================================="
        ;;

    sync-tap)
        echo "[2/2] Synchronizing Homebrew Tap for $TAG..."
        sync_homebrew_tap "$VERSION"
        exit 0
        ;;

    cloud)
        echo "[2/3] Verifying git state..."
        if git rev-parse "$TAG" >/dev/null 2>&1; then
            echo "ℹ️ Tag $TAG already exists."
        else
            echo "Tag $TAG is ready to be created."
        fi

        echo "[3/3] Ready to trigger Cloud Release Workflow!"
        echo ""
        echo "To trigger the automated GitHub Actions release workflow, run:"
        echo "  ./release.sh --push"
        echo ""
        echo "Or run manually:"
        echo "  git tag -a $TAG -m \"Release $TAG (Build $BUILD)\""
        echo "  git push origin $TAG"
        echo ""
        echo "For an offline/local build & publish directly from this machine:"
        echo "  ./release.sh --local"
        echo "=================================================="
        ;;
esac
