---
tier: lite
slug: 2026-09-21c-smoke-drive-riff
scope: "Epic #199 Story 1 — scripts/smoke-drive-riff.sh"
mode: light
lenses: [alistair-cockburn, andreas-zeller, michael-feathers]
date: 2026-09-21
always_fire_matched: false
branch: feat/199-smoke-drive-riff
---

# Pre-mortem risk ledger — smoke-drive-riff

Scope: ship `scripts/smoke-drive-riff.sh` modeled on `scripts/smoke-drive-onboard-repo.sh`. Fires `/riff` via `claude -p` in a fresh scratch dir inside the Docker cold-adopter harness. Asserts HTML mock variants land at `docs/prototypes/YYYY-MM-DD-riff-<slug>-variant-N/index.html`. Handles Playwright MCP absence.

## Sources read

- `~/.claude/skills/riff/SKILL.md` — full body; noted Playwright BLOCK requirement + tier degrade tension
- `scripts/smoke-drive-onboard-repo.sh` — template (142 lines)
- `harness/docker/entry.sh` L374-391 — V2 Step 6 wire-in point for onboard-repo
- Epic #199 body — Story 1 acceptance list

## Lens: Alistair Cockburn — walking skeleton

**Assumed failure:** The drive shipped as an atomic unit but the harness wiring path never got exercised end-to-end. The drive works in isolation. It exits cleanly on a mock `/riff`. When wired into `harness/docker/entry.sh` Step 7, the environment lacks something the drive needed — the CI runner has no HOME, or ADOPTER_HOME is unset, or the Docker layer added a permission the drive did not expect.

Risks:

1. **HOME unset in the Docker layer** — scratch dir path resolution defaults to `/tmp` per the `${HOME:-/tmp}/riff-test` idiom. `/tmp` is writeable but the harness may not clean it.
2. **`claude` binary in Docker uses a different PATH than the drive expects** — CLAUDE_BIN default `claude` fails; needs an env override at wire-in.
3. **The drive works locally but the harness Step 7 wire-in reads OUT_ROOT differently** — capture file lands in a place `smoke-report` does not aggregate.
4. **Timeout of 240s is too short** — `/riff` runs 5 sub-steps (interpret-input + luminary picker + author 3 mocks + gallery + visual-review). Real runs may hit 300s+.
5. **Exit code semantics diverge from the sibling** — onboard-repo maps 142 → 5 (timeout). Drive uses different codes and harness reports the wrong bucket.

## Lens: Andreas Zeller — hypothesis-driven assertion

**Assumed failure:** The drive shipped an assertion that could not falsify. The check was "HTML file exists somewhere under docs/prototypes/" but a stub HTML from a prior test run was already there. Green flag was theatrical — the test could not fail.

Risks:

1. **Assertion reads pre-existing files** — glob matches leftover state from a prior run. Fresh scratch cures this but the harness may not always reset.
2. **Assertion glob too broad** — matches anything under `docs/prototypes/**/*.html`. A stray file from a different skill trips the pass.
3. **No characterization on file content** — an empty HTML file (0 bytes) passes existence check. Better: assert non-empty AND contains `<h2>` naming a luminary (per `/riff` SKILL L77).
4. **Playwright BLOCK path is not distinguished from clean pass** — if `/riff` BLOCKs on Playwright before authoring any HTML, exit is non-zero; drive exits 3 (assertion). Should map to a distinct code so harness reports environment issue, not skill regression.
5. **No falsification test in Tier 0** — the drive script lands without a test that fires it against a FIXTURE where /riff produces zero output. Drive would pass its own tests without proving the assertion is real.

## Lens: Michael Feathers — characterization tests

**Assumed failure:** The drive shipped without a characterization test. It was verified once manually. When the shape of `/riff`'s output changes (a future SKILL update moves variant paths or renames the `<h2>` tag), the drive silently passes or fails on the wrong signal.

Risks:

1. **No Tier 0 test spawns the drive against a known-good fixture** — regressions to the drive script itself land uncaught.
2. **No test spawns the drive against a Playwright-block fixture** — the graceful-degrade path is not pinned.
3. **The drive's assertion is coupled to `/riff` SKILL body language ("<h2> naming the lens")** — if the SKILL body changes wording, the drive breaks. Should be a shared contract, not a duplicated string match.
4. **Harness wiring change is not covered by a test** — a Step 7 rename or reorder is invisible until CI runs.

## Top 5 risks — pick + owner + mitigation

| # | Severity | Lens | Risk | Owner | Mitigation |
|---|---|---|---|---|---|
| R1 | **HIGH** | Zeller | Assertion could-not-falsify because stub HTML from prior run stays behind. | Drive's `rm -rf` scratch dir at start (fresh state per run, matches onboard-repo template). | Fresh scratch dir on every run. Assert files inside `$SCRATCH_DIR/docs/prototypes/`, not repo-wide. |
| R2 | **HIGH** | Cockburn | Wire-in path in `harness/docker/entry.sh` Step 7 breaks on runner env quirks (HOME, CLAUDE_BIN, OUT_ROOT). | Wire-in step author (Story 5 of #199). | Copy the wire-in shape from Step 6 (onboard-repo) verbatim. Preserve every env plumbed to onboard-repo. |
| R3 | **HIGH** | Zeller | Playwright-block path exits same code as assertion-fail. Harness cannot tell environment-degraded from skill-regression. | Drive exit code map. | Reserve exit 6 for "expected environment miss" (Playwright absent). Grep the capture for Playwright / MCP tokens; if present, exit 6. Exit 3 stays for real assertion fail. |
| R4 | **MED** | Feathers | Assertion checks HTML file exists but not content. Empty file passes. | Drive assertion body. | Assert file is >100 bytes AND contains `<h2>` heading. Cite `/riff` SKILL L77 in comment. |
| R5 | **MED** | Cockburn | Timeout 240s too tight for real 5-step `/riff` run. False-timeout in production. | Drive's default `RIFF_TIMEOUT_SEC`. | Set default 300s. Note in header. Extend later per Story 6 verification results. |

## Scope-cut candidates

- **Ship without Playwright-aware exit code (R3).** Cost: harness cannot tell environment-degraded from skill-regression on first-run failures. **Reject** — R3 is HIGH; two exit codes cost 3 lines of shell.
- **Ship without characterization test (Feathers).** Cost: regressions in `/riff` output shape break silently. **Reject in principle** — but characterization test scope for this session is small (single test spawning the drive against a fixture scratch dir). Ship.

## Monitoring signals (post-ship)

- Next `harness/docker/docker-smoke.yml` run on PR: Step 7 fires + reports pass/fail per drive
- Zero false-fail cycles across 5 tarball runs (Story 6 verification)
- Grep the report format: is exit 6 (env) distinguishable from exit 3 (assertion) at the smoke-report layer?

## Refs

- Epic #199 body
- `~/.claude/skills/riff/SKILL.md` L96-100 — "MUST screenshot every variant via Playwright MCP. BLOCK if MCP not enabled" — the tension this ledger surfaces
- `~/.claude/skills/riff/SKILL.md` L38-40 — tier gate; lite gets graceful degrade for `/visual-review` + `/stage`; unclear whether Playwright is inside or outside that degrade
- `scripts/smoke-drive-onboard-repo.sh` — the template
- `harness/docker/entry.sh` L374-391 — wire-in shape
- @luminary alistair-cockburn — walking skeleton
- @luminary andreas-zeller — hypothesis test
- @luminary michael-feathers — characterization
