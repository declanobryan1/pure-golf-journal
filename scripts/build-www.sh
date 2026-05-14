#!/bin/bash
# Build the www/ directory that Capacitor will package into the iOS app.
# Pure is a single-file PWA, so we don't have a bundler — we just copy the
# files Capacitor needs to ship inside the iOS app's WebView.
#
# Run this every time index.html or any asset changes:
#   ./scripts/build-www.sh && npx cap sync ios
#
# Or use the npm script: npm run cap:sync (which calls this for you).

set -euo pipefail
cd "$(dirname "$0")/.."

OUT=www
rm -rf "$OUT"
mkdir -p "$OUT"

# Pre-fetch any new remote course images to images/courses/remote/, then precompile
# index.html with the URL→local-path rewrites baked in. Keeps photos always-instant
# inside the iOS app. The prefetch step is idempotent — only downloads new URLs.
node scripts/prefetch-remote-images.js
node scripts/precompile-babel.js
cp manifest.json "$OUT/" 2>/dev/null || true

# Icons (PWA + Apple touch + maskable)
cp apple-touch-icon.png "$OUT/" 2>/dev/null || true
cp icon-192.png "$OUT/" 2>/dev/null || true
cp icon-512.png "$OUT/" 2>/dev/null || true
cp icon-maskable.png "$OUT/" 2>/dev/null || true

# Brand assets referenced from index.html
cp pure-full-noback.png "$OUT/" 2>/dev/null || true
cp pure-p-noback.png "$OUT/" 2>/dev/null || true
cp pure-p-icon.png "$OUT/" 2>/dev/null || true
cp pure-wordmark-noback.png "$OUT/" 2>/dev/null || true
cp golf-journal-cream.png "$OUT/" 2>/dev/null || true
cp golf-journal-green.png "$OUT/" 2>/dev/null || true
cp PURE_app_icon.png "$OUT/" 2>/dev/null || true

# Course imagery — recursively copy images/ but exclude HEIC backups AND the
# images/courses/_original/ folder (full-resolution source files, only used by
# scripts/prefetch-remote-images.js to regenerate downsized versions; never read
# at runtime). Including them was bloating the iOS bundle by ~150MB and slowing
# both app install and cold launch.
mkdir -p "$OUT/images"
cp -R images/* "$OUT/images/" 2>/dev/null || true
find "$OUT/images" -name "*HEIC_backup*" -delete 2>/dev/null || true
rm -rf "$OUT/images/courses/_original" 2>/dev/null || true

# Capacitor runtime + plugin JS (for native iOS deep-linked OAuth).
# These IIFEs register window.Capacitor and window.Capacitor.Plugins.* — we
# load them via <script> tags from index.html. capacitor.js MUST come first.
mkdir -p "$OUT/cap"
cp node_modules/@capacitor/core/dist/capacitor.js "$OUT/cap/capacitor.js" 2>/dev/null || true
cp node_modules/@capacitor/browser/dist/plugin.js "$OUT/cap/capacitor-browser.js" 2>/dev/null || true
cp node_modules/@capacitor/app/dist/plugin.js "$OUT/cap/capacitor-app.js" 2>/dev/null || true
cp node_modules/@capacitor/haptics/dist/plugin.js "$OUT/cap/capacitor-haptics.js" 2>/dev/null || true

echo "Built $OUT/ — $(du -sh "$OUT" | awk '{print $1}') total"
ls "$OUT" | head -20
