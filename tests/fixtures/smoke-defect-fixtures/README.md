# Smoke defect fixtures — cli#101 through cli#108

Fixtures that pin known defects surfaced during the 2026-09-17 cold-adopter smoke on `@thebassclef/lite@1.1.1`. Each fixture is a hook-capture file (same shape `smoke-capture.sh` writes) that reproduces one defect's observable signal.

## Coverage

6 of 8 defects map cleanly to one of the four checks:

| Defect | Check that catches it | Fixture |
|---|---|---|
| **cli#101** — /onboard-repo no path for existing install | `no-unexpected-blocked` | `cli-101/onboard-repo-blocks.out` |
| **cli#102** — orientation gate false-fires on fresh repo | `no-unexpected-blocked` | `cli-102/orientation-gate-blocks.out` |
| **cli#103** — whereami.md ships at wrong path | `no-not-found` | `cli-103/whereami-not-found.out` |
| **cli#104** — bassclef-configs.jsonc absent from bundle | `no-not-found` | `cli-104/configs-not-found.out` |
| **cli#105** — BASSCLEF_DIR resolves to $HOME | `no-silent-skip` | `cli-105/bassclef-dir-skip.out` |
| **cli#108** — ABRUPT STOP false-fires on first session | `no-unexpected-blocked` | `cli-108/abrupt-stop-false-fire.out` |

## Uncovered by V1 checks

Two defects fall outside the four-check surface. Ship without a fixture and note the gap:

- **cli#106** — sync failure message misdirects. Message content defect. No grep-detectable signal in the current check set. Recommend Layer 2 or later: add a `messages-are-accurate` check driven by a per-message-class allowlist plus expected-cause pairs.
- **cli#107** — textstat warning fires every turn with no once-per-session guard. Rate-limit defect. No grep-detectable signal in the current check set. Recommend Layer 2 or later: add a `no-repeat-warnings` check that flags duplicate warning lines above a threshold.

Both cited in the Layer 1 closeout retro plus follow-on tickets.

## Refs

- Parent goal: `docs/iteration-bets/2026-09-18a-smoke-evidence-capture.md`
- Spec: `docs/specs/smoke-evidence-capture.md` § Four checks
- Coordination ticket: bassclef-upstream#1728
- Fixture pins: cli#101 through cli#108
