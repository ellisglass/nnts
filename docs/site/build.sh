#!/usr/bin/env bash
set -euo pipefail

echo "Building optimized CSS and JS for production..."

# Requires esbuild to be installed globally or via npx
npx --yes esbuild styles.css --minify --outfile=styles.min.css
npx --yes esbuild variants.css --minify --outfile=variants.min.css
npx --yes esbuild app.js --minify --outfile=app.min.js
npx --yes esbuild variants.js --minify --outfile=variants.min.js
npx --yes esbuild assets/js/OrbitControls.js --minify --outfile=assets/js/OrbitControls.min.js

echo "✅ Build complete. Minified files generated."
