---
id: UC-script-cli-323-save-state-prototype-exclude-driver
type: brief
status: active
primary-actor: adopter-sim test runner
authoring_luminaries:
  lead: michael-feathers
  supporting:
    - kent-beck
    - linus-torvalds
---

# UC — Characterize save-state.sh prototype-leak (cli#323)

## Scope

Session H driver 2. Characterizes shipped state of `dist/lite/.claude/hooks/save-state.sh` auto-save staging. Ticket says the hook commits unreviewed prototype edits because `git add docs/` lacks a `docs/prototypes/` exclusion.

## Primary actor

Adopter-sim runner on CI OR developer local test shell.

## Preconditions

- `dist/lite/.claude/hooks/save-state.sh` exists.

## Main scenario

1. Runner invokes `bash scripts/tests/smoke-drive-adopter-323-save-state-prototype-exclude.test.sh`.
2. Driver greps the hook for `git add docs/` lines.
3. Driver greps the hook for `:!docs/prototypes` OR `:(exclude)docs/prototypes` pathspec.
4. Driver finds at least one `git add docs/` and zero exclusion pathspecs.
5. Driver emits `RED-CONFIRMED|driver-323|...`.
6. Driver exits 0.

## Extensions

**4a — exclusion present.** Upstream applied the pattern `git add docs/ ':!docs/prototypes'` or equivalent.

1. Driver emits `GREEN-UNEXPECTED|driver-323|...`.
2. Driver exits 1. Downstream flips the ticket GREEN after bundle sync.

**4b — bundle absent.** `dist/lite/.claude/hooks/save-state.sh` not present.

1. Driver emits SKIP with code 77. Driver inconclusive.

## Postconditions

- RED-CONFIRMED exit — defect reproduces; ticket stays open for upstream cure.
- GREEN-UNEXPECTED exit — cure reached adopters; ticket closes after bundle sync.
- SKIP exit — bundle not available; driver inconclusive.

## Related

- cli#323 — the ticket this driver characterizes
- `.claude/rules/prototype-workflow.md` — the rule the hook violates
- Session F precedent — grep-based characterization pattern (#322)
