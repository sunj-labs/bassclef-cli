#!/usr/bin/env bash
# Mock claude — empty-html sub-class.
# Writes a zero-byte HTML file (or one under the 100-byte floor).
# Simulates author-mid-write abort. Drive should exit 3 FAIL:empty-html.
set -euo pipefail
DIR="docs/prototypes/2026-09-21-riff-marketing-hero-variant-1"
mkdir -p "$DIR"
: > "$DIR/index.html"
echo "/riff mock: wrote empty file"
exit 0
