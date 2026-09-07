---
slug: 2026-09-07-lite-rename-sync
scope: "Ship @thebassclef/lite@0.1.0 — 5-step chain: backward-compat test, substrate sync v1.2.19→v1.5.0, smoke, rename+publish, deprecate core + comment coord #51"
mode: light
lenses: [alan-cooper, saltzer-schroeder, john-ousterhout]
date: 2026-09-07
always_fire_matched: partial
always_fire_notes: "Deploy-pipeline changes (npm publish) touches Saltzer domain #8; not full-mode escalation because publish path is proven at @thebassclef/core@0.1.1 and reused as-is"
time_budget_original: 70-120 turns
time_budget_revised: 90-155 turns (adds ~20-35 for closure of top 3 risks)
---

# Pre-mortem risk ledger — @thebassclef/lite@0.1.0 rename + sync

Klein workshop shape: assume the ship failed spectacularly. Each lens surfaces failure classes independently. Top-3 collated after all lenses land.

Anchor: `.claude/luminaries/gary-klein.md` HBR 2007 method.

---

## Lens: Alan Cooper — adopter experience

Assume failure: "We shipped @thebassclef/lite@0.1.0 cleanly but two weeks later existing @thebassclef/core adopters are still on the old package. The deprecation notice never reached them; their sessions are silently stale; a cross-repo config referencing core keeps them there."

Risks:

1. **Deprecation notice invisible on stale-install adopters** [severity: medium; probability: high]
   Existing `@thebassclef/core@0.1.1` adopters see the deprecation only when they run `npm install` again. Silent install-once users stay on core indefinitely.
   *Mitigation:* Ship a README + CHANGELOG entry to core naming the migration BEFORE `npm deprecate` fires. Add a session-start advisory to lite v1.5.0 that surfaces if `.bassclef-source.json` still points at core.
   *Owner:* Step 5 (deprecate + coord comment).

2. **Confusion when both packages installed** [severity: medium; probability: medium]
   Adopter runs `npm install -g @thebassclef/lite` without uninstalling core — `bassclef` binary from whichever installed later wins. No clear signal that lite supersedes core.
   *Mitigation:* Deprecation message on core includes the exact uninstall+reinstall command. Optional: add a first-run detection message in `bassclef init` when both are on the PATH.
   *Owner:* Step 4 (rename+publish) message text + Step 5 deprecate message.

3. **npm 10 deprecation-warning rendering weaker than npm 11** [severity: low; probability: medium]
   npm 11 pins were required for trusted-publisher (memory `feedback_npm_11_required_for_trusted_publisher`); npm 10 renders deprecation warnings less prominently.
   *Mitigation:* Test deprecation output on npm 10 + 11 before Step 5 lands. Include screenshot proof in the closeout.
   *Owner:* Step 5 verification.

4. **Manifest bump ships /build promotion + 4 skill retags + 14 luminary flips without adopter-visible release notes** [severity: medium; probability: medium]
   v1.5.0 changes surface-area but the substrate refresh alone won't tell adopters what changed. Skill retags (upstream #1478) can shift auto-loading; luminary flips (#1459) change tier availability.
   *Mitigation:* Read upstream #1478 + #1459 + #1462 before Step 2. Ship a `CHANGELOG.md` update naming each surface change in the same PR as the substrate sync.
   *Owner:* Step 2 (sync) PR body + CHANGELOG.

5. **Mobile / ephemeral session adopters may suppress npm deprecation warnings** [severity: low; probability: medium]
   Mobile sandbox often silences CLI warnings during install.
   *Mitigation:* Session-start hook surfaces a BLOCKED item for stale-core adopters (follow-on ticket; out of scope this goal).
   *Owner:* Step 5 follow-on filing.

---

## Lens: Saltzer & Schroeder — npm security surface

Assume failure: "We published @thebassclef/lite@0.1.0 and it went live within minutes. The tarball shipped an operator-private path we didn't grep for; the substrate sync included a file whose upstream hash we didn't verify; the trusted-publisher config silently failed and we fell back to a legacy token that leaked in CI logs."

Risks (Saltzer & Schroeder 1975, IEEE 63(9) — 8 protection-mechanism principles):

