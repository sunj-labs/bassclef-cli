---
tier: project
title: Pre-mortem light — cli#247 adjacent-shadow detection
date: 2026-09-26
shape: light
lenses: [donald-norman, michael-nygard]
folded: [N2, S1]
goal_id: 2026-09-26-247-shadow-detection
---

# Pre-mortem light — cli#247 adjacent-shadow detection

Klein pre-mortem shape: assume the change shipped, adopter ran into pain, work backward from the pain to what would need to be true.

## Lens 1 — Donald Norman (signifiers + feedback loops)

Norman asks: does the operator know what happened and what to do?

- **N1** — Warning fires but the operator does not know which flag to pass. Adopter reads "shadow detected" and has no next step.
- **N2** — Warning names path + three options but the `--allow-shadow` flag is buried in the docs, not in the message itself.
- **N3** — Bypass fires silently (returns 0 with no log line). Operator later cannot recall whether the bypass triggered or the check simply passed.
- **N4** — Docker container fires the check but adopter running from CI sees `exit 1` with no message that shadow was the cause (stderr eaten by CI wrapper).
- **N5** — Runbook mentions the class but not the exact warning text — reader searching for the warning does not find the runbook entry.

## Lens 2 — Michael Nygard (stability + fail-soft)

Nygard asks: what edge case makes the guard rail worse than no guard rail?

- **S1** — Sentinel file missing at shadow path — coincidentally-named directory (`~/tmp/bassclef/` empty) fires false positive. Operator blocked with no real shadow.
- **S2** — Symlink at shadow path — `[ -d ]` follows symlinks; a symlink to `/some/other/repo/bassclef` may fire the check based on target content, not intent.
- **S3** — Permission denied reading sentinel — non-executable operator (rare) sees fail-loud exit even when the shadow is not readable.
- **S4** — Docker container has `/root/tmp/bassclef` mounted intentionally as fixture — legitimate use case blocked by the check.
- **S5** — `dirname` of a workdir with trailing slash returns unexpected parent — off-by-one on path calculation.

## Top-2 folds

- **N2 folded into UC main scenario Step 5** — warning message names the exact bypass flag inline: `SMOKE_ALLOW_SHADOW=1` plus "mv aside" plus "rm -rf" as three concrete options. Reader acts without opening source or docs.

- **S1 folded into UC Extension 3a** — sentinel-absent path returns 0 silently. A coincidentally-named `~/tmp/bassclef/` empty directory does NOT block smoke. The check requires the specific sentinel file to fire.

## Deferred (not folded this ship)

- **N3** bypass-silent — added as advisory: bypass will log via trace-helper when available. Runbook amendment names the trace file location.
- **N4** CI stderr — CI wrapper handling is not owned by this ticket. Peer's upstream#1954 covers CI observability separately.
- **S2** symlink — accept default `[ -f ]` follow behavior; document in runbook as "symlink to bassclef checkout is treated as a shadow". Not folded because the behavior matches intent for the common case.
- **S3** permission denied — rare on operator machines; if surfaced, add explicit `[ -r ]` check as follow-on.
- **S4** intentional docker mount — no legitimate use case identified today; follow-on ticket if surfaced.
- **S5** trailing slash — bash `dirname` handles trailing slashes correctly per POSIX; verified inline via test T05 in the RED harness.

## References

- Ticket: `bassclef-cli#247`
- UC: `docs/use-cases/UC-247-shadow-detection.md`
- Diagnosis: `state/markers/diagnose/fix-247-shadow-detection.marker`
- Luminary marker: `state/markers/luminary/fix-247-shadow-detection.marker`
