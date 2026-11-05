import { defineConfig } from 'vitest/config';

// Separate config for the install harness — different timeout + scope from
// the source tests at tests/**/*.test.ts. Harness spawns npm subprocesses
// (npm pack + npm install + bassclef init + bassclef sync); each subprocess
// takes seconds not milliseconds. Per ADR-006 the harness lives at harness/
// and never ships in the @thebassclef/core npm tarball (package.json files
// field enforces the whitelist).
//
// Discipline — no auto-BUILD. Build must have already produced dist/ before
// harness runs, same rule as vitest.config.ts. The harness verifies the built
// artifact; compiling src/ here would hide build failures behind harness
// failures.
//
// The globalSetup below does not cross that rule (cli#463 drew the same
// distinction for the source suite). It never compiles src/; it asserts
// dist/cli.js exists and fails naming the missing build. What it builds is
// the dist/lite/ substrate bundle, which is the thing being packed.
//
// It is here because the harness had never once passed. `npm run build`
// empties dist/ and takes dist/lite/ with it; the bundler is wired to
// `prepublishOnly`, which npm runs on `npm publish` and never on `npm pack`.
// So the harness packed a tarball with no substrate and `bassclef init`
// exited 4 on a missing wiring manifest — six releases running, from
// v1.9.15 to v1.9.20. One owner for the bundle fixes both suites.

export default defineConfig({
  test: {
    include: ['harness/**/*.test.ts'],
    globalSetup: ['./tests/setup/ensure-lite-fixture.ts'],
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
