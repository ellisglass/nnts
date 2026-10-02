#!/bin/bash
set -euo pipefail

# ==============================================================================
# NNTS Live Watcher
# Continuously monitors src/ChromeQuickAccess for changes and triggers
# instant compilation, installation to /Applications, and app relaunch.
# ==============================================================================

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WATCH_DIR="${PROJECT_DIR}/src/ChromeQuickAccess"

echo "=================================================="
echo " 🔭 NNTS Live Dev Watcher Active"
echo " Watching: ${WATCH_DIR}"
echo " Action: Auto-build & relaunch on file save"
echo " Press Ctrl+C to stop"
echo "=================================================="

# Run initial build & launch
"${PROJECT_DIR}/build_native_app.sh" --run

exec python3 -u -c '
import os, sys, time, subprocess

project_dir = sys.argv[1]
watch_dir = sys.argv[2]
build_cmd = [os.path.join(project_dir, "build_native_app.sh"), "--run"]

def get_snapshot():
    snapshot = {}
    for root, _, files in os.walk(watch_dir):
        for f in files:
            if f.startswith(".") or f.endswith("~"):
                continue
            path = os.path.join(root, f)
            try:
                stat = os.stat(path)
                snapshot[path] = (stat.st_mtime, stat.st_size)
            except OSError:
                pass
    return snapshot

last_snapshot = get_snapshot()

try:
    while True:
        time.sleep(0.5)
        current_snapshot = get_snapshot()
        
        changed_files = []
        for path, meta in current_snapshot.items():
            if path not in last_snapshot or last_snapshot[path] != meta:
                changed_files.append(os.path.relpath(path, project_dir))
        
        for path in last_snapshot:
            if path not in current_snapshot:
                changed_files.append(os.path.relpath(path, project_dir) + " (deleted)")
                
        if changed_files:
            # Short debounce to settle multi-file editor saves
            time.sleep(0.2)
            last_snapshot = get_snapshot()
            
            print("\n🔄 [NNTS Watcher] Change detected in: " + ", ".join(changed_files[:3]))
            print("⚡ Rebuilding & relaunching app...")
            res = subprocess.run(build_cmd)
            if res.returncode == 0:
                print("✨ [NNTS Watcher] Live reload complete! Ready.\n")
            else:
                print("❌ [NNTS Watcher] Build failed (exit code {}). Fix error and save again.\n".format(res.returncode))
except KeyboardInterrupt:
    print("\n👋 NNTS Live Dev Watcher stopped.")
    sys.exit(0)
' "${PROJECT_DIR}" "${WATCH_DIR}"
