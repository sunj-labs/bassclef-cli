---
name: publish
description: "Cut an npm release of @thebassclef/lite. Three words — status reads the gate and what would ship; publish bumps, tags and leaves the publish waiting for your click; trust clears that wait for one publish, when you say so."
problem: "Cutting a release means six steps in order, and the approval gate is a shell script with a flag nobody remembers. Some nights the operator wants to trust the release and sleep."
value: "One word ships it. A second word ships it without waiting for you. The gate goes back on either way."
tier: standard
user_invocable: true
disable_model_invocation: true
modes: [status, publish, trust]
composes_with: [temperance, verify]
---

# /publish — cut a release of @thebassclef/lite

## What you get

`/publish status` tells you the gate state and what would ship. Nothing moves.

`/publish` bumps the version, opens a release PR, merges it on green, and
creates the release. The workflow then stops and waits for your click.

`/publish trust` does the same and clears the wait, so it publishes while you
sleep. The gate goes back on afterward.

## The one rule that matters

**You pick `trust`. An agent never does.**

`scripts/publish-gate.sh` says it in its own header: the gate's value is that
it "cannot be cleared by accident or by an agent acting on its own read of the
room." The `--authorized-by` argument exists to record who decided.

So this skill carries `disable_model_invocation: true` — the only skill in the
repo that does. An agent may not fire it. If you are an agent reading this
because the operator typed `/publish`, that is the operator's word and you
follow it. If you are considering `trust` because the release looks clean to
you, stop. A clean read is not authorization.

## Three words

| Word | What happens | Who waits |
|---|---|---|
| `status` | Reads the gate, the version, the last tag, the unreleased entries | nobody |
| *(none)* | Bump, PR, merge, release. Publish waits at the gate | you |
| `trust` | Same, with the gate cleared for one publish | nobody |

## Procedure

### Step 0 — read, before anything moves

```bash
bash scripts/publish-gate.sh status
node -p "require('./package.json').version"
git describe --tags --abbrev=0
awk '/^## \[Unreleased\]/,/^## \[[0-9]/' CHANGELOG.md | sed '$d'
```

Report all four. Under `status`, stop here.

A gate that reads `UNKNOWN` is not a gate that reads `OFF`. The script exits 2
when it cannot determine the state, and that is a stop, not a green light.

### Step 1 — check the preconditions and say which failed

- `gh auth status` succeeds.
- The `[Unreleased]` block is not empty. `npm run bump` refuses on an empty
  one, and that refusal is correct — a release with no changelog entry tells
  an adopter nothing.
- The working tree is clean apart from `state/markers/`.
- `main` is the merge base and nothing is unmerged that should ship.

Name the one that failed. Do not proceed past a failure.

### Step 2 — confirm, or take `trust`

Show the operator the version step and the changelog entries, then ask.

Two answers move forward: a confirmation, or the word `trust`.

### Step 3 — if `trust`, open the window

```bash
bash scripts/publish-gate.sh trust --authorized-by "$(git config user.name)"
```

Read it back. The script verifies its own write, and a zero exit is not
evidence on its own.

`trust` is its own verb now, not a spelling of `off`. It clears the gate and
writes a marker holding who authorized the window and when it closes — one
hour by default, or `--ttl <minutes>`. The marker is what re-arms the gate.

One authorization, one publish. That promise is kept as of #506. Before it,
nothing marked a window spent, so the deadline was the only thing that closed
one — and between the publish landing and the deadline the gate sat clear.
A window now ends on whichever comes first: its publish lands, its deadline
passes, or someone marks it spent.

The marker lives at `~/.bassclef/publish-trust.marker`, outside the
repository. A marker a `git reset` could erase would fail to re-arm, and
that fails the wrong way. Per #488.

Say in the turn prose that the gate is clear and when the window closes.

### Step 4 — bump

```bash
npm run bump patch     # or minor / major
```

This writes `package.json`, `src/index.ts`, `README.md` and `CHANGELOG.md`
together, then rebuilds `dist/`. Never hand-edit `package.json` — it leaves
the other three stale, which shipped a wrong version once already.

Then confirm the built bundle agrees:

```bash
node dist/cli.js --version    # must match package.json
```

### Step 5 — PR, and wait for its checks

Open the release PR per `.claude/rules/pr-body-shape.md`. Wait for all three
checks. The Docker cold-adopter smoke takes about fourteen minutes and it is
the one that exercises what an adopter actually runs, so do not skip it.

### Step 6 — merge, then release

```bash
gh pr merge <N> --squash --delete-branch
gh release create "v<version>" --title "v<version>" --notes-file <notes>
```

