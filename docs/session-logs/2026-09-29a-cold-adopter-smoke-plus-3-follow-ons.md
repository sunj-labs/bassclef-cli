# Session log — 2026-09-29a

## What shipped

Three PRs merged in scope, one npm release published, three follow-on tickets filed:

- **PR #288** — `feat: scripts/nuke-install.sh — one-command cold-adopter fresh install` (squash `0b845dc`). Six-step cold install script + 14 Tier 0 tests + brief Cockburn UC. Full ceremony pre-code (temperance + luminary Cooper lead + Feathers supporting + ADR-deviation ADR-honored).
- **PR #289** — `chore: rename nuke-install.sh → nuke-and-fresh-install.sh` (squash `b2cafc8`). Operator-driven rename for clarity. `git mv` on three files + internal ref substitution. 14/14 tests GREEN post-rename.
- **PR #285 + #286** — cli#281 statusline rich impl (merged earlier in session 2026-09-28a; recorded here for completeness).
- **npm release** — `@thebassclef/lite@1.9.8` published. Sigstore transparency log 3006465231. Full test suite 498/498 GREEN locally + in CI. No Touch ID needed — `npm-publish` env has zero required reviewers per cli#279 (open).

## What was decided

**v1.9.8 stays on `latest` despite substrate version drift.** Adopter-facing surface is correct — statusline reads what actually shipped. Drift is a maintainer-visible labeling mismatch, filed as cli#290. Waiting on upstream cure before next cli release.

**cli-side files upstream-mirror-candidate tickets rather than opening bassclef-upstream tickets directly.** Cli session lacks direct write access to the private upstream repo. Peer session `bassclef-upstream-35` picks up mirrors on next coordination. Message sent to peer this session naming cli#284, cli#290, cli#291 for overnight cure.

**Nuke-install script filename** — operator ask: `nuke-and-fresh-install.sh` reads what it does (both a nuke AND a fresh install). Renamed PR #289 shipped ~15 minutes after PR #288 with zero adopter reach on the old name.

## Cold-adopter smoke — cli#281 cure confirmed end-to-end

Operator ran the one-command install on the cold-adopter-1 Mac profile. Screenshot from the session:

- Statusline read: `𝄢 bassclef.dev · Opus 5.5 · bassclef-smoke-test · v1.6.4 · 30%`
- No `?` fallback — rich impl file resolved via dispatcher path 3
- `/onboard-repo`, `/riff`, `/launch` all dispatched cleanly with capability-probe + tier-check + branch guards
- Skills refused to write directly to main; each proposed `feature/` or `chore/` branches

**cli#281 shipped as designed.** Cold adopter sees a real version, not `?`.

## Follow-on tickets filed this session

- **cli#284** — `/whereami` auto-update signal misreads user-scope substrate inheritance. cli-side reader reads `.bassclef-source.json`; bassclef-cli inherits substrate via user-scope sync per CLAUDE.md L22-25 and has no such file. Signal reads OFF on cli even though substrate updates every session. Adopter-source; mirror candidate for bassclef-upstream.
- **cli#290** — v1.6.5 git tag on public bassclef ships v1.6.4 in `bassclef-version.json`. Publish workflow pin at `ref: v1.6.5` resolves to a commit whose version file wasn't bumped. Three npm tarballs (1.9.6, 1.9.7, 1.9.8) all carry `v1.6.4` byte-for-byte. Root cause upstream. Preferred cure: re-tag v1.6.5 at post-bump commit or ship v1.6.6.
- **cli#291** — statusline dispatcher hardcodes `$SCRIPT_DIR/bassclef-statusline.sh` as path 3 for rich impl. Cli-side init has to match that filename exactly or feature silently falls back to `?`. Substrate-evolution candidate: swap for config file OR `--rich-impl PATH` arg. Mirror candidate for bassclef-upstream.

## Peer coordination

**Sent to `bassclef-upstream-35`**: message naming cli#290 for overnight cure, with cross-refs to cli#284 and cli#291 for context. Named preferred cure (re-tag OR v1.6.6) and confirmed cli-side does nothing until upstream lands the fix.

## Gates fired

- `/temperance` — on nuke-and-fresh-install branch + release-v1.9.8 branch + rename branch. Markers committed.
- `/luminary` — Cooper lead + Feathers supporting on nuke-and-fresh-install branch.
- `/pre-mortem` — skipped per scope class (adopter-facing helper script; no substrate change).
- `/loop` iteration 1 GREEN on both PR branches.
- ADR-deviation marker — outcome ADR-honored (no ADR governs adopter-facing helper scripts under `scripts/`).
- `/verify` — full suite 498/498 GREEN at both PR merge points + after rename.
- **cli#281 cold-adopter verification** — this session's `/verify` extension. Cure works in production on a truly cold profile.

## Sources read

- `docs/whereami.md` — session-start orientation (last updated 2026-09-28T12:10:00Z)
- `scripts/smoke-one-shot.sh` L69, L118-123, L133-137, L144-166 — smoke chain shape + version validator
- `scripts/nuke-and-fresh-install.sh` (new) + `scripts/tests/nuke-and-fresh-install.test.sh` (new)
- `scripts/prepublish-bundle-substrate.mjs` L38-84 — sibling root resolution
- `.github/workflows/publish.yml` L74-140 — publish pipeline + substrate checkout pin at `v1.6.5`
- `~/src/sunj-labs/bassclef` `git show v1.6.5:bassclef-version.json` + `git rev-parse main v1.6.5` — root cause verification
- Three npm tarballs (`@thebassclef/lite@1.9.6/1.9.7/1.9.8`) — bundled substrate version check via `npm pack` + `tar -xzf`
- `presence/cli/bassclef-statusline.dispatcher.sh` L18 + L76-78 (upstream substrate) — dispatcher lookup contract
- `src/lib/install-statusline.ts` L88-94, L239-262 — cli-side coupling + migration helpers

## Turn count

~50 turns end-to-end. Two PR merges (#288 script + #289 rename) + one npm release (v1.9.8 via `gh release create`) + three ticket filings (cli#284/290/291) + one peer message.
