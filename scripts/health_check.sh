#!/bin/bash
set -euo pipefail

# ==============================================================================
# NNTS - System Health & Diagnostics Utility
# Evaluates version consistency, binary architectures, and automated tests
# ==============================================================================

echo "=================================================="
echo " NNTS — System Health Check                       "
echo "=================================================="

FAILED=0

# 1. Check Versioning Consistency
echo -n "[1/3] Checking Versioning Consistency... "
if [ -f "VERSION.txt" ] && [ -f "BUILD.txt" ]; then
    V_TXT=$(cat VERSION.txt | tr -d '[:space:]')
    B_TXT=$(cat BUILD.txt | tr -d '[:space:]')
    PLIST="src/ChromeQuickAccess/Info.plist"
    if [ -f "$PLIST" ]; then
        V_PLIST=$(plutil -extract CFBundleShortVersionString raw "$PLIST" 2>/dev/null || echo "missing")
        B_PLIST=$(plutil -extract CFBundleVersion raw "$PLIST" 2>/dev/null || echo "missing")
        if [ "$V_TXT" = "$V_PLIST" ] && [ "$B_TXT" = "$B_PLIST" ]; then
            echo "✅ Synchronized (v$V_TXT, Build $B_TXT)"
        else
            echo "⚠️  Mismatch: VERSION.txt ($V_TXT / $B_TXT) vs Info.plist ($V_PLIST / $B_PLIST)"
            FAILED=1
        fi
    else
        echo "✅ Tracked ($V_TXT / Build $B_TXT)"
    fi
else
    echo "⚠️  VERSION.txt or BUILD.txt missing."
    FAILED=1
fi

# 2. Check Build Outputs & Universal Binary
echo -n "[2/3] Checking Build Artifacts & Universal Binary... "
APP_BUNDLE="dist/NNTS.app"
if [ -d "$APP_BUNDLE" ]; then
    BINARY="$APP_BUNDLE/Contents/MacOS/NNTS"
    if [ -f "$BINARY" ]; then
        ARCHS=$(lipo -archs "$BINARY" 2>/dev/null || echo "Unknown")
        echo "✅ Present (Architectures: $ARCHS)"
    else
        echo "⚠️  App bundle exists but executable is missing."
        FAILED=1
    fi
else
    echo "ℹ️  dist/ bundle not built yet (Run 'make native' to build)."
fi

SKIP_TESTS=0
for arg in "$@"; do
    if [ "$arg" = "--skip-tests" ] || [ "$arg" = "--no-tests" ]; then
        SKIP_TESTS=1
    fi
done

# 3. Check Test Suite Health
echo -n "[3/3] Running Automated Test Suite... "
if [ $SKIP_TESTS -eq 1 ]; then
    echo "⏭️  Skipped (Tests verified in prior step)"
elif ./tests/run_tests.sh >/dev/null 2>&1; then
    echo "✅ All tests passing cleanly."
else
    echo "❌ Test suite failed! Run ./tests/run_tests.sh for details."
    FAILED=1
fi

echo "=================================================="
if [ $FAILED -eq 0 ]; then
    echo "🎉 System Health: HEALTHY & PRODUCTION READY"
else
    echo "⚠️  System Health: ISSUES DETECTED"
fi
echo "=================================================="
exit $FAILED
