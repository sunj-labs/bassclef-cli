# Session log — 2026-09-28a

## What shipped

Two PRs merged in scope:

- **PR #285** — `fix(cli-281): install rich statusline impl for cold adopters` (squash `01a0a31`).
  - `src/lib/install-statusline.ts` — added `handleRichImpl` + `report.rich` outcome + `isLegacyDispatcher` + `isLegacyStatuslineCommand` migration checks. Dispatcher install path moved to `~/.claude/bassclef-statusline-dispatcher.sh`. Rich impl lands at `~/.claude/bassclef-statusline.sh`.
  - `scripts/prepublish-bundle-substrate.mjs` L205 — new dispatcher command emitted into `dist/lite/.claude/settings.json`.
  - `src/commands/init.ts` — `maybeEmitStatuslinePlan` extended to report rich impl outcome.
  - `tests/statusline-install.test.ts` — 7 new rich impl assertions (Beck TDD; 498/498 GREEN after prepublish regen).
  - Ceremony markers committed: temperance + pre-mortem + luminary + adr-deviation + lead-lens sign-off.
  - PR body clarity gate caught `blast radius` → substituted to `impact` before push.

- **PR #286** — `chore: release v1.9.8 — cli#281 statusline rich impl install`.
  - `npm run bump patch` — v1.9.7 → v1.9.8 across package.json + src/index.ts + README.md + CHANGELOG.md.
  - CHANGELOG.md `[Unreleased]` populated with cli#281 Added/Changed/Fixed/Notes rows.
  - Release temperance marker committed.

## What was decided

- **v1.9.7 was already published for cli#282 SECURITY email swap** — discovered when `git ls-remote --tags` showed `v1.9.7` pointing at `010ba6a` (cli#282 merge). Per project memory `feedback_git_tag_collision_across_rename.md`, bumped forward to v1.9.8 rather than move a shipped tag.
- **Dispatcher content unchanged.** Pre-mortem R1.3 (BASSCLEF_SYNC_VERSION bump) marked not applicable — only the dispatcher's install path changed, not its content. Version bump lives with dispatcher content edits, which happen upstream in bassclef substrate.
- **Parity test surfaced a second-order gap.** `dist/lite/.claude/settings.json` carried the legacy statusLine command string; parity test caught the mismatch after install-statusline.ts moved to the new command. Cure landed in the same commit as the cli#281 fix — `scripts/prepublish-bundle-substrate.mjs` L205.

## What's still open

- **PR #286 CI in flight** — Docker cold-adopter smoke on v1.9.8 pending. Test + typecheck pending. Merge + tag push awaits GREEN.
- **v1.9.8 publish workflow** — will fire on tag push. Operator Touch ID gate at npm-publish environment.
- **Docker cold-adopter smoke on published v1.9.8** — will verify the cure end-to-end. If GREEN, `bassclef · ?` becomes `bassclef v1.6.5 · not synced` (or similar version-bearing fallback) on cold adopters.

## Gates fired

- `/temperance` — on both branches. Markers committed.
- `/luminary` — Norman lead + Feathers supporting on cli#281 branch. Inherited on release branch.
- `/pre-mortem light` — Torvalds + Saltzer-Schroeder × 8 risks; top 2 folded (R1.3 not applicable; R2.2 covered by parent try/catch in init.ts).
- `/rfc` — not invoked (scope class b per temperance marker; RFC council reserved for higher-scope work).
- `/loop` iteration 1 GREEN on both branches. Lead-lens sign-off marker on cli#281 branch.
- ADR-deviation marker — outcome ADR-honored per ADR-002 + ADR-010.
- `/verify` — full suite 498/498 GREEN + typecheck clean at both PR merge points.

## Sources read

- `docs/whereami.md` — session-start orientation
- `state/markers/{temperance,pre-mortem,luminary,adr-deviation}/fix-cli-281-statusline-rich-impl.marker` — pre-code ceremony
- `gh issue view 281` — cure options a/b/c + acceptance criteria
- `src/lib/install-statusline.ts` — cure target
- `tests/statusline-install.test.ts` — test-list block + 12 base + 7 new rich-impl assertions
- `src/commands/init.ts` L910-999 — `maybeEmitStatuslinePlan` gap surfaced
- `dist/lite/presence/cli/bassclef-statusline.dispatcher.sh` — path 3 target confirmation
- `dist/lite/.claude/settings.json` — parity test failure root cause
- `scripts/prepublish-bundle-substrate.mjs` L205 — parity cure target

## Turn count

~40 turns end-to-end through both PR merges (cli#281 cure + v1.9.8 release plumbing). Pre-code ceremony was already on disk from the prior session's abrupt stop — this session executed the /loop cycle from Beck TDD RED-first through merge + release bump.
