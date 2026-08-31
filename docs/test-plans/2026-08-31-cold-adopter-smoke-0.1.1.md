---
tier: upstream
title: Cold adopter smoke test — @thebassclef/core@0.1.1
date: 2026-08-31
type: test-plan
scope: local, second macOS user profile, from-scratch install
audience: operator (kingofrock)
---

# Cold adopter smoke — 0.1.1 from a second macOS profile

**Why this test exists.** 0.1.0 shipped broken (issue #45). 0.1.1 ships the cure. The install-then-init path is the first thing every new adopter runs. This test proves it works from a machine state that has never seen bassclef before.

**What "cold" means here.** A macOS user profile that has never run `bassclef`. No `.claude/`, no `~/.npm/` bassclef entries, no cached tarballs, no old package left behind.

**Duration.** ~10 minutes end-to-end.

**Signals of success.** Numbered in the checklist below. Any FAIL → stop, capture output, file an issue.

---

## Step 1 — Log in as the second profile

Log out of `sanjay2025` and log in as your other user. Confirm the shell prompt shows the other user's name.

**Signal:** `whoami` returns the second profile's username.

---

## Step 2 — Verify Node is available

Bassclef requires Node.js 20 or newer. The other profile may have Node from Homebrew, nvm, or nothing at all.

```
node --version
npm --version
```

**Signal:**
- Node prints `v20.x` or higher
- npm prints `10.x` or higher

**If Node is missing:** install via `brew install node` OR nvm. Capture what the install path looks like — that's real cold-adopter signal.

---

## Step 3 — Confirm no bassclef install lingers

The other profile should have nothing. Verify:

```
which bassclef
npm ls -g @thebassclef/core 2>/dev/null
ls ~/.claude/ 2>/dev/null
```

**Signal:**
- `which bassclef` returns nothing (or "not found")
- npm ls shows no `@thebassclef/core`
- `~/.claude/` may or may not exist depending on Claude Code prior use — either state is fine

**If old bassclef state shows up (or between test runs):** use the reset helper.

If you have the bassclef-cli repo checked out under this profile:

```
bash scripts/smoke-reset.sh --dry-run   # preview
bash scripts/smoke-reset.sh             # apply
```

If you do NOT have the repo checked out under this profile, run manually:

```
npm uninstall -g @thebassclef/core
rm -rf ~/tmp/bassclef-smoke-test
```

The reset helper leaves `~/.claude/`, `~/.npm/` cache, and all other repos untouched — it only removes the global `@thebassclef/core` install and the smoke test work dir at `~/tmp/bassclef-smoke-test`.

---

## Step 4 — Install from the live npm registry

```
npm install -g @thebassclef/core
```

**Signals of success:**
- Exit code 0
- Output names `@thebassclef/core@0.1.1` (not 0.0.2, not any earlier version)
- No warnings about deprecated deps or missing peer deps

**Verify the install:**

```
bassclef --version
```

**Signal:** prints `0.1.1`.

---

## Step 5 — Create a fresh directory and run init

```
mkdir -p ~/tmp/bassclef-smoke-test && cd ~/tmp/bassclef-smoke-test
bassclef init
```

**Signals of success:**
- Exit code 0
- Output line: `bassclef init: 147 substrate files copied.`
- Output line: `bassclef init: 2 created, 0 unchanged.`
- Final line names `.claude/` and suggests adding it to `.gitignore`

**Count the files:**

```
find . -type f | wc -l
```

**Signal:** prints `150`. Breakdown: 2 config files + 1 init manifest + 147 substrate files.

**If the count is 2 or 3:** 0.1.0-style breakage returned. Capture the init output and file an issue immediately.

---

## Step 6 — Inspect what actually landed

```
ls -la
ls .claude/
```

**Signals of success:**
- `.claude/`, `substrate.config.md`, and `.bassclef/` exist at top level
- `.claude/` contains `agents/`, `hooks/`, `luminaries/`, `rules/`, `skills/`, `settings.json`

```
ls .claude/skills/ | wc -l
```

**Signal:** prints a number in the mid-30s (36 skills at this manifest version).

---

## Step 7 — Try bassclef subcommands

```
bassclef --help
bassclef sync --help
bassclef migrate --help
```

**Signal:** each prints a usage block naming the flags for that command. No stack traces.

---

## Step 8 — Try `bassclef sync --dry-run`

```
bassclef sync --dry-run
```

**Signal:** exit 0, output lists what sync would do without writing anything. No error about missing manifest.

---

## Step 9 — Optional: open Claude Code in the test dir

If Claude Code is set up under this profile:

```
claude
```

Type `/skills` to browse the bassclef skill catalog. **Signal:** the catalog renders with skills grouped by discovery cluster.

If Claude Code is not set up, skip this step. The test's core signals (steps 5 + 6) already prove the install works.

---

## Step 10 — Clean up

If you have the bassclef-cli repo checked out under this profile:

```
cd ~
bash <path-to-bassclef-cli>/scripts/smoke-reset.sh
```

Otherwise manual:

```
cd ~
npm uninstall -g @thebassclef/core
rm -rf ~/tmp/bassclef-smoke-test
```

Verify uninstall:

```
which bassclef
```

**Signal:** returns nothing.

---

## Result reporting

Write a one-line summary as a note to yourself:

- ✅ or ❌ per step 1 through 10
- If any FAIL: paste the full command output from that step

If all green: 0.1.1 works for cold adopters on macOS. Ship confidence.

---

## What this test does NOT cover

- Linux adopters (needs a Linux VM or a Linux CI runner)
- Windows adopters (needs a Windows VM; known gap around `writeSafely` and Windows path separators — file separate issue if you find one)
- Upgrade path from 0.0.2 to 0.1.1 (that's what `bassclef migrate` is for; separate test plan)
- Long-running sessions inside Claude Code (that's substrate-behavior testing, not install testing)

---

## Related

- Issue #45 — the defect this release cures
- PR #47 — the fix
- PR #48 — the CI workflow reorder
- ADR-007 §Amendment 2026-08-31 — the manifest-write contract
- CHANGELOG.md — 0.1.1 entry
