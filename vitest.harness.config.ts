import { defineConfig } from 'vitest/config';

// Separate config for the install harness — different timeout + scope from
// the source tests at tests/**/*.test.ts. Harness spawns npm subprocesses
// (npm pack + npm install + bassclef init + bassclef sync); each subprocess
// takes seconds not milliseconds. Per ADR-006 the harness lives at harness/
// and never ships in the @thebassclef/core npm tarball (package.json files
// field enforces the whitelist).
//
// Discipline — no globalSetup. Build must have already produced dist/ before
// harness runs, same rule as vitest.config.ts. Harness verifies the built
// artifact; auto-building here would hide build failures behind harness
// failures.

export default defineConfig({
  test: {
    include: ['harness/**/*.test.ts'],
    testTimeout: 90000, // 90s per test — accommodates npm pack + npm install + 3 CLI invocations
    hookTimeout: 30000, // 30s for beforeEach / afterEach (Fixture cleanup)
    // Serial execution — parallel harness runs would collide on npm cache
    // if any shared state leaks. Fixture scoping avoids this in theory but
    // serial is the safer default per Nygard fail-safe. Revisit if run
    // time becomes a problem.
    pool: 'forks',
    poolOptions: {
      forks: {
        singleFork: true,
      },
    },
  },
});
