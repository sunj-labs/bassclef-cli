---
tier: lite
---

# Cold-adopter baseline — `@thebassclef/lite@1.9.23`, substrate pin `v1.11.1`

**Captured** 2026-11-08 by the operator on a real cold-adopter profile
(`cold-adopter-1`, macOS), not in Docker.

**Why this exists.** `.bassclef-pin` is about to move from `v1.11.1` to
`v1.12.0`, which takes the lite hook set from **31 to 46**. That is 15 hooks
firing in adopter sessions for the first time. This is the before picture, so a
regression after the pin advance is visible rather than argued about.

Run again after the pin moves and diff against this file.

---

## 1. Install

```
curl -sSL .../nuke-and-fresh-install.sh | bash -s -- --purge-adopter
```

```
bash: moving ~/.claude → /Users/<user>/.claude.bak.20261108T023349Z
bash: uninstalling any prior @thebassclef/lite
bash: installing @thebassclef/lite@latest
added 1 package in 1s
bash: listing test repos under gh user '<user>' matching '*bassclef-smoke-test*'
bash: no matching GitHub repos
bash: preparing workdir /Users/<user>/tmp/bassclef-smoke-test
bash: running bassclef init
bassclef init: 1 config files created, 0 unchanged.
bassclef init: 554 files installed (1 config + 553 substrate).
bassclef init: Installed 31 of 31 hooks (lite tier). 29 in <repo>/.claude/hooks, 2 in ~/.claude/hooks.
bassclef init: your substrate lives under .claude/.
```

**Pin these numbers:**

| | Value |
|---|---|
| package | `@thebassclef/lite@1.9.23` |
| config files | 1 created, 0 unchanged |
| files installed | **554** (1 config + 553 substrate) |
| hooks | **31 of 31** (lite) — 29 project, 2 user |
| banner | brass wordmark, brass chip, dim tagline, version `1.9.23` |

The brass renders on a real terminal: wordmark in brass, `bassclef` as a chip
with dark text on brass, tagline dim. Matches the ANSI measured in Docker —
`38;5;179` on the art, `48;5;179` with `38;5;233` on the chip.

**Two known defects are visible in this capture**, both filed, both expected
to persist until fixed:

- `#493` — `1 config files created` should read "file". It is the first line
  a cold adopter reads.
- `#492` — the hook line is 102 columns and wraps on an 80-column terminal.

---

## 2. First `claude` — the instruction-budget warning

```
⚠ 81 instruction files add up to 478.0k chars, over the 150.0k-char total limit
  · largest: .claude/rules/compounding-sequence-fresh-analysis.md (17.1k),
    .claude/rules/test-sufficiency.md (17.0k),
    .claude/rules/visual-hierarchy.md (17.0k)
```

Claude Code v2.1.319.

### What the warning actually counts — measured, not assumed

Reproduced the figure exactly against a 1.9.23 install:

| Method | Chars | Delta vs 478.0k |
|---|---|---|
| raw file contents | 491,028 | +13,028 |
| minus YAML frontmatter | 478,171 | +171 |
| **minus frontmatter, trimmed** | **478,010** | **+10** |

Ten characters is rounding. So the count is:

> **81 files** — 79 under `.claude/rules/`, plus `CLAUDE.md` and
> `.claude/bassclef-orientation.md` — measured as **body text after YAML
> frontmatter is stripped**.

Two consequences worth carrying into `up#2238`:

- **Frontmatter is free.** 13,028 chars of it across 80 files do not count.
  Trimming frontmatter saves nothing.
- The ratio is **478,010 / 150,000 = 3.19x**.

This corrects an earlier figure of 481,327 that I posted to `up#2238`. That
was bytes, rules-only, and it measured the wrong thing.

---

## 3. First `/onboard-repo`

Read `.claude/bassclef-orientation.md` (190 lines), then one combined Bash
check of `.bassclef/`, `git remote -v`, branch, and git identity.

```
No blocked items surfaced by session-start hook.
```

Then:

- **Fresh install** — `.bassclef/init.manifest.json` written today at 02:33
- **No GitHub remote** — `git remote -v` returns nothing
- **On main** — setup scaffolding has to go on a branch
- **Ready** — git identity set, `gh` logged in

Offered two paths, both landing on a `chore/bassclef-bootstrap` branch:

1. Share on GitHub (recommended) — create the repo, push, set labels and
   branch protection, fill config and starter docs, all through a PR.
2. Add only the missing files — nothing goes to GitHub.

Closing with: `Pick 1 or 2. Type skip to see all the options.`

### The behaviour to protect

> *"I won't run the empty-repo starter here. `bassclef init` already set up
> this repo, and that path would overwrite `.claude/settings.json` and wipe
> out the hook setup."*

**That refusal is the baseline's most important line.** The skill detected
that a path available to it was destructive given the current state, and
declined it without being asked. If a post-pin run offers the empty-repo
starter on an already-initialised repo, that is a regression regardless of
what else improves.

---

## What to compare after the pin moves to `v1.12.0`

| Check | Baseline | Expectation at v1.12.0 |
|---|---|---|
| hooks installed | 31 of 31 | **46 of 46** — 15 added, none removed |
| files installed | 554 | higher; record the number |
| instruction files / chars | 81 / 478.0k | likely higher; record both |
| banner renders brass | yes | unchanged |
| `/onboard-repo` refuses the empty-repo starter | yes | **must stay yes** |
| session-start blocked items | none | record any new ones |

The 15 hooks the pin adds are listed in the session log for
2026-11-08. Three worth watching on first fire:
`destructive-command-guard.sh`, `role-entry-gate.sh`, `atomic-pr-check.sh` —
each can refuse an action, so each can refuse one it should not.

## Sources

- Operator terminal capture and two screenshots, 2026-11-08
- Reproduction of the char count against a Docker install of the same package
- `#492`, `#493` — the two defects visible in the install output
- `up#2238` — the instruction-budget ticket this corrects a figure for
