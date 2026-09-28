---
tier: standard
ticket: cli#281
level: brief
primary_actor: adopter running `bassclef init` for the first time
---

# UC-cli-281 — Rich statusline impl reaches cold adopter

## Primary actor

Adopter on a fresh machine running `bassclef init` for the first time. Has no bassclef sibling checkout at `~/src/sunj-labs/bassclef*`.

## Preconditions

- Adopter installed `@thebassclef/lite` globally via npm.
- Adopter has no existing `~/.claude/bassclef-statusline*.sh` files.
- Claude Code is installed and picks up user-scope `settings.json`.

## Main success scenario

1. Adopter runs `bassclef init` in a project directory.
2. Init copies the statusline dispatcher to `~/.claude/bassclef-statusline.sh`.
3. Init copies the rich statusline impl to `~/.claude/bassclef-statusline-rich.sh`.
4. Init merges the `statusLine.command` field into `~/.claude/settings.json` per the existing install-statusline flow.
5. Adopter opens Claude Code.
6. Claude Code calls the dispatcher every ~300 ms.
7. Dispatcher tries path 1 (`~/src/sunj-labs/bassclef/presence/cli/bassclef-statusline.sh`) — absent.
8. Dispatcher tries path 2 (`~/src/sunj-labs/bassclef-upstream/presence/cli/bassclef-statusline.sh`) — absent.
9. Dispatcher tries path 3 (`$SCRIPT_DIR/bassclef-statusline-rich.sh`) — resolves to `~/.claude/bassclef-statusline-rich.sh`, exists, executable.
10. Dispatcher execs the rich impl with stdin piped through.
11. Rich impl reads `$REPO_ROOT/bassclef-version.json` and `$REPO_ROOT/state/bassclef-sync-status.json`.
12. Rich impl emits a version-bearing line to stdout (e.g., `bassclef · not synced` when the version file is absent, or `bassclef v1.6.5 · up-to-date` after sync).
13. Claude Code renders the line as the statusline.

## Extensions

3a. Rich impl copy fails (permission denied, disk full).
- 3a.1. Init logs `bassclef init: statusline rich impl copy failed at $DEST — statusline may show ?`.
- 3a.2. Init continues with the rest of the install steps (statusline install is cosmetic; must not block init).
- 3a.3. Adopter can retry with `bassclef init --force`.

7a. Adopter has a sibling bassclef checkout at path 1 OR path 2.
- 7a.1. Dispatcher's sibling fast-path resolves; script-relative path 3 is not reached.
- 7a.2. Behavior matches current dev-environment shape (unchanged).

9a. Rich impl file was deleted from `~/.claude/` after init.
- 9a.1. Dispatcher path 3 misses.
- 9a.2. Dispatcher falls through to the `bassclef · ?` fallback (still exit 0).
- 9a.3. Adopter can restore via `bassclef init --force`.

11a. Repo has no `bassclef-version.json` at root (typical cold adopter state).
- 11a.1. Rich impl emits `bassclef · initializing` OR `bassclef · not synced` per its documented fallback shapes.
- 11a.2. First `bassclef-sync` run writes the state file and adopters see the version thereafter.

## Postconditions

- `~/.claude/bassclef-statusline.sh` exists and is executable (dispatcher).
- `~/.claude/bassclef-statusline-rich.sh` exists and is executable (rich impl).
- `~/.claude/settings.json` has `statusLine.command` pointing at the dispatcher.
- Init exit code reflects the substrate copy step result, not the statusline result (statusline is fail-soft).
- Adopter sees a version-bearing statusline line, not `bassclef · ?`.

## Refs

- cli#281 — this ticket
- bassclef-upstream#1961 — statusline feature ship
- bassclef-upstream#1981 defect A1 — dispatcher self-loop guard
- `src/lib/install-statusline.ts` — current statusline install step
- `dist/lite/presence/cli/bassclef-statusline.dispatcher.sh` — dispatcher body
- `dist/lite/presence/cli/bassclef-statusline.sh` — rich impl body
