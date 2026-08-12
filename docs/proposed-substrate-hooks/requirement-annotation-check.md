---
tier: standard
kind: substrate-hook-spec
authored: 2026-08-12
authored_by: agent
target: sunj-labs/bassclef-upstream
proposed_for: Phase 2 of the Traceability Subsystem promote
promote: docs/promotes/2026-08-11-traceability-subsystem.md
applied_test_case: docs/requirements/2026-08-11-npm-distribution.md
sibling_hooks:
  - assert-verify-steering.sh
  - turn-prose-kiss-check.sh
  - compound-noun-scrub.sh
  - pattern-annotation-validate.sh
anchoring_luminaries:
  - alexander-egyed
  - john-ousterhout
  - michael-nygard
---

# Substrate hook spec — `requirement-annotation-check.sh`

## Purpose

This doc specifies the PreToolUse hook that should ship on bassclef substrate. It closes the gap the operator named in the iteration g discussion — CI enforcement is a failsafe, not a subsystem. This hook is the subsystem shape.

The hook fires at write time. It blocks Edit / Write / MultiEdit calls that break the requirement traceability chain. Bassclef adopters (bassclef-cli today; more later) inherit the hook via substrate sync at every SessionStart.

Not shipped. This doc is Phase 2 concrete-shape evidence for the Traceability Subsystem promote at `docs/promotes/2026-08-11-traceability-subsystem.md`. When Phase 2 opens, this spec becomes the reference for the substrate PR.

## Sources read

- `.claude/hooks/assert-verify-steering.sh` (sibling — same PreToolUse pattern for a different discipline)
- `.claude/hooks/turn-prose-kiss-check.sh` (sibling — Stop event; scans latest assistant message)
- `.claude/hooks/compound-noun-scrub.sh` (sibling — PreToolUse Edit / Write on prose files)
- `.claude/hooks/pattern-annotation-validate.sh` (closest sibling — checks `@pattern` annotations)
- `tests/requirements-traceability.test.ts` in bassclef-cli (the applied test case; hook mirrors the same algorithm)
- `docs/requirements/2026-08-11-npm-distribution.md` (registry shape the hook parses)

## Design

### Trigger

- Event — `PreToolUse`
- Tool matcher — `Edit|Write|MultiEdit`
- Path matcher — files matching `src/**/*.{ts,tsx,js,jsx}`, `scripts/**/*.{mjs,js,sh}`, `tests/**/*.{ts,tsx,js,jsx}`, `vite.config.ts`, `tsconfig.json`, and `docs/requirements/*.md`

The hook stays silent on paths outside the matcher (docs, ADRs, chronicles, config that does not touch traceability).

### Inputs

Standard bassclef PreToolUse hook contract per the substrate:

- JSON payload on stdin — carries `tool_name`, `tool_input.file_path`, and `tool_input.new_string` (Edit) or `tool_input.content` (Write)
- Env vars — `CLAUDE_PROJECT_DIR` (adopter repo root), `BASSCLEF_DIR` (substrate location)

### Behavior

Per write call:

1. Read the adopter's registry. Path resolves against `docs/requirements/*.md` (glob; picks the newest by mtime if multiple). If no registry exists, exit 0 with a stderr note — the discipline does not fire on repos that have not opted in.
2. Parse the registry to get satisfied non-meta requirement IDs. Same parser shape as `tests/requirements-traceability.test.ts` `parseRegistry()`.
3. Read the file path being written. Determine the class — source, test, or registry — from the path matcher.
4. Extract annotations from the file's new content (`@requirement R-XXX-NNN` for source, `@verifies R-XXX-NNN` for tests).
5. Apply the checks (below).
6. On failure, exit 2 with a structured stderr message per `.claude/rules/blocked-items.md`.

### Checks

Per class, at write time:

**Source file (src/, scripts/, vite.config.ts, tsconfig.json):**

- If the file is BEING CREATED (Write) and its path is under a directory that satisfies at least one existing requirement per the registry, warn if no `@requirement` annotation appears. Do NOT block — the file may be an internal helper.
- If any `@requirement` annotation references an ID NOT in the registry, block with an orphan-ID message.
- If the file previously carried `@requirement R-XXX-NNN` and the new content removes it, and the requirement's status is `satisfied` per the registry, and no other source file carries the same ID, block with a "removing sole satisfier" message.

**Test file (tests/):**

- Same shape as source but for `@verifies` annotations.

