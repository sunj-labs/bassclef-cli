---
tier: lite
id: UC-cold-adopter-init-nudge
name: Nudge cold adopter to `bassclef init` when they run other verbs first
level: user goal
primary_actor: Sam (cold adopter)
scope: bassclef-cli — `bassclef sync` and `bassclef migrate` verb preflight
authored: 2026-09-11
authored_by: agent
cockburn_ceremony: brief
bet: docs/iteration-bets/2026-09-11-zero-state-nudge-plus-straplines.md
governs_source:
  - src/cli.ts
  - src/lib/require-init.ts (new)
references_adr: ADR-002-bassclef-init-safety-contract.md
references_ticket: 55
---

# UC-cold-adopter-init-nudge — Point cold adopter at `bassclef init` from `--help`

## Scope

`bassclef --help` marks `init` as the first-run verb so cold adopters know which command to run first. `bassclef sync` no-manifest keeps its current nudge (already Cooper-good). `bassclef migrate` no-manifest keeps its Path B behavior per ADR-008 Decision 2.

## Sources read

- `docs/iteration-bets/2026-09-11-zero-state-nudge-plus-straplines.md` — parent goal doc; ships this UC
- Ticket #55 body — 5-test contract + evidence bullets; original spec conflicted with ADR-008; scope reconciled per reading below
- `src/cli.ts` L20-38 — current `USAGE` string; three verbs listed with equal weight; no first-run cue
- `src/commands/sync.ts` L118-130 — sync catches `ManifestReadError`; prints message + exits 1
- `src/lib/manifest-io.ts` L34-40 — current no-manifest error message: `not initialized — no manifest at <path>. Run \`bassclef init\`...`
- `src/lib/migrate.ts` L86-105 — Path B fires on no-manifest per ADR-008; dispatches `runInit` with `--force`
- `docs/adrs/ADR-008-bassclef-migrate-subcommand.md` Decision 2 — Path B skips prompt per Cooper (no interstitial); prints "Running full init for 149 files"
- `docs/session-logs/2026-09-07-lite-rename-sync-publish-shipped.md` L48 — friend "had to ask which command sets up the project"; pain point is `--help` pre-run, not post-run

## Reconciliation with ticket #55

The original ticket asked for a nudge on sync + migrate + bare `bassclef`. Reading the source discovered:
- Sync already nudges (works as ticket wants)
- Migrate no-manifest dispatches Path B per ADR-008 D2 (not a nudge; auto-inits)
- Bare `bassclef` already prints help + exits 0

The friend's actual pain (per session log L48) was pre-run confusion at `--help`. This UC ships the smaller fix that addresses that pain without amending ADR-008.

## Main success scenario (brief)

Sam installs `@thebassclef/lite` from npm. She runs `bassclef --help`. The help output lists three verbs with `init` marked as the first-run verb (line: `Start here: bassclef init`). Sam runs `bassclef init`. It works. Cold-adopter friction: closed.

Second scenario — Sam guesses `sync` first. She sees `bassclef sync: not initialized — no manifest at <path>. Run \`bassclef init\` (or \`bassclef init --force\` if managed files already exist).` Exit 1. She runs `bassclef init`. Works.

## Preconditions

- `bassclef` binary on `$PATH` via npm global install
- Sam is a cold adopter — has not run `bassclef init` in the target directory

## Postconditions

- **--help hint** — `bassclef --help` prints usage with a "Start here: `bassclef init`" line before the verb list
- **Sync nudge intact** — `bassclef sync` in no-manifest dir prints the current nudge + exits 1 (characterization test pins the string)
- **Migrate Path B intact** — `bassclef migrate` in no-manifest dir prints "no prior manifest detected. Running full init for 149 files." + dispatches init (characterization test pins the opener)

## Trigger

Sam runs any `bassclef` command as a cold adopter.

## Extensions (brief)

- **Manifest present** — --help hint still prints; irrelevant to init'd users but harmless
- **Non-TTY environment** — help output is identical; no interactive behavior needed
- **Future verb added** — the "Start here" hint stays anchored to `init` regardless of new verbs

## Out of scope

- Behavior change on migrate no-manifest — Path B stays per ADR-008 D2; changing needs an ADR amendment
- Bin-name confusion (user installed `@thebassclef/lite`, binary is `bassclef`) — documented in ticket #55 out-of-scope
- Interactive prompt on Path B for cold adopters — sister proposal, not this UC

## Refs

- Ticket #55 body
- Risk ledger `docs/risk-ledgers/2026-09-11-zero-state-nudge-plus-straplines.md` (R1, R3, R7 folded here)
- ADR-002 (init safety contract; the manifest path this reads)
- `.claude/rules/oo-ad-entry-point.md` (Cockburn ceremony matrix — brief tier fits existing-code extension)
- @luminary alan-cooper (adopter UX; zero-state moment as UX signal)
