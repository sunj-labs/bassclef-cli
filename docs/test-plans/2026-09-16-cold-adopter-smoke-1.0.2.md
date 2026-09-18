---
tier: upstream
title: Cold adopter smoke — @thebassclef/lite@1.0.2
date: 2026-09-16
type: test-plan
scope: local, second macOS user profile (cold-adopter-1), from-scratch install
audience: operator (kingofrock) OR Claude executing on the cold-adopter-1 profile
---

# Cold adopter smoke — 1.0.2 (install-class dispatch)

**Why this test exists.** Cli 1.0.1 shipped with an incomplete upstream lite bundle (bassclef v0.40.0). Cold-adopter-1 first `claude` session hit a cascade of `source: No such file or directory` errors from `trace-helper.sh`, `session-reflection.d/`, and 8 `lib/*.sh` modules. Cli 1.0.2 pins upstream v0.42.0 which bundles all of them, plus adds install-class dispatch (bassclef-upstream#1682 goal 14c Step 6). Hooks now split between `~/.claude/hooks/` (operator scope) and `<repo>/.claude/hooks/` (project scope) based on each hook's `install-class` header.

This test proves 1.0.2 cures the cascade end-to-end.

**What "cold" means here.** The cold-adopter-1 profile was reset clean 2026-09-14 per `scripts/smoke-reset.sh --clean-home` — `~/.claude/` moved to `.claude.bak.2026-09-14T08-03-38Z`, global `@thebassclef/lite` uninstalled, work dir gone.

**Duration.** ~10 minutes end-to-end.

**How Claude runs this plan.** Paste this into a fresh `claude` session on cold-adopter-1:

```
Execute the cold-adopter smoke test at https://raw.githubusercontent.com/sunj-labs/bassclef-cli/main/docs/test-plans/2026-09-16-cold-adopter-smoke-1.0.2.md. Run each step in order. After each step, print the signal check result. Stop on the first FAIL and capture the offending output.
```

**Signals of success.** Each step names its own signal. Any FAIL → stop, capture output, paste into a comment on bassclef-cli#82.

---

## Step 0 — Confirm profile

```
whoami
echo "HOME=$HOME"
```

**Signal:**
- `whoami` returns `cold-adopter-1` (or the second-profile username, NOT `sanjay2025`)
- `HOME` does NOT contain `sanjay2025`

**If wrong profile:** log out, log into cold-adopter-1, restart.

---

## Step 1 — Verify Node + npm

```
node --version
npm --version
```

**Signal:**
- Node: `v20.x` or higher (v22 recommended per bassclef-cli#66)
- npm: `10.x` or higher

**If Node is missing:** install via `brew install node` OR nvm. Capture the install path — that's real cold-adopter signal.

---

## Step 2 — Confirm no lingering install

```
which bassclef
npm ls -g @thebassclef/lite 2>/dev/null
npm ls -g @thebassclef/core 2>/dev/null
ls -la ~/.claude/ 2>/dev/null | head -3
ls ~/.claude.bak.* 2>/dev/null | head -3
```

**Signal:**
- `which bassclef` returns nothing (or "not found")
- Both `npm ls -g` show empty
- `~/.claude/` either doesn't exist OR shows the backup from 2026-09-14

**If old install lingers OR you want a clean slate between re-runs:** run the reset.

```
# fetch reset script from main
curl -sL -o /tmp/smoke-reset.sh https://raw.githubusercontent.com/sunj-labs/bassclef-cli/main/scripts/smoke-reset.sh
chmod +x /tmp/smoke-reset.sh
bash /tmp/smoke-reset.sh --dry-run --cold
# review output, then apply:
bash /tmp/smoke-reset.sh --cold
```

The `--cold` flag is shorthand for `--clean-home --yes`. One flag, re-runnable.

What the reset cleans:
- Global `@thebassclef/lite` (and legacy `@thebassclef/core`)
- Work dir at `~/tmp/bassclef-smoke-test`
- `~/.claude/` — moved to `~/.claude.bak.<ISO-timestamp>` (never deleted; every reset creates a fresh backup)

What the reset leaves alone: other repos, `~/.npm/` cache, and any `~/.claude.bak.*` archives from prior runs.

---

## Step 3 — Install 1.0.2 from live npm

```
npm install -g @thebassclef/lite@1.0.2
```

**Signals of success:**
- Exit code 0
- npm output names `@thebassclef/lite@1.0.2` (not any prior version)
- No warnings about deprecated peer deps

**Verify:**

```
bassclef --version
npm view @thebassclef/lite version
```

**Signal:**
- `bassclef --version` prints `1.0.2`
- `npm view` prints `1.0.2` (they match)

---

## Step 4 — Create fresh work dir + init

```
mkdir -p ~/tmp/bassclef-smoke-test && cd ~/tmp/bassclef-smoke-test
git init -q
bassclef init
```

**Signals of success:**
- Exit code 0
- Banner line: `Installed N of M hooks (lite tier). N in <repo>/.claude/hooks, M in ~/.claude/hooks.`
- **BOTH counters non-zero** — that's the install-class dispatch working
- Final summary line: `N files total (2 config + N-2 substrate)` where N ≈ 290
- Suggests adding `.claude/` to `.gitignore`

**Count the hooks landed per scope:**

```
ls ~/.claude/hooks/ | wc -l
ls .claude/hooks/ | wc -l
```

**Signal:**
- `~/.claude/hooks/` count is at least 1 (operator-scope hooks)
- `.claude/hooks/` count is at least 1 (project-scope hooks)
- Sum matches the banner's total

**If either count is 0:** install-class dispatch broke. Capture banner + both `ls` outputs, paste into cli#82.

---

## Step 5 — Verify the cure — no source errors

The 1.0.1 crash class was bundled hooks sourcing files that were never in the tarball. Verify the tarball now carries them.

```
ls ~/.claude/hooks/trace-helper.sh .claude/hooks/trace-helper.sh 2>/dev/null
ls ~/.claude/hooks/session-reflection.d/ .claude/hooks/session-reflection.d/ 2>/dev/null | head -5
ls ~/.claude/hooks/lib/*.sh .claude/hooks/lib/*.sh 2>/dev/null | head -5
```

**Signal:** at least one path in each row exists. Absence in one scope is fine (install-class routes each file to one scope); absence in BOTH is a fail.

---

## Step 6 — Open Claude Code

```
claude
```

**Watch for at SessionStart:**
- No red error blocks
- No `SessionStart:startup hook error` messages
- No `trace-helper.sh: No such file or directory`
- No `session-reflection.d: No such file or directory`
- No cascade of missing `lib/*.sh` sources

**Signal:** `claude` opens the interactive prompt cleanly. Substrate banner shows some skill / rule / hook counts.

Type `/skills` and press enter.

**Signal:** the skill catalog renders. No stack traces.

Exit with Ctrl+D or `/exit`.

---

## Step 7 — Quick sanity checks

```
bassclef --help
bassclef sync --help
bassclef migrate --help
```

**Signal:** each prints a usage block. No stack traces.

---

## Automated evidence capture (post 2026-09-18 — goal 2026-09-18a)

Steps 5, 6, 7 above are eyeball checks. As of 2026-09-18 they have an
automated counterpart that captures per-hook + per-skill output to
files, runs four checks per capture, writes one report, and posts as a
GitHub issue on `sunj-labs/bassclef-cli` with the `smoke-run-v1` label.

The automated version does NOT replace the eyeball checks yet — the
plan doc keeps Steps 5-7 for operators who want to eyeball. The
automated scripts run alongside and produce a durable artifact that
survives the session (whereas an eyeball pass leaves no trail).

Ship (from goal 2026-09-18a):

- `scripts/smoke-capture.sh` — fires wired SessionStart hooks; writes
  one file per hook under `docs/smoke-captures/<date>/hooks/`
- `scripts/smoke-assert-hooks.sh` — runs four checks per hook capture
- `scripts/smoke-drive-skills.sh` — fires five skills via `claude -p`;
  writes one file per skill under `docs/smoke-captures/<date>/skills/`
- `scripts/smoke-assert-skills.sh` — runs same four checks per skill
- `scripts/smoke-report.sh` — builds report; optional `--publish` posts
  as GitHub issue with `smoke-run-v1` label; idempotent per version+date
- `scripts/smoke-reset-whole.sh` — reset with snapshot + `--restore`

To use them after Step 4 above:

```bash
# from ~/tmp/bassclef-smoke-test (where bassclef init ran)

# capture SessionStart hooks
bash /path/to/bassclef-cli/scripts/smoke-capture.sh

# capture 5 skills (needs `claude` on PATH)
bash /path/to/bassclef-cli/scripts/smoke-drive-skills.sh

# assert both surfaces
bash /path/to/bassclef-cli/scripts/smoke-assert-hooks.sh
bash /path/to/bassclef-cli/scripts/smoke-assert-skills.sh

# build report and post as issue
bash /path/to/bassclef-cli/scripts/smoke-report.sh \
  --version-tag 1.1.1 \
  --publish
```

The exit code of `smoke-report.sh` is 0 when all checks pass, 3 when
any check fails, 4 when publish itself fails.

For a per-check drill-down after a RED smoke, use `--only`:

```bash
bash /path/to/bassclef-cli/scripts/smoke-assert-hooks.sh --only paths-exist
```

Design refs: `docs/iteration-bets/2026-09-18a-smoke-evidence-capture.md`,
`docs/specs/smoke-evidence-capture.md`, `docs/use-cases/UC-smoke-run.md`.

Note on npm provenance (per pre-mortem D4 fold): before installing at
Step 3 above, verify the provenance badge on the npm package page. Any
mismatch is a real smoke signal, not a routine check.

---

## Step 8 — Clean up (optional; use before every re-run)

Between smoke runs on the same profile, run the reset again:

```
cd ~
bash /tmp/smoke-reset.sh --cold
```

Verify:

```
which bassclef
```

**Signal:** returns nothing.

The `--cold` flag is idempotent — running it twice in a row yields the same clean state on the second run (nothing to uninstall, nothing to remove).

Leave the profile as-is if you plan to iterate without a reset.

---

## Result reporting

Post one of these two comments to bassclef-cli#82:

**If all green:**

> Cold-adopter-1 smoke on live `@thebassclef/lite@1.0.2` — all steps green.
> - `bassclef init` reported both scope counters non-zero (install-class dispatch confirmed)
> - `claude` opened clean, no source errors, no cascade
> - `/skills` catalog rendered
>
> The 1.0.1 crash class is cured. Closing.

**If any FAIL:**

Paste the full stderr from the failing step + the step number. I'll diagnose.

---

## What this test does NOT cover

- Linux adopters (needs a Linux VM or Linux CI runner)
- Windows adopters (known gap around Windows path separators)
- Upgrade path from 1.0.1 → 1.0.2 in place (that's `bassclef sync` / manifest-update; separate test)
- Long-running sessions (that's substrate behavior, not install)

---

## Related

- bassclef-cli#82 — the cold-adopter tracker this smoke result closes
- bassclef-cli#84 — the pin bump PR that shipped 1.0.2 (commit `3d90892`)
- bassclef-upstream#1682 — install-class dispatch (merged `a9832a81`)
- bassclef#1492 — release cascade to public bassclef (merged `d99cdede`)
- Prior 0.1.1 smoke plan: `docs/test-plans/2026-08-31-cold-adopter-smoke-0.1.1.md`
- Prior 1.0.1 diagnosis: `docs/session-logs/2026-09-14-cli-1.0.1-cold-adopter-smoke-diagnosis.md`
- CHANGELOG.md — 1.0.2 entry
- Wake-up flow this test closes: `docs/session-logs/2026-09-14-cli-1.0.1-cold-adopter-smoke-diagnosis.md § Wake-up hand-off` Step 11
