---
tier: upstream
authoring_luminaries:
  primary: michael-feathers
  supporting:
    - linus-torvalds
    - alistair-cockburn
    - michael-nygard
---

# Pre-mortem light — Session G — v1.7.1 bundle sync + driver flips + cli release

**Mode:** light (3 lenses × 5-8 risks per Klein workshop shape).

**Scope under pre-mortem:** Pull bassclef v1.7.1 pin at `.github/workflows/publish.yml` L136/L151/L152/L281 → regen `dist/lite/` → verify 5 Session F drivers flip RED → GREEN-UNEXPECTED → one PR per driver flipping assertion semantics → cli release cascade bump v1.9.9 → v1.9.10 → publish via npm Touch ID.

## Lens 1 — Michael Feathers (characterization risks)

| # | Risk | Fold |
|---|---|---|
| F1 | Semantics flip inverts assertion but leaves `RED-CONFIRMED` tag string unchanged; reviewer confusion + CI label mismatch. | Rename `RED-CONFIRMED` → `GREEN-CONFIRMED` + update driver file top-comment in the same commit as the assertion swap. |
| F2 | Flip authored without re-reading `dist/lite/` post-bundle; characterization skips. | Run each driver after `npm run bundle` BEFORE flipping. Expect RED → GREEN-UNEXPECTED (exit 1). Flip only after that signal lands. |
| F3 | One driver stuck in RED after bundle because upstream cure is settings.json-only + bundle doesn't carry it. Plan doc L41 names cli#329 as this exact case. | Verify empirically per driver. If one stays RED, close its ticket via separate path (no flip; comment-only resolution). |
| F4 | CI runs flipped drivers against old bundle on main pre-merge → false RED on CI. | Serialize: bundle sync PR merges first. Flip PRs only after bundle is on main. |
| F5 | Fixture-content shift in v1.7.1 breaks driver grep anchors (cure landed in different file). | Driver reads shipped `dist/lite/.claude/*` with grep anchors; verify anchor target exists post-bundle before flipping. |
| F6 | Semantics flip renames exit codes: `exit 0 = cure present` → `exit 0 = cure present` (no change) OR `exit 1 = cure missing` (regression). Driver harness downstream greps on exit code. | Keep exit-code semantics stable (0 = pass, 1 = fail). Flip only the match-count direction. Harness contract unchanged. |

## Lens 2 — Linus Torvalds (adopter contract risks)

| # | Risk | Fold |
|---|---|---|
| L1 | Release PR body missing `Closes #NNN` for one of 7 tickets → orphan ticket after release. | Cross-check driver filenames against ticket list before opening release PR. Format `Closes #N` one per line. |
| L2 | `publish.yml` L151 Nygard assertion fires on tag mismatch → publish halts. | Working as designed. Proceed only when `gh api repos/sunj-labs/bassclef/git/refs/tags/v1.7.1` resolves. SHA `a7951b50` already confirmed. |
| L3 | `npm run bump patch` touches 4 files per memory `feedback_use_npm_run_bump_not_hand_edit` (package.json + src/index.ts + README + CHANGELOG); hand-editing one leaves others stale. | Use `npm run bump patch`. Do not hand-edit version strings. |
| L4 | npm publish Touch ID fails or times out → session stalls mid-cascade. | Operator at keyboard for Touch ID. Retry if timeout. Memory `feedback_npm_2fa_is_touch_id` names the mechanism. |
| L5 | `@thebassclef/lite@1.9.10` publishes but `latest` tag doesn't update → adopters install stale. | Default npm publish sets `latest`. Verify via `npm view @thebassclef/lite dist-tags` after publish. |
| L6 | v1.7.1 cures bundled but one adopter-visible banner persists (cold-adopter smoke would catch). | Deferred to post-release smoke on cold-adopter Mac profile; not blocking Session G. File as follow-on if seen. |

## Lens 3 — Alistair Cockburn (walking-skeleton risks)

| # | Risk | Fold |
|---|---|---|
| C1 | Five flip PRs stacked on one branch → rollback not atomic. Plan doc L95 warns against this. | One branch + one PR per flip. 5 separate feat branches. |
| C2 | Flip PR touches driver file + unrelated doc edit → scope creep. | Minimal diff per flip PR. Only the driver file + its paired marker refresh. |
| C3 | Bundle-sync verification pass fires but one driver passes RED by coincidence (grep match on wrong file). | Each driver's grep anchor is file-path-specific per Session F chronicle. Re-verify by reading anchor path first. |
| C4 | Semver pick wrong — minor instead of patch. | No public API change in Session G. `npm run bump patch` is correct. |
| C5 | Operator interrupts mid-cascade (Touch ID at the wrong moment) → partial release state. | Session-end marker catches partial state. Resume path: finish release PR, bump, tag, publish on next session if interrupted. |

## Top folds — apply BEFORE first edit

- **F1** — rename tag + comment in the flip commit. Mandatory.
- **F4** — serialize bundle sync → flip. Mandatory.
- **L2** — publish halt is working as designed. Mandatory signal interpretation.
- **L3** — use `npm run bump patch`. Mandatory. Per memory `feedback_use_npm_run_bump_not_hand_edit`.
- **C1** — one PR per flip. Mandatory per plan doc L95.

## Sources read

- `docs/next-session-plan-2026-10-05-session-g-v1-7-1-bundle-sync.md` (L1-106)
- `docs/whereami.md` L1-24 (PRIMARY queue + Session F recap)
- `.github/workflows/publish.yml` L136, L151-152, L281 (pin location)
- `scripts/tests/smoke-drive-adopter-*.test.sh` (5 Session F drivers on disk)
- v1.7.1 release page `https://github.com/sunj-labs/bassclef/releases/tag/v1.7.1` (gh API confirmed tag SHA `a7951b50`)
- Memory `feedback_use_npm_run_bump_not_hand_edit`, `feedback_npm_2fa_is_touch_id`, `feedback_git_tag_collision_across_rename`

## Luminary consult

- **Lead:** @luminary michael-feathers — the flip IS characterization-complete signal (per plan doc L26). Each driver's RED → GREEN closes a thread Session F opened.
- **Supporting:** @luminary linus-torvalds — adopter contract. Bundle sync reaches adopter machines. Release honesty matters.
- **Supporting:** @luminary alistair-cockburn — same walking-skeleton pattern. One PR per driver flip.
- **Supporting:** @luminary michael-nygard — publish.yml L151 tag-mismatch assertion is a stability pattern; respect its halt signal.
