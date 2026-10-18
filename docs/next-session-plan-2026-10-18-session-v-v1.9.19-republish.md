---
session_id: 2026-10-18-session-v
project: bassclef-cli
status: planned
tags: [v1.9.19, republish, v1.11.1, cold-adopter, peer-coord, cli-447-pilot]
peer_msg_ref: bassclef-upstream-c7 msg_id (received post-Session U close)
---

# Next-session plan — Session V: v1.11.1 republish + peer coord asks

## Context

Session U closed clean. @thebassclef/lite@1.9.18 LIVE on npm bundling bassclef v1.11.0. Chronicle at `docs/chronicle/2026-10-18-session-u-v1-9-18-release-cold-adopter-defects.md`.

Peer `bassclef-upstream-c7` shipped bassclef v1.11.1 within hours of Session U close. v1.11.1 cures 5 of 5 upstream defects filed from the cold-adopter smoke:

- **upstream#2253** (pre-push-shellcheck install-written-paths consultation + state-marker bypass) → PR #2258
- **upstream#2254** (SKIP bypass via state marker) → same PR
- **upstream#2255** (OAuth preflight uses `claude-oauth-probe.sh` with gtimeout/shim fallback) → PR #2259
- **upstream#2257** (auto-save probes `$CLAUDE_PROJECT_DIR/.claude/hooks/` first) → same PR
- **upstream#2256** (Concise preamble + default flipped Y → n) → PR #2260
- Trailing housekeeping — PR #2261 (~ → $HOME)

Peer ran full /loop (temperance + luminary + pre-mortem light + Beck RED-first + /verify + /architect-review fork + CI loop). 86 Tier 0 tests GREEN across the 4 cures.

Release URL: https://github.com/sunj-labs/bassclef/releases/tag/v1.11.1

## Four peer asks

### 1. Republish @thebassclef/lite@1.9.19 bundling v1.11.1 (MUST)

Fresh cycle required because publish is operator-gated per `CLAUDE.md`. Earlier "permission to publish" was scoped to v1.9.17/v1.9.18.

**Steps**:

