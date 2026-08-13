// @thebassclef/core — programmatic API surface.
//
// @requirement R-NPM-007
//
// Semver contract for 0.x. The only export today is `version: string`.
// Consumers reading it get the running package version — useful for
// logging, feature gating on the adopter side, and cold-adopter harness
// checks. This constant is kept in sync with package.json by
// scripts/bump-version.mjs; tests/version-sync.test.ts pins the invariant.
//
// This surface is intentionally minimal. Every additional export becomes
// a semver commitment: removing it after 1.0 is a breaking change per
// ADR-031 (we-don't-break-adopters). Add exports only when a real
// consumer needs them — no speculative surface.

export const version = '0.0.2' as const;