1. **`files` array in package.json includes operator-private paths after sync** [severity: HIGH; probability: medium]
   `files: ["dist/*.js", "dist/*.cjs", "dist/*.d.ts", "substrate/**", "README.md", "LICENSE"]`. `substrate/**` is a broad glob — if v1.5.0 introduces an `operator-private/` subdirectory or bundles chronicles/journals, they ship to npm and become public.
   *Mitigation:* `npm publish --dry-run` after Step 2; grep the tarball listing for `operator-private/`, `chronicle/`, `journals/`. Tighten `files` array if needed. Add a Tier 0 test that asserts no operator-private paths in tarball.
   *Owner:* Step 3 (new Step 2.5 pre-publish audit) — see scope-change recommendation below.
   *Principle:* fail-safe defaults + least privilege (only publish what you intended).

2. **`prepublishOnly` runs `node scripts/prepublish-bundle-substrate.mjs` — script execution during publish** [severity: HIGH; probability: low]
   If the substrate sync introduces a malicious file OR the script itself is compromised via a dep bump, publish runs it with npm-token privileges.
   *Mitigation:* `--ignore-scripts` on publish. Audit the sync source against the upstream v1.5.0 git tag SHA before Step 4. Pin the sync source to a specific tag, not a moving branch.
   *Owner:* Step 4 pre-publish.
   *Principle:* economy of mechanism + open design (the sync source should be auditable + pinned).

3. **Trusted-publisher config may reject second package publish** [severity: medium; probability: medium]
   OIDC audience or repository-claim mismatch. Same repo + same workflow SHOULD work but has never been proven for `@thebassclef/lite`.
   *Mitigation:* Verify trusted-publisher config supports `@thebassclef/lite` BEFORE Step 4. Check npm settings for the trusted-publisher entry. If missing, add it via npm UI (operator step).
   *Owner:* Step 4 pre-flight.
   *Principle:* fail-safe defaults (default action denies unauthorized publish).

4. **Provenance attestation may fail on shape mismatch** [severity: medium; probability: low]
   Same class as #3 — workflow file path or triggering event may not match provenance requirements for the new name.
   *Mitigation:* Verify workflow provenance in dry run. Include provenance URL in the release notes.
   *Owner:* Step 4.

5. **LICENSE file coverage** [severity: medium; probability: low]
   New package needs its own LICENSE in the tarball. If it's a symlink or missing, npm publishes without a license.
   *Mitigation:* Check `files` array covers `LICENSE` explicitly (it does per current package.json). Audit tarball listing.
   *Owner:* Step 4.

6. **npm 2FA Touch ID prompt requires operator at keyboard** [severity: low; probability: high]
   If operator away when publish fires, publish times out and CI job fails.
   *Mitigation:* Operator confirms availability before Step 4 dispatch. Publish is a synchronous operator-gated step per session /temperance.
   *Owner:* operator.
   *Principle:* psychological acceptability (2FA is the human authorization boundary).

---

## Lens: John Ousterhout — sync module depth

Assume failure: "The substrate sync from v1.2.19 → v1.5.0 landed. `copy-substrate` reported 42 files copied and 3 refused — silently. Turns out v1.5.0 renamed a directory that adopters had local edits over; content_hash comparison per old-path returned 'refused' without surfacing WHICH files or why. Adopter debugging took hours."

Risks:

