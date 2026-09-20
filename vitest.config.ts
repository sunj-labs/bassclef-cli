import { defineConfig } from 'vitest/config';

// UTC ISO timestamp with millisecond precision, colons+dots swapped for hyphens
// (per RFC-0006 Z4 fold — filesystem-safe + lexicographically sortable).
// Per bassclef-cli#169 — vitest emits JSON per run for later aggregation via
// scripts/aggregate-test-runs.sh; state/events/test-runs/ is gitignored.
const runTimestamp = new Date().toISOString().replace(/[:.]/g, '-');

export default defineConfig({
  test: {
    include: ['tests/**/*.test.ts'],
    testTimeout: 10000,
    reporters: ['default', 'json'],
    outputFile: `state/events/test-runs/${runTimestamp}.json`,
    // These tests spawn the compiled CLI. Build must run before test.
    // We do NOT set globalSetup to auto-build — that would hide build
    // failures behind test failures. Run `npm run build && npm test`
    // explicitly, per the split-mechanism discipline in Evil Martians'
    // 2026 guide (bet L98).
  },
});
