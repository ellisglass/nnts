---
name: mac-productivity-ops
description: Operational, CI/CD pipeline management, semantic versioning, observability, and diagnostic procedures for Chrome Quick Access. Use whenever bumping versions, building release artifacts, streaming logs, monitoring system health, running quality gates, or managing the release lifecycle.
---

# Chrome Quick Access Operations & Pipeline Management Guide

This skill governs the end-to-end management, maintenance, versioning, observability, and release lifecycle of Chrome Quick Access.

---

## 1. Pipeline Management Protocols

Whenever tasked with maintaining, updating, or releasing the application:

### Step 1: Quality Gate & Health Check
Always execute pre-flight diagnostics and verification before initiating any build or release:
```bash
make health
```
This runs the 3-point automated verification:
1. Version synchronization check between `VERSION.txt`, `BUILD.txt`, and `src/ChromeQuickAccess/Info.plist`.
2. Binary architecture verification (`arm64` + `x86_64` Mach-O universal slices in `dist/Chrome Quick Access.app`).
3. Automated test suite run (`./tests/run_tests.sh`).

### Step 2: Semantic Version Bumping
Never manually edit version numbers across disparate files. Use the automated semantic versioning commands:
```bash
make bump-patch  # Bug fixes, minor adjustments (e.g. 1.0.0 -> 1.0.1)
make bump-minor  # New non-breaking features (e.g. 1.0.1 -> 1.1.0)
make bump-major  # Breaking architectural changes (e.g. 1.1.0 -> 2.0.0)
```
This automatically:
- Updates `VERSION.txt` and increments `BUILD.txt`.
- Updates `src/ChromeQuickAccess/Info.plist` (`CFBundleShortVersionString` and `CFBundleVersion`) via `plutil`.

### Step 3: Local Builds & Packaging
```bash
# Build standalone universal app & DMG
make native

# Run test suite
make test

# Install locally to /Applications
make install
```

### Step 4: Release Execution & Cloud Automation
Chrome Quick Access supports automated cloud-native releases powered by GitHub Actions:

**Recommended: Cloud-Native Release via Git Tag**
1. Ensure the working tree is clean and version is bumped:
   ```bash
   make validate
   make health
   ```
2. Trigger the automated cloud release pipeline:
   ```bash
   ./release.sh --push
   # or manually:
   # git tag -a v$(cat VERSION.txt) -m "Release v$(cat VERSION.txt)"
   # git push origin v$(cat VERSION.txt)
   ```
   This triggers `.github/workflows/release.yml` on GitHub Actions, which compiles the universal binary, runs health checks, generates SHA-256 checksums (`checksums.txt`), and automatically publishes a GitHub Release with all assets attached.

**Alternative: Local Fallback Release**
If releasing locally without cloud CI:
```bash
./release.sh --local
```

### Step 5: CI/CD Quality Gates & Artifact Delivery
The GitHub Actions CI pipeline (`.github/workflows/ci.yml`) runs on every pull request and push to `main` across three isolated stages:
- **`lint-and-validate`**: Verifies version synchronization between `VERSION.txt`, `BUILD.txt`, and `Info.plist`, and lints all shell scripts.
- **`test`**: Independent fast-fail gate running the Swift Testing unit suite in <30 seconds.
- **`package`**: Compiles universal Mach-O binaries, packages the `.dmg` installer, computes SHA-256 hashes, and uploads downloadable artifacts (`ChromeQuickAccess-dmg`, 7-day retention) directly to the PR / workflow run.

---

## 2. Observability & Telemetry Instrumentation

The suite emits structured logs directly to the macOS Unified Logging System (`os_log`) under subsystem `com.almosteleven.nnts`.

### Architecture Subsystems:
- `app`: Application lifecycle, menu setup, and general state.
- `engine`: Caps-Lock hardware remapping and global event tap routing.
- `profiles`: Chromium `Local State` parsing, monogram rendering, and menu bar AX profile switching.
- `antigravity`: Antigravity & Antigravity IDE application discovery and switching.
- `copy-on-select`: Universal mouse drag and multi-click text selection copy engine.
- `hid`: `hidutil` hardware modifier mapping service.

### Telemetry Operations:
```bash
# Live stream real-time telemetry (all categories)
make monitor
# or
./scripts/monitor_telemetry.sh stream

# View aggregated category distribution & error rate
make diagnostics
# or
./scripts/monitor_telemetry.sh summary 1h

# Extract recent errors and faults (last 30 minutes)
./scripts/monitor_telemetry.sh errors 30m

# Export ndjson log records for log analytics ingestion
./scripts/monitor_telemetry.sh json 1h > telemetry.jsonl
```
