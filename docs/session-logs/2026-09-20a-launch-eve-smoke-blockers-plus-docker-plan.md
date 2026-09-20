---
date: 2026-09-20
session_id: 2026-09-20a-launch-eve-smoke-blockers-plus-docker-plan
started_at: 2026-09-19T22:00:00+0100
ended_at: 2026-09-20T10:55:00+0100
duration_minutes: 775
timing_source: approximate (session spanned evening + morning)
branch: fix/smoke-assert-settings-hooks
tier: standard
---

# 2026-09-20a — Launch-eve smoke blockers plus Docker harness plan

## Entry state

Session opened via `/remote-control` late evening 2026-09-19. Public bassclef-lite launch was scheduled for 2026-09-20. Cli 1.2.1 shipped to npm at 2026-09-19T23:26 with bundled bassclef v0.46.0 substrate. Cold-adopter smoke run on cold-adopter-1 reported 37/1 pass initially, which turned out to be polluted by operator-state overlay (peer clone at `~/tmp/bassclef/`, kingofrock gh auth). Real cold-adopter behavior surfaced 12 hooks wired in `settings.json` but absent from the shipped bundle. Launch decision moved to Option C — wait for upstream cures — and shifted 24 hours to 2026-09-21.

## Work done

**Cli 1.2.1 release**
- PR #155 merged: `chore(release): 1.2.1 — bundle v0.46.0 + smoke bootstrap fixes`
- Tag `v1.2.1` cut, GitHub Release created
- Publish workflow run 35475504457 completed clean (4-min build + test + publish)
- Sigstore provenance published at logIndex 2893669400
- npm registry serves `@thebassclef/lite@latest` at 1.2.1

**Cold-adopter smoke on 1.2.1**
- First run: 36/2 pass with kingofrock auth (polluted by peer clone + private-repo access)
- Second run with giveisusfree + auto_sync flip: 37/1 pass (still polluted per capture body counts 97/88/13/76)
- Static check via new script found 12 hooks wired in settings.json without source files on disk
- Root cause: substrate lite manifest emits settings entries for hooks whose files do not ship in lite tier