**Registry file (docs/requirements/*.md):**

- Detect status flips (satisfied → GAP or GAP → satisfied) by diffing the pre-image against the new content.
- If a row flips satisfied → GAP, warn (usually intentional; sometimes a mistake).
- If a row flips GAP → satisfied and no source or test file carries the annotation yet, block with a "declare-then-implement" message asking the operator to add annotations in the same PR.

### Failure format

Per bassclef `blocked-items.md` protocol:

```
🛑 requirement-annotation-check — BLOCKED

  File: <path>
  Class: source | test | registry
  Reason: <one of the check names above>

  Detail:
    <one or two lines describing the specific issue>

  Cure:
    <one or two paths the operator can take>

  Override: SKIP_REQUIREMENT_ANNOTATION_CHECK=1 <command>
  Logged: state/markers/hook-overrides/<timestamp>.log

  See docs/requirements/*.md (registry) and
  <substrate-doc-path>/requirement-annotation-check.md (this hook).
```

### Override paths

- Per-call — `SKIP_REQUIREMENT_ANNOTATION_CHECK=1` env var. Logged to `state/markers/hook-overrides/` per bassclef existing hook idiom.
- Per-adopter — `.claude/bassclef-configs.jsonc` field `traceability.enforcement: false`. Turns off the hook entirely for the adopter. Useful for repos that do not yet ship a registry.

### Composition with existing bassclef hooks

- `pattern-annotation-validate.sh` — closest sibling. Same shape (PreToolUse, scan annotations, validate against a catalog). This hook is a sister — annotations point at requirements instead of patterns.
- `assert-verify-steering.sh` — different discipline; both fire in the same event stream. Cooperate cleanly; each looks at different content.
- `pre-build-gate.sh` — later gate. Runs at commit time (via git pre-commit). Complements the write-time gate; catches drift the write-time hook missed.

## Bash implementation sketch

Not runnable today. Compiles once bassclef substrate ships the `lib/hook-inject.sh` helpers per the existing substrate pattern.

```bash
#!/bin/bash
# @requirement R-BSC-TRACE-001  (bassclef-side registry when the promote lands)
#
# requirement-annotation-check.sh — PreToolUse gate for
# @requirement + @verifies annotations. Phase 2 of the Traceability
# Subsystem promote.
#
# install-class: dual  (per standards/hook-install-class.md)

set -euo pipefail

# Source the shared bassclef helpers.
# shellcheck source=/dev/null
source "${BASSCLEF_DIR}/lib/hook-inject.sh"

# Read the tool call JSON on stdin.
INPUT_JSON=$(cat)
TOOL_NAME=$(echo "$INPUT_JSON" | jq -r '.tool_name')
FILE_PATH=$(echo "$INPUT_JSON" | jq -r '.tool_input.file_path // empty')

# Only fire on Edit / Write / MultiEdit with a file_path.
case "$TOOL_NAME" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac
[ -z "$FILE_PATH" ] && exit 0

# Explicit operator override.
if [ "${SKIP_REQUIREMENT_ANNOTATION_CHECK:-0}" = "1" ]; then
  echo "requirement-annotation-check: SKIP set; skipping." >&2
  trace_log "override_set" "SKIP_REQUIREMENT_ANNOTATION_CHECK=1 on $FILE_PATH"
  exit 0
fi

# Per-adopter opt-out from bassclef-configs.jsonc.
if config_flag_off "traceability.enforcement"; then
  exit 0
fi

# Locate the registry. Skip silently if the adopter has not opted in.
REGISTRY=$(find_adopter_registry "$CLAUDE_PROJECT_DIR")
[ -z "$REGISTRY" ] && exit 0

# Classify the write target.
CLASS=$(classify_path "$FILE_PATH")
case "$CLASS" in
  source|test|registry) ;;
  *) exit 0 ;;
esac

# Extract annotations from the new content.
NEW_CONTENT=$(echo "$INPUT_JSON" | jq -r '.tool_input.new_string // .tool_input.content // empty')

# Parse registry IDs (satisfied set).
mapfile -t REGISTRY_IDS < <(parse_registry_ids "$REGISTRY")
mapfile -t SATISFIED_IDS < <(parse_registry_satisfied "$REGISTRY")

# Run the checks per class.
case "$CLASS" in
  source) check_source "$FILE_PATH" "$NEW_CONTENT" "${REGISTRY_IDS[@]}" ;;
  test)   check_test   "$FILE_PATH" "$NEW_CONTENT" "${REGISTRY_IDS[@]}" ;;
  registry) check_registry "$FILE_PATH" "$NEW_CONTENT" ;;
esac
```

Each `check_*` function returns 0 on pass, 2 on block. Each block writes the structured failure format above to stderr, logs to trace, and calls `exit 2`.

The helpers (`find_adopter_registry`, `classify_path`, `parse_registry_ids`, `parse_registry_satisfied`, `check_source`, `check_test`, `check_registry`, `config_flag_off`, `trace_log`) live in a new `lib/traceability.sh` that ships alongside the hook.

## Testing

Same tier as other bassclef substrate hooks. Tier 0 strict TDD.

Test file — `.claude/hooks/tests/requirement-annotation-check.test.sh` (bash test suite per bassclef pattern).

Cases (at minimum):

1. Passes when tool is not Edit / Write / MultiEdit.
2. Passes when file_path is empty.
3. Passes when SKIP env is set (with trace log).
4. Passes when adopter opts out via config.
5. Passes when no registry exists.
6. Source path — annotation present and valid — pass.
7. Source path — orphan ID annotation — block, exit 2.
8. Source path — annotation missing (Write on new file) — warn, exit 0 (not block).
9. Source path — removes sole satisfier of a satisfied requirement — block, exit 2.
10. Test path — same shape as source (three cases).
11. Registry path — flips satisfied → GAP — warn, exit 0.
12. Registry path — flips GAP → satisfied without paired annotation — block, exit 2.

## Applied test case in bassclef-cli

The Vitest at `tests/requirements-traceability.test.ts` in bassclef-cli (PR #17 merged 2026-08-11 at commit 77c2817) proves the algorithm holds. This hook uses the same parser + same annotation shapes + same registry format. Adopting the hook on substrate means the algorithm ports cleanly.

The bassclef-cli test file exercises 8 assertions today. The hook adds a real-time layer on top; the CI Vitest becomes the safety net for cases the hook misses (multi-file coordinated changes; branch merges that reintroduce drift).

## Composition with git pre-commit hook

Iteration g in bassclef-cli ships `scripts/pre-commit-traceability.sh` — a git-side pre-commit hook that fires the traceability test before commit. Three gates now exist:

1. **This hook (proposed)** — PreToolUse Edit / Write. Fires at author time. Blocks the write before disk touches.
2. **Git pre-commit (iteration g)** — fires before `git commit` finalizes. Catches drift a bypassed substrate hook missed.
3. **Workflow checks job (iteration d)** — fires on push / release. Catches drift a bypassed pre-commit missed.

Defense in depth. The substrate hook is the primary; the other two are safety nets.

## Composition with the Traceability Subsystem promote

This spec extends the promote's Phase 2 with concrete design. When Phase 2 opens as its own iteration, the substrate PR ships:

- `.claude/hooks/requirement-annotation-check.sh` per this spec
- `lib/traceability.sh` helpers
- `.claude/hooks/tests/requirement-annotation-check.test.sh` (Tier 0)
- Wire in `.claude/settings.json` under `hooks.PreToolUse`
- Updates to `standards/traceability-subsystem.md` naming the hook

Every adopter that syncs bassclef substrate inherits the hook. bassclef-cli's Vitest becomes the CI safety net; adopters do not need to write their own.

## Open questions for the substrate reviewer

- **Config field placement.** `traceability.enforcement: false` — does bassclef prefer this under `bassclef-configs.jsonc` or under `.claude/settings.json`? Convention is not fully written down yet.
- **Registry discovery.** Adopter's registry might live at `docs/requirements/*.md` or `standards/requirements/*.md` or elsewhere. Should the hook scan a fixed set of paths or read the location from config?
- **Multi-registry.** An adopter may ship multiple registries (one per subsystem). Does the hook aggregate or check per-file scope? The bassclef-cli case has one; larger adopters may want more.
- **Annotation shape.** `@requirement` vs `@requires` vs something else. Aligned with `@pattern` today; verify no conflict.

Reviewer feedback on these unblocks the substrate PR.

## Refs

- Traceability Subsystem promote — `docs/promotes/2026-08-11-traceability-subsystem.md`
- Applied test case — `docs/requirements/2026-08-11-npm-distribution.md` + `tests/requirements-traceability.test.ts`
- Git pre-commit bridge — `scripts/pre-commit-traceability.sh` (iteration g, PR #21 merged)
- Sister OOAD promotes — bassclef-upstream #1167..1171
- Anchoring luminaries — `alexander-egyed` (transitive consistency), `john-ousterhout` (deep modules; small hook interface), `michael-nygard` (stability patterns; the hook is a circuit breaker at write time)
