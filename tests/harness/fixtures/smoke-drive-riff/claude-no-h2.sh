#!/usr/bin/env bash
# Mock claude — no-h2 sub-class.
# Writes a >100 byte HTML file WITHOUT an <h2>. Simulates SKILL body drift
# where /riff no longer tags variants with luminary lens.
set -euo pipefail
DIR="docs/prototypes/2026-09-21-riff-marketing-hero-variant-1"
mkdir -p "$DIR"
cat > "$DIR/index.html" << 'HTML'
<!DOCTYPE html>
<html><head><title>Variant</title></head><body>
<h1>Ship</h1><p>Prose prose prose prose prose prose prose prose prose prose prose prose.</p>
</body></html>
HTML
echo "/riff mock: wrote HTML without h2"
exit 0