1. **Content-hash mismatch on renamed files in v1.5.0 manifest** [severity: HIGH; probability: medium]
   `src/lib/copy-substrate.ts` hashes each source file and compares against `entry.content_hash` from the bundled manifest. v1.5.0 promoted `/build` to lite (#1462) which likely adds new files; skill retag #1478 might rename skill directories. Any entry.path that doesn't resolve in the bundled snapshot fails silently as "refused" or "errored".
   *Mitigation:* Run `copy-substrate --dry-run` on a fresh clone after Step 2 sync. Verify every `entry.path` in the new manifest resolves to a real file at `<bundleRoot>/<entry.path>`. If any refuse/error, halt and diagnose before Step 4.
   *Owner:* Step 3 (smoke, extended).
   *Principle:* deep module — the interface should say "here's what synced OR here's what broke" not leak 4 result buckets.

2. **`substrate-registration-canary.sh` reads manifest at wrong path** [severity: medium; probability: low]
   Hook body references `$REPO_ROOT/lite-manifest.json`, not `substrate/.bassclef/lite-manifest.json`. Post-sync, this hook may look at a stale or wrong manifest.
   *Mitigation:* Read the hook body in Step 3 smoke; verify the path it reads is intentional (either it reads a different file by design, or it needs updating for the new bundled location).
   *Owner:* Step 3.

3. **`bassclef sync` adopter-side conflict handling** [severity: medium; probability: medium]
   Per ADR-003 sync safety contract, adopters with local edits over synced files see NeedsUpdate vs Edited distinction. v1.5.0 with retagged skills may surface "Edited" states for files adopter never touched (upstream renamed the file; adopter's snapshot has old-name state).
   *Mitigation:* `bassclef sync --dry-run` in the smoke step against a fixture adopter carrying an old snapshot. Document any surprise "Edited" surfacings in release notes.
   *Owner:* Step 3.

4. **Manifest additive fields (`problem` + `value` per entry) pass through cleanly** [severity: NONE; already verified]
   Grep in parent turn: no consumer reads these fields. Copy path is field-agnostic. No action.

5. **`upstream_commit` field removed from v1.5.0** [severity: NONE; already verified]
   Grep in parent turn: no consumer reads this field. Backward-compat test in Step 1 pins this. No further action.

6. **Interface complexity — copy-substrate returns 4 result buckets** [severity: low; probability: low]
   Pre-existing shallow interface — not v1.5.0-specific. Adopter has to interpret copied/wouldCopy/refused/errored. Documented as-is; not fixing this ship.

---

## Top 3 highest-severity risks (collated)

Ranked by severity × probability across all 3 lenses:

1. **Saltzer #1 — operator-private paths in tarball** (HIGH × medium)
   Mitigation: `npm publish --dry-run` + grep tarball for `operator-private/`, `chronicle/`, `journals/` BEFORE Step 4. Add Tier 0 test asserting tarball cleanliness.

2. **Ousterhout #1 — content-hash mismatch on renamed files** (HIGH × medium)
   Mitigation: `copy-substrate --dry-run` on fresh clone after Step 2 sync. Verify every `entry.path` resolves. Halt if any refuse/error.

3. **Saltzer #2 — prepublishOnly script execution risk** (HIGH × low)
   Mitigation: Audit sync source against upstream v1.5.0 git tag SHA before Step 4. Pin to tag not branch. Consider `--ignore-scripts` on publish (may break the bundle step — verify).

---

## Recommended scope changes

Top 3 risks demand three scope additions:

- **NEW Step 2.5 — pre-publish tarball audit** (~5-10 turns)
  After sync commits, run `npm publish --dry-run`. Grep tarball listing for operator-private paths. Fail if any found. Ship a Tier 0 test that codifies this check.

- **EXTEND Step 3 — copy-substrate dry-run on fresh clone** (~10-15 additional turns)
  Beyond current smoke plan (cold install), add: fresh clone → run copy-substrate → assert 0 refused + 0 errored + entries.length copied. This is the Ousterhout deep-module cure.

- **NEW Step 3.5 — trusted-publisher config verification** (~5-10 turns)
  Before Step 4 publish, verify npm trusted-publisher config supports `@thebassclef/lite`. Screenshot proof committed to `state/markers/npm-config/`.

**Revised time budget: 90-155 turns** (originally 70-120; adds ~20-35 for top-3 mitigations).

---

## Refs

- Bet parent: `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md` (goal doc needs amendment for rename)
- Coord ticket: bassclef-cli#51
- Peer heads-up: bassclef-web cross-session message 2026-09-07 (upstream_commit removal in v1.5.0)
- Memory: `project_lite_is_free_tier_package.md`, `feedback_rename_must_ride_with_manifest_sync.md`, `feedback_npm_11_required_for_trusted_publisher.md`, `reference_npm_2fa_is_touch_id.md`
- Prior session log: `docs/session-logs/2026-09-05-longrun-prep-lite-rename-sync-scoped.md` (Option a-plus origin)
- ADR-002 init safety, ADR-003 sync safety, ADR-005 npm packaging strategy
- `.claude/luminaries/alan-cooper.md`, `.claude/luminaries/saltzer-schroeder.md`, `.claude/luminaries/john-ousterhout.md`
- `.claude/luminaries/gary-klein.md` — anchor
- Klein, G. (2007). "Performing a Project Premortem." HBR
