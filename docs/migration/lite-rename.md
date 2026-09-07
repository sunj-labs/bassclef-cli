---
tier: lite
migration: lite-rename
title: Migration plan — @thebassclef/core → @thebassclef/lite
audience: existing bassclef adopters
authored: 2026-09-07
goal: 2026-09-07-lite-rename-sync-publish
references:
  - {type: goal, id: docs/iteration-bets/2026-09-07-lite-rename-sync-publish.md}
  - {type: adr, id: architecture/decisions/ADR-031-non-breaking-changes-adopter-discipline.md}
---

# Migration — @thebassclef/core → @thebassclef/lite

## Sources read

- `docs/iteration-bets/2026-09-07-lite-rename-sync-publish.md` — goal + acceptance
- `.claude/rules/we-dont-break-adopters.md` — ADR-031 discipline (compat window per rename)
- Memory: `project_lite_is_free_tier_package` (lite is shipping name), `feedback_rename_must_ride_with_manifest_sync`

## What I'm NOT reading (with reason)

- Individual adopter repos — this migration plan is generic; per-adopter adaptation lives in the adopter's own docs

## What changes

- Package name — `@thebassclef/core` → `@thebassclef/lite`
- Substrate version bundled — v1.2.19 → v1.5.0 (three minor versions of skill retags, luminary flips, `/build` promoted to lite)
- Manifest shape — `upstream_commit` field removed; `problem` + `value` added per entry (bassclef-cli consumers unaffected — grep confirms no reads)

## What does NOT change

- CLI binary name stays `bassclef` — no shell-alias changes
- `bassclef init` output shape stays the same
- `bassclef sync` behavior stays the same
- `.bassclef/init.manifest.json` schema stays the same
- Adopter config files (`.claude/settings.json`, `substrate.config.md`) stay the same

## Migration path (existing @thebassclef/core adopters)

```bash
npm uninstall -g @thebassclef/core
npm install -g @thebassclef/lite
bassclef sync
```

Three commands. First uninstalls old package. Second installs new package with fresh substrate. Third refreshes adopter repo to the new substrate.

## Timeline

| Date | Event |
|---|---|
| 2026-09-07 | `@thebassclef/lite@0.1.0` published to npm |
| 2026-09-07 | `@thebassclef/core@0.1.1` deprecated with migration message |
| 2026-09-07 to 2026-12-07 | 90-day grace window — `@thebassclef/core` stays installable; deprecation notice on every install |
| 2026-12-07 | Grace window ends — decision on unpublish vs archive |

Grace window per `.claude/rules/we-dont-break-adopters.md` — 90 days from deprecation date.

## What breaks

- Adopters running `npm install -g @thebassclef/core` see the deprecation notice; install still succeeds
- Automated CI that pins `@thebassclef/core@0.1.1` keeps working; upgrade to `@thebassclef/lite` at adopter's cadence

## What does NOT break

- Existing `@thebassclef/core@0.1.1` installations keep working; deprecation is advisory
- Adopter repos already initialized by core keep their `.claude/settings.json` + `substrate.config.md`; no re-init needed after switching to lite
- `bassclef sync` on an adopter repo initialized by core works when run from a lite install

## Silent-install adopters (Cooper risk #1)

Adopters who ran `npm install -g @thebassclef/core` once and never ran `npm install` again do not see the deprecation notice on their next session.

Mitigation (out of scope this goal; follow-on ticket):
- Session-start hook surfaces BLOCKED item if `.bassclef-source.json` still points at core
- Adopter runs the 3-command migration when the BLOCKED item fires

For now — adopters on stale installs stay on core until they run `npm install` again OR until the follow-on hook ships.

## Verification steps for adopters

After migration:

```bash
which bassclef
# should return the npm global bin path

bassclef --version
# should return 0.1.0 (from lite)

npm ls -g @thebassclef/lite
# should show 0.1.0 installed

npm ls -g @thebassclef/core
# should return empty (no core installed)
```

If any step fails, run:

```bash
npm uninstall -g @thebassclef/core @thebassclef/lite
npm install -g @thebassclef/lite
```

## Compat shim

None needed. `bassclef` binary name stays constant across packages; any script that references `bassclef` works after migration without change.

## Refs

- Goal: `docs/iteration-bets/2026-09-07-lite-rename-sync-publish.md`
- ADR-031 we-don't-break-adopters (grace window discipline)
- Memory: `project_lite_is_free_tier_package`, `feedback_rename_must_ride_with_manifest_sync`
- Rule: `.claude/rules/we-dont-break-adopters.md`