- Switch to main; fast-forward
- `git checkout -b feat/v1.9.19-bump-v1.11.1`
- Temperance + ADR-deviation + decompose markers
- Edit `.bassclef-pin`: `v1.11.0` → `v1.11.1`
- Run `node scripts/sync-bassclef-version.mjs` (populates `bassclef-version.json` at repo root from sibling `~/src/sunj-labs/bassclef/bassclef-version.json`)
- Edit CHANGELOG `[Unreleased]` block with the 4 upstream cures summary
- `npm run bump patch` (1.9.18 → 1.9.19)
- `npm run build && node scripts/prepublish-bundle-substrate.mjs`
- Verify `dist/lite/bassclef-version.json` reads v1.11.1
- Local test matrix: vitest + typecheck + install harness + nuke-and-install tier-0 + pack+andon + 2 new Tier 0 (bassclef-pin + sync-bassclef-version) + full shell tier
- Commit single atomic + push + open PR
- Watch CI (expect all 3 checks GREEN; docker-smoke will exercise the fixed /onboard-repo prompts + oauth probe)
- When CI green: merge → tag v1.9.19 → create GitHub release → publish workflow fires
- Watch publish; expect no andon trip (v1.11.1 has the oauth probe + onboard preflight; andon-list hasn't changed)
- Post-publish verify tarball `dist/lite/bassclef-version.json` reads v1.11.1

**Time budget**: ~80-120 turns per the v1.9.18 cycle baseline (that cycle hit a mid-flight andon trip; v1.9.19 shouldn't; range accounts for either).

### 2. Fold cli#444 cure into v1.9.19? (OPERATOR CHOICE)

cli#444 — `nuke-and-fresh-install.sh --purge-adopter` silently proceeds past `delete_repo` scope failures.

**Two options**:

- **a. Fold**: cure the script in the same cycle. Scope: ~30-60 turns. Pro: fewer release cycles. Con: scope creep.
- **b. Defer**: ship v1.9.19 pin-only; cli#444 rides v1.9.20 or later. Pro: fast confirmation that upstream cures land. Con: more release cycles.

**Recommend b** — v1.9.19 is a bundle refresh. cli#444 is a tooling bug for operators, not an adopter contract. Separate cycle keeps the shape of each release clean.

### 3. Cold-adopter smoke on `giveisusfree` post-republish (MUST per adopter-contract)

Peer offered to coordinate. After v1.9.19 is live on npm, operator (or peer-coord with operator-approval) runs:

```bash
curl -sSL https://raw.githubusercontent.com/sunj-labs/bassclef-cli/main/scripts/nuke-and-fresh-install.sh \
  | bash -s -- --purge-adopter
```

Expected: all 4 upstream cures land clean. Specifically:

- `/onboard-repo` OAuth probe reports OAUTH_OK on macOS (upstream#2255 cure).
- Phase 2.7 Concise prompt carries preamble + default N (upstream#2256 cure).
- Auto-save installer succeeds without `~/src/bassclef` sibling (upstream#2257 cure).
- First `git push` after `bassclef init` passes shellcheck (upstream#2253 cure).

If any class still fires, file follow-up ticket + flag to peer.

### 4. cli#447 pre-publish gate pilot (STRATEGIC — operator schedules)

Standing peer offer to pilot the mechanical pre-publish gate from a fixture adopter when operator kicks it off. Distinct from Session V scope; coordinate separately. ADR-012 (open PR #449) is the design doc.

**Suggested sequence** (not binding):

- Merge ADR-012 PR #449 first (status proposed → accepted)
- Then: cli#445 (macos-latest workflow) + cli#446 (scoped-PAT variant) land as prerequisites
- Then: cli#447 (mechanical gate) lands with peer-side pilot run

Rough time budget: 3 release cycles over several sessions. Not Session V scope.

## Session V entry state

Branch: `main` at `31d2c16` (session-end archive commit). Working tree clean.

Open PRs:

- PR #449 (ADR-012 cold-adopter smoke pre-publish gate; proposed; awaits review+merge).

Open tickets:

- cli#441 (bump-version postcondition bug — pre-existing; small quick-fix candidate; could ride Session V)
- cli#444 (nuke-and-fresh-install silent delete — see Ask 2)
- cli#445, cli#446, cli#447, cli#448 (ADR-012 implementation triangle; strategic)
- upstream#2253-#2257 (CLOSED by v1.11.1; close out verification after Session V republish confirms adopter path)

## Luminary pins for Session V

- **Lead: Linus Torvalds** — ship the cures to adopters. v1.11.1 content has been waiting hours; publish latency extends the window where adopters hit the known-cured bugs.
- **Supporting: Tony Hoare** — pin precondition + bundle postcondition contract (same shape as Session U).
- **Supporting: Michael Nygard** — stability pattern (release cycle shape mirrors Session U; proven path).

## Decision points queued for operator

- Fold cli#444 or defer? (Ask 2)
- Fold cli#441 bump-postcondition quick-fix or defer?
- Schedule cli#447 pilot now or after v1.9.19 ships?
- Keep Session V scope lean (just Ask 1 + Ask 3) OR fold in cli#444 + cli#441?

## Reference artifacts

- Session U chronicle: `docs/chronicle/2026-10-18-session-u-v1-9-18-release-cold-adopter-defects.md`
- Session U closeout commit: `d7085fa` (chronicle + whereami) + `31d2c16` (rescue archive)
- Peer v1.11.1 release: https://github.com/sunj-labs/bassclef/releases/tag/v1.11.1
- ADR-012 PR: https://github.com/sunj-labs/bassclef-cli/pull/449
- All upstream cure PRs: #2258, #2259, #2260, #2261 at `sunj-labs/bassclef-upstream`
