.PHONY: all run dev watch build native package test health validate checksums monitor diagnostics clean bump-major bump-minor bump-patch install release help

# Default target
all: validate test native checksums health

# ==============================================================================
# 🚀 Developer Inner Loop (Instant Testing without password or DMG)
# ==============================================================================
run:
	@./build_native_app.sh --run

dev: run

watch:
	@./scripts/watch_dev.sh

test:
	@./tests/run_tests.sh

# ==============================================================================
# 🛡️ Quality & Validation Gates
# ==============================================================================
validate:
	@echo "Checking version synchronization..."
	@V_TXT=$$(cat VERSION.txt | tr -d '[:space:]'); \
	B_TXT=$$(cat BUILD.txt | tr -d '[:space:]'); \
	PLIST="src/ChromeQuickAccess/Info.plist"; \
	V_PLIST=$$(plutil -extract CFBundleShortVersionString raw "$$PLIST" 2>/dev/null || echo "missing"); \
	B_PLIST=$$(plutil -extract CFBundleVersion raw "$$PLIST" 2>/dev/null || echo "missing"); \
	if [ "$$V_TXT" != "$$V_PLIST" ] || [ "$$B_TXT" != "$$B_PLIST" ]; then \
		echo "❌ Version mismatch: VERSION.txt ($$V_TXT/$$B_TXT) vs Info.plist ($$V_PLIST/$$B_PLIST)"; \
		exit 1; \
	fi; \
	echo "✅ Version synchronized ($$V_TXT, Build $$B_TXT)"
	@echo "Checking script syntax..."
	@bash -n release.sh build_native_app.sh bump_version.sh install.sh scripts/*.sh tests/*.sh
	@echo "✅ All shell scripts valid"

health:
	@./scripts/health_check.sh

# ==============================================================================
# 📦 Packaging & Distribution
# ==============================================================================
native:
	@./build_native_app.sh

build: native

package: native

install:
	@./install.sh --no-settings

release:
	@./release.sh

checksums:
	@if [ -f "dist/NNTS.dmg" ]; then \
		cd dist && shasum -a 256 NNTS.dmg > checksums.txt && echo "✅ dist/checksums.txt generated: $$(cat checksums.txt)" && cd ..; \
	else \
		echo "ℹ️ dist/NNTS.dmg not built yet. Run 'make native' first."; \
	fi

# ==============================================================================
# 📊 Observability & Diagnostics
# ==============================================================================
monitor:
	@./scripts/monitor_telemetry.sh stream

diagnostics:
	@./scripts/monitor_telemetry.sh summary 1h

# ==============================================================================
# 🏷️ Versioning
# ==============================================================================
bump-major:
	@./bump_version.sh major

bump-minor:
	@./bump_version.sh minor

bump-patch:
	@./bump_version.sh patch

# ==============================================================================
# 🧹 Housekeeping & Help
# ==============================================================================
clean:
	@rm -rf dist .build

help:
	@echo "NNTS Developer Commands:"
	@echo "  make dev / make run  - Fast build (host arch) + update /Applications + relaunch app (no password)"
	@echo "  make watch           - Live auto-reload: watches src/ and rebuilds/relaunches on save"
	@echo "  make test            - Run all automated unit tests"
	@echo "  make validate        - Verify version alignment & shell scripts"
	@echo "  make native          - Full universal build (arm64+x86_64) + DMG"
	@echo "  make install         - Install to /Applications via installer script"
	@echo "  make release         - Run release tagging & cloud release"
	@echo "  make monitor         - Stream real-time macOS unified logs"
	@echo "  make clean           - Remove build artifacts"

