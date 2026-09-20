---
tier: operator-private
rfc_id: RFC-0003
authored: 2026-09-20
session_id: 2026-09-20b
subject: Docker harness testing surface (Step 7 live-run pre-review)
goal_doc: docs/iteration-bets/2026-09-20b-docker-cold-adopter-harness.md
disposition: Revised A (accept scope; 1 HIGH cured before Step 7 live-run attempt)
council:
  - karl-popper
  - charles-sanders-peirce
  - stephen-toulmin
  - kaoru-ishikawa
  - w-edwards-deming
---

# RFC-0003 — Docker harness testing surface (Handoff 3 outside council)

Third-pass adversarial review. Council focused on epistemology of the falsification test.

## Sources read

- All prior artifacts through Step 5
- Pre-mortem-3 — 9 live-run risks
- `scripts/smoke-assert-settings-hooks.sh` — the assertion the harness invokes

## Council

| Lens | Role |
|---|---|
| Karl Popper | Falsifiability — is the test genuinely falsifiable, or does it always pass by construction? |
| Charles Sanders Peirce | Abductive reasoning — is exit code 3 the only explanation, or are there alternatives? |
| Stephen Toulmin | Argument shape — does the pass/fail claim carry claim + evidence + warrant? |
| Kaoru Ishikawa | Root-cause fishbone — where do false positives / false negatives originate? |
| W. Edwards Deming | Measurement system analysis — is the test measuring what we think? |

## Findings

### HIGH-R14 (Popper — falsifiability audit)

- **Claim:** the harness must be able to fail. If it cannot fail, it is not a test.
- **Evidence:** entry.sh calls smoke-assert-settings-hooks.sh + captures the exit code + maps it. But if smoke-assert-settings-hooks.sh cannot exit 3, the harness cannot detect anything.
- **Why it fails:** before Step 7 live run, we have no evidence smoke-assert exits 3 on 1.2.1. Verify direct on operator machine first.
- **Cure:** run smoke-assert-settings-hooks.sh directly on operator machine (bassclef-cli or peer clone) with cli 1.2.1 installed; confirm exit 3 with visible 12-hook list. Only then invoke the container.

### MEDIUM-R15 (Peirce — abductive alternatives)

- **Claim:** exit 3 in Docker may come from more than one cause. Options: (a) hooks-missing class per intent; (b) settings.json malformed; (c) smoke-assert-settings-hooks.sh path resolution bug inside container.
- **Cure:** entry.sh logs the smoke-assert stdout in the report. Reader distinguishes (a), (b), (c) by log content, not just exit code.

### MEDIUM-R16 (Toulmin — argument shape)

- **Claim:** exit code alone is a bare assertion. "Cli 1.2.1 has the 12-hook class" needs claim + evidence + warrant.
- **Cure:** report.txt names the class + lists the 12 hooks + cites upstream#1827. Report shape is the argument shape, not just an exit code.

### MEDIUM-R17 (Ishikawa — fishbone root cause)

- **Claim:** a false negative (exit 0 on 1.2.1) traces to 6 possible root-cause categories: (a) assertion missing hooks; (b) settings.json not read; (c) init not run; (d) install skipped; (e) container using stale image; (f) test-mode leaked to production run.
- **Cure:** entry.sh preflight logs each stage's start + end. If exit 0 surfaces on 1.2.1, the 6 categories map to specific log signatures.

### LOW-R18 (Deming — measurement system analysis)

- **Claim:** is exit code a stable measurement? Run the same setup twice — same result?
- **Cure:** V3 CI-gate would run the smoke twice in parallel + compare exit codes. Deferred to V3 per cli#162 L57.

## Disposition — Revised A

Accept scope. Cure R14 inline before Step 7 live-run attempt. R15 + R16 + R17 fold into the run itself (log inspection). R18 deferred to V3.

### R14 cure (inline before Step 7)

Run `scripts/smoke-assert-settings-hooks.sh` on operator machine against a fresh cli 1.2.1 install; confirm exit 3 + confirm 12-hook list in stdout. Only proceed to Docker run after this confirms.

## Follow-on plan

- V3 — measurement-system-analysis wiring (per R18)
- Deferred to next iteration
