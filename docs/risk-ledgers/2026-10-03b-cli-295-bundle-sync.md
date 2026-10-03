---
title: Pre-mortem light — cli#295 bundle sync via commit SHA pin
date: 2026-10-03
scope: cli#295 bundle sync against upstream commit 633cc2bb (release-2026-10-03-89ceaa15)
lenses:
  lead: linus-torvalds
  supporting: [michael-nygard, saltzer-schroeder]
mode: light (3 lenses × 5 risks)
---

# Pre-mortem light — cli#295 bundle sync

Scope: bump `.github/workflows/publish.yml` L136 + L281 from `ref: v1.6.5` to `ref: 633cc2bb` (upstream release PR #1523 squash). Build + bundle v1.9.9. Publish via workflow + Touch ID.

## Linus (adopter contract — do not break userspace)

| # | Risk | Severity | Fold? |
|---|---|---|---|
| L1 | SHA pin sets precedent — future readers copy the shape when semver would do. | med | F1 — add a comment in publish.yml naming the one-off + cite follow-on cli ticket. |
| L2 | Adopters pulling cli v1.9.9 see bundled substrate newer than any upstream semver tag; version provenance looks odd. | low | release notes carry the SHA + cite upstream PR #1523. |
| L3 | Statusline + version checks that compare cli bundle vs upstream tags show false drift. | low | document SHA/tag divergence in CHANGELOG. |
| L4 | If upstream cuts `v1.6.7` later at a different commit than `633cc2bb`, cli bundle diverges from the tag. | low | follow-on PR when `v1.6.7` lands either confirms match or bumps pin again. |
| L5 | Memory `feedback_git_tag_collision_across_rename` — SHA pin avoids future tag-collision class but introduces its own non-semver reference. | low | acknowledged in ledger; not actionable tonight. |

## Nygard (stability pattern — observable failure modes)

| # | Risk | Severity | Fold? |
|---|---|---|---|
| N1 | CI `validate-tag.mjs` may reject non-semver refs if strict pattern check fires. | high | F2 — read `scripts/validate-tag.mjs` BEFORE pin edit; confirm it accepts SHA inputs OR gates only cli-side tag format. |
| N2 | Publish workflow Touch ID gate times out mid-session; operator AFK stalls cascade. | med | surface the gate timing to operator before dispatch. |
| N3 | Prepublish parity test may fail if `dist/lite/` byte-equality diverges from fresh clone at new ref. | med | run `npm run build && npm run prepublish-copy` locally first; verify sanitize + lib on disk BEFORE push. |
| N4 | Release-notes RCA shape change may break downstream parsers (unknown blast radius). | low | sample one parser (bassclef-web if applicable); mirror upstream PR #1523 body shape. |
| N5 | CI prepublish parity cycle takes multiple iterations if any shape miss. | low | Beck-style GREEN after one fix cycle acceptable; two cycles pause and re-anchor. |

## Saltzer-Schroeder (complete mediation — every ref checked)

| # | Risk | Severity | Fold? |
|---|---|---|---|
| S1 | Pin edit misses a third ref beyond L136 + L281. | high | F4 — `grep -nE "ref:" .github/workflows/publish.yml` BEFORE edit; map every ref match. |
| S2 | Hardcoded `v1.6.X` strings elsewhere in the repo need bumping too. | med | `grep -r "v1.6.5" --include="*.yml" --include="*.ts" --include="*.sh"` before PR. |
| S3 | actions/checkout `fetch-depth` setting may need adjustment for SHA fetch vs tag fetch. | low | check current fetch-depth; SHA refs usually work with fetch-depth: 0. |
| S4 | `BASSCLEF_SOURCE_TOKEN` scope may not allow arbitrary SHA ref access. | low | test token scope by local clone first OR fall back to a shallow fetch of specific SHA. |
| S5 | `prepublish-copy` script may hardcode an expected upstream tag format. | med | F3 — read `scripts/prepublish-copy.mjs` (or equivalent) BEFORE pin edit. |

## Top folds — pre-code checklist

- **F1 (L1):** publish.yml comment above each pin line names the SHA, cites upstream PR #1523, and names the follow-on cleanup ticket.
- **F2 (N1):** read `scripts/validate-tag.mjs` end-to-end before any pin edit.
- **F3 (S5, N3):** read `scripts/prepublish-copy.mjs` (or whichever script owns `dist/lite/` population). Confirm it tolerates SHA pins.
- **F4 (S1, S2):** grep publish.yml + whole repo for `v1.6.5` / `v1.6` ref strings. Map every hit before edit.

## Deferred (not folded tonight)

- L2 / L3 / L4 — downstream version-provenance concerns; release notes carry the SHA + cross-ref.
- N2 — Touch ID timing is operator attention; surface at execution.
- N4 — RCA shape sampling; cli release notes mirror upstream PR #1523 body shape directly.

## Risk-class summary

- high: N1, S1 (CI gate + ref coverage) → F2 + F4 fold mandatory.
- med: L1, N2, N3, S2, S5 → F1 + F3 + F4 cover.
- low: L2, L3, L4, L5, N4, N5, S3, S4 → acknowledged.
