#!/usr/bin/env bash
# Mock claude — MCP server absent (broader than Playwright-block).
# Tests F3 expanded token — `mcp` alone matches; F-AR-1 cure.
set -euo pipefail
echo "/riff: MCP server not connected — cannot dispatch screenshot subskill" >&2
exit 3
