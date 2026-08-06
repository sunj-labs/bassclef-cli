// @thebassclef/core — programmatic API surface.
//
// Semver contract for 0.x.
//
// The only export at 0.0.1 is `version: string`. Consumers reading this
// export get the running package version — useful for logging, feature
// gating on the adopter side, and cold-adopter harness checks (WU-6).
//
// This surface is intentionally minimal. Every additional export becomes
// a semver commitment: removing it after 1.0 is a breaking change per
// ADR-031 (we-don't-break-adopters). WU-2 and WU-3 add exports only when
// a real consumer needs them — no speculative surface.

export const version = '0.0.1' as const;
