#!/usr/bin/env bash
# Mock claude — happy path.
# Ignores argv beyond the flag; writes one HTML variant to docs/prototypes/
# and exits 0. Mirrors /riff's rule that variants land at
# docs/prototypes/YYYY-MM-DD-riff-<slug>-variant-N/index.html.
set -euo pipefail
DIR="docs/prototypes/2026-09-21-riff-marketing-hero-variant-1"
mkdir -p "$DIR"
cat > "$DIR/index.html" << 'HTML'
<!DOCTYPE html>
<html>
<head><title>Marketing hero variant 1</title></head>
<body>
<h2>Bill Buxton — sketch, iterate, revise</h2>
<div class="hero">
  <h1>Ship earlier. Learn faster.</h1>
  <p>Marketing landing hero variant 1 authored by /riff mock.</p>
</div>
</body>
</html>
HTML
echo "/riff mock: wrote variant 1 to $DIR/index.html"
exit 0
