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

    coverage: {
      // istanbul provider — compatible with subprocess-spawning tests (runCli).
      // v8 sets NODE_V8_COVERAGE which propagates to children and breaks their exit codes.
      // Instrumentation cost is higher but tests stay green. Per architect-review 2026-09-20 M3.
      provider: 'istanbul',
      reporter: ['text', 'json-summary', 'html'],
      include: ['src/**/*.ts'],
      exclude: [
        'src/**/*.test.ts',
        'src/**/*.d.ts',
        'src/index.ts', // CLI dispatcher; tested via spawn, not unit
      ],
      // Baseline thresholds — set at current actuals (2026-09-20) minus a small margin.
      // Actuals: lines 41.22 / functions 50 / branches 27.66 / statements 39.17.
      // Raise these as coverage grows. Follow-on to backfill migrate.ts + sync.ts + sync-argv.ts.
      // See docs/architecture/reviews/2026-09-20.md § M3.
      thresholds: {
        lines: 40,
        functions: 45,
        branches: 25,
        statements: 35,
      },
      // Fail the run when coverage drops below threshold (Zeller falsification framing).
      // Adopter can bypass locally via --coverage.thresholds.lines=0 if needed.
      // CI enforces the threshold as a merge gate.
    },
  },
});
