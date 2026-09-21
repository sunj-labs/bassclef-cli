#!/usr/bin/env bash
# Mock claude — Playwright MCP absent path.
# Simulates /riff's L98 BLOCK: "MUST screenshot every variant via Playwright MCP. BLOCK if MCP not enabled."
# Writes to stderr and exits non-zero WITHOUT authoring any HTML.
set -euo pipefail
echo "/riff: BLOCK — Playwright MCP not enabled; cannot screenshot variants" >&2
echo "/riff: install Playwright MCP or run in an environment where it is available" >&2
exit 3
