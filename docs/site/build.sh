#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "Building optimized CSS and JS for production..."

# Requires esbuild to be installed globally or via npx
npx --yes esbuild styles.css --minify --outfile=styles.min.css
npx --yes esbuild app.js --minify --outfile=app.min.js

echo "✅ Build complete. Minified files generated."