`publish.yml` fires on `release: published`. Job 1 runs the checks. Job 2 is
gated by the `npm-publish` environment: it waits if the gate is ON, and runs
if `trust` cleared it.

### Step 7 — restore the gate, always

```bash
bash scripts/publish-gate.sh rearm     # closes a trust window that is over, and consumes its marker
bash scripts/publish-gate.sh status    # read it back, and read the log
```

`rearm` restores the gate once the window is over, and says so when it is
still open. Either way it names the reason.

It does not *wait* on the publish — a failed, cancelled or hung release still
leaves a window that closes on its own terms. But as of #506 it does *ask*.
It queries `publish.yml` for a successful run created at or after the moment
the marker opened.
A query it cannot answer reads as "window over" and the gate goes back on,
because a question with no answer must not hold the gate open.

Why this is a read and not a write: the marker is a local file under `$HOME`,
and the publish runs on a GitHub runner that cannot reach it. Nothing on the
runner could ever have marked the window spent. The laptop has to go and ask.

Use `on` directly when you cleared the gate with `off` rather than `trust`.
As of #507 it clears a leftover marker either way, so the gate and the marker
cannot drift apart. Run this even when the release failed. Leaving the gate
clear turns a one-night decision into the new resting state.

**What still rests on someone running this.** `rearm` is a mechanism, but
nothing fires it on a schedule. Step 0 runs `status`, which names an open
window, or says a window is over and why, so the next publish cannot start
without the window being visible. A window left open between publishes stays
open. Tracked in #488.

`status` now ends with a line about the log. It walks the entries in order and
says whether every clear has a restore after it. A clear with no restore means
the window is still open; a restore with no clear before it means a clear was
written and then lost. Both read as `UNPAIRED`, and `publish-gate.sh audit`
prints the same thing on its own.

The log that counts lives outside the repo, at `~/.bassclef/publish-gate-audit.log`.
The copy in `state/` is for review and a `git reset` rewrites it — which is how
an authorization was lost on 2026-11-08. If the two disagree, `audit` says so
and the one outside the repo is the one to trust. Per #489.

### Step 8 — report, and verify against the registry

Say which run is in flight and what it is waiting for. Then verify the publish
landed — from the registry, not from a zero exit:

```bash
npm view @thebassclef/lite version
```

The registry lags about three minutes and the local cache returns `ETARGET`
before then. Read the `+ pkg@version` line in the publish log rather than
guessing from a failed `npm view`.

## What NOT to do

- **Don't run `npm publish` locally.** The workflow publishes, from the tag,
  with provenance via trusted publishing. A local publish skips the checks and
  the gate both. INSTEAD: create the release and let the workflow run.
- **Don't pick `trust` as an agent.** INSTEAD: report the gate state and ask.
  The operator's word is the authorization; your read of the diff is not.
- **Don't leave the gate OFF.** INSTEAD: Step 7, on every path including
  failure.
- **Don't hand-edit `package.json`.** INSTEAD: `npm run bump`, which touches
  all four files.
- **Don't treat a gate read of `UNKNOWN` as `OFF`.** INSTEAD: stop and say the
  state could not be determined.
- **Don't skip the cold-adopter smoke to save fourteen minutes.** INSTEAD: wait
  for it. It is the only check that runs `bassclef init` the way an adopter
  does.

## Where things are

| Thing | Path |
|---|---|
| The gate | `scripts/publish-gate.sh` |
| Who authorized what | `~/.bassclef/publish-gate-audit.log` (the record) |
| The same, for review | `state/publish-gate-audit.log` (a reset rewrites it) |
| An open trust window | `~/.bassclef/publish-trust.marker` |
| The workflow | `.github/workflows/publish.yml` |
| The contract | `docs/adrs/ADR-004-publish-pipeline-safety-contract.md` |
| The bump | `scripts/bump-version.mjs` |

## Why this lives here and not upstream

Everything above names something only this repo has — a gate script at a fixed
path, a GitHub Environment called `npm-publish`, a tag-triggered workflow, and
one package. An upstream version would have to read all four from config for
any adopter's package, and those config fields do not exist. If a second repo
needs this, `/promote` is the path.

## Composes with

- `scripts/publish-gate.sh` — the mechanical layer this skill drives
- `.claude/rules/destructive-operations.md` — npm publish is on its list
- `.claude/rules/guardrails.md` — human approval on production, the hardest one
- `docs/use-cases/UC-skill-publish.md` — the flows above, as a use case
- `@luminary saltzer-schroeder` — fail-safe defaults. Every failure path leans
  toward "approval required".
- `@luminary tony-hoare` — the gate script verifies its own write by reading
  back, because a zero exit is not a postcondition.
- `@luminary alan-cooper` — the operator asked for one short word, not a
  sentence. `trust` is that word.
