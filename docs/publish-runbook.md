---
tier: lite
---

# Publishing @thebassclef/lite

Two paths. The default waits for you. The other does not, and says so.

The decision behind this is `docs/adrs/ADR-004-publish-pipeline-safety-contract.md`,
particularly §Amendment 2026-11-05. The full stage-by-stage path from an
upstream merge through to an adopter's machine is mapped separately; this file
covers only the release itself.

## Before either path

```bash
bash scripts/publish-gate.sh status
```

Three possible answers. `ON` means publish will wait for your approval.
`OFF` means it will not. `UNKNOWN` means the gate cannot be read, which you
should treat as unprotected until it reads cleanly.

The `can_admins_bypass` line prints every time because it is part of the real
answer — an admin can click through regardless of the reviewer list.

## Default — you approve

1. Confirm the gate is on. `publish-gate.sh on` is idempotent, so running it
   when it is already on costs nothing.
2. Merge the version bump PR. Release notes should read **Prepared**.
3. Tag the merge commit `vX.Y.Z` and publish a GitHub Release. The tag alone
   does nothing; the Release is what starts the workflow.
4. The `checks` job runs ungated. Wait for it.
5. The `publish` job stops at the gate. Read the checks output, then approve.
6. Verify the published bytes, not a local build:

   ```bash
   npm pack @thebassclef/lite@X.Y.Z
   ```

   Compare the byte size and file count against the publish log's
   `+ @thebassclef/lite@X.Y.Z` line. `latest` lags roughly 90 seconds to
   3 minutes; the publish log is authoritative meanwhile, and a local
   `ETARGET` inside that window is not a failure.
7. Flip the release notes line to **Released**.

## trust — you are asleep

Same sequence, with step 1 replaced and a step added at the end.

```bash
bash scripts/publish-gate.sh off --authorized-by operator
```

The `--authorized-by` argument is required. It is the record of who decided,
and it lands in `state/publish-gate-audit.log`.

Then cut the Release as above. The `publish` job will not stop.

**Restore the gate as soon as the publish lands:**

```bash
bash scripts/publish-gate.sh on
```

This is the step that matters. A gate left off is the exact condition `cli#462`
was filed about — it had been off, unnoticed, through at least one release.
Nothing yet warns you about it, so until something does, the restore is yours
or the dispatch's to remember.

## Why a script rather than a skill

This repo gitignores `.claude/skills/` (`.gitignore:84`) and tracks no skills
of its own — every skill arrives from the upstream sync. A `/publish` SKILL.md
authored here could never be committed. So the sequence lives in this file and
the gate logic lives in a tested script, both tracked.

Typing `/publish` or `/publish trust` still works as shorthand in a session.
It resolves to this runbook.

## What is not mechanized yet

- Nothing fires a cold-adopter smoke against a freshly published version.
  `docker-smoke.yml` can do it but triggers only on pull requests. See
  `cli#469` and `cli#447`.
- Nothing installs the packed tarball and runs it before publish, so the
  irreversible step is taken on a file list rather than a working artifact.
  Also `cli#469`.
- Nothing notices a gate left off. Named above.