**Filed 11 tickets on bassclef-upstream (private)** — all carry "From: bassclef-cli" header + `from:adopter` label:
- #1815 smoke evidence mirror
- #1816 operator-private gcloud path leak
- #1818 fresh-install false-positive banners on metrics + hook-liveness
- #1820 auto_sync flag is placebo (hook does not read it)
- #1822 bassclef-sync.sh should not ship in lite bundle (operator-class per its own header)
- #1824 skills hardcode `~/src/sunj-labs/bassclef` in adopter code paths
- #1825 operator-only skills (`/release`, `/journal-export`) leaked into lite bundle
- #1826 harness-propose upstream — simulator misses PreToolUse cascade class
- #1827 lite manifest wires 12 hooks in settings.json whose source files do not ship (LAUNCH BLOCKER)
- #1828 bassclef-sync.sh install path inconsistent (settings wires user scope, onboard-repo writes project scope)
- Cross-refs posted on the 3 sync-hook tickets (#1820, #1822, #1828)

**Filed 3 tickets on bassclef-cli (public)**:
- #160 add `/onboard-repo` to smoke drive skills (blind spot the pass count hid)
- PR #161 new `scripts/smoke-assert-settings-hooks.sh` — Bash 3.2-compatible static check for hook wiring vs disk
- #162 Docker-based cold-adopter harness plan — grounded in Cockburn (walking skeleton), Beck (tests-as-first-client), Zeller (hypothesis-test) at 0.92 confidence via `/extract-intent` LIVE

**Deleted tickets on bassclef-cli** (identifier leaks):
- #156 smoke report (contained `sunjay-google-ops.json`)
- #157 gcloud path leak ticket (contained "Sanjay-personal")

**Discovery of the day**: cli 1.2.1 as shipped is NOT self-contained. `bassclef-sync.sh` fires at every SessionStart and tries to clone `sunj-labs/bassclef` (PRIVATE, invite-only). Cold-adopter-1 sync succeeded because a peer clone existed at `~/tmp/bassclef/`, masking the real behavior. Every real adopter without a peer clone or invite hits 6 PreToolUse errors on every bash tool call. The `auto_sync: false` flag in `.bassclef-source.json` is placebo — the hook does not read it. 4 launch blockers (#1822, #1824, #1825, #1827) all trace to the same root class: install-class boundary not enforced by the lite manifest generator.

## Decisions

- **Launch delayed 24 hours** to 2026-09-21. Upstream picks up 4 p0 blockers overnight.
- **Ship path: Option C** — wait for upstream cures, not cli-side settings-strip workaround. Reason: substrate defects belong at their source; stripping cli-side loses discipline for future releases.
- **Docker harness is the next primary smoke lane** (post-launch). Operator's Mac stops being the test surface. Zero operator-state pollution possible.
- **Substrate defect tickets go on bassclef-upstream** (private) not public bassclef when they name operator-personal paths. Establishes the pattern for future adopter-source filings.

## Open threads

- **Upstream cures** — bassclef-upstream working on #1822, #1824, #1825, #1827 overnight. Cli 1.2.2 patch cuts once cures land. Rerun cold-adopter smoke against 1.2.2. Green means launch clear.
- **PR #161 review + merge** — `scripts/smoke-assert-settings-hooks.sh` sits pending. Once merged, next smoke bootstrap will fetch it.
- **Cli #160** — add `/onboard-repo` to `scripts/smoke-drive-skills.sh`. Not yet started.
- **Cli #162** — Docker harness V1 walking skeleton. Not yet started. Plan filed; code work is next iteration.
- **bassclef-sync.sh peer clone at `~/tmp/bassclef/`** — real observed on cold-adopter-1. Confirms operator-state pollution class. Would fail cleanly if we moved peer aside before smoke (as noted in the ticket bodies).

## Key files changed

- `scripts/smoke-assert-settings-hooks.sh` — new script, 125 lines, tier: upstream
- Branch: `fix/smoke-assert-settings-hooks` (PR #161)

## Gate evidence

| Gate | Fired? | Marker | Notes |
|---|---|---|---|
| temperance | yes | `state/markers/temperance/release-v1.2.1.marker` | Release scope decision |
| luminary | yes | `state/markers/luminary/release-v1.2.1.marker` | Lead: linus-torvalds. Supporting: saltzer-schroeder, michael-nygard |
| pre-mortem | yes | `state/markers/pre-mortem/release-v1.2.1.marker` | Light mode, 3 lenses, verdict proceed |
| extract-intent | yes | LIVE mode, 0.92 confidence | Cockburn + Beck + Zeller for Docker harness plan |
| verify | partial | Local test on smoke script | Test suite not re-run this session |
| diagnose | not applicable | | Release orchestration + design work; no bug fix |

## Sources read

- `dist/lite/.claude/settings.json` — 28 hook entries, 12 missing
- `dist/lite/.claude/hooks/bassclef-sync.sh` line 4 (operator-class header) + line 248 (BASSCLEF_REPO url) + line 265 (git clone call)
- `dist/lite/.bassclef-source.json` — `auto_sync: true`, `source_repo: sunj-labs/bassclef`
- `.claude/skills/onboard-repo/SKILL.md` — 6 `~/src/sunj-labs/bassclef` hardcodes
- `.claude/skills/provision-deploy-host/SKILL.md` — 2 hardcodes
- `.claude/skills/release/SKILL.md`, `journal-export/SKILL.md` — operator-only skill audit
- `.claude/luminaries/alistair-cockburn.md`, `kent-beck.md`, `andreas-zeller.md`
- `scripts/prepublish-bundle-substrate.mjs` — sibling path logic
- `.github/workflows/publish.yml` — release trigger + environment gate
- Bassclef v0.46.0 release notes at `../bassclef-upstream/docs/release-notes/v0.46.0.md`

## Next session pickup

1. Check bassclef-upstream progress on #1822, #1824, #1825, #1827 overnight
2. Merge PR #161 if unblocked
3. Cut cli 1.2.2 with v0.46.0-cured substrate bundle (assuming upstream cures land)
4. Rerun cold-adopter-1 smoke on 1.2.2
5. If green, resume launch
6. Post-launch: begin Docker harness V1 walking skeleton per #162 plan
