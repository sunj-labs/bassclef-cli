---
tier: standard
ticket: cli#nuke-and-fresh-install
title: UC-script-nuke-and-fresh-install — Cold adopter runs one-command fresh install
scope: scripts/nuke-and-fresh-install.sh
level: user goal
primary_actor: cold-adopter
authoring_luminaries:
  lead: alan-cooper
  supporting: [michael-feathers]
---

# UC — Cold adopter: one-command fresh install of @thebassclef/lite

**Primary actor:** cold adopter on a fresh Mac or Linux profile.

**Stakeholders + interests:**

- **Cold adopter** — wants a fresh cli install with zero cruft from any prior state, without pasting multi-line command blocks that get mangled by zsh.
- **Bassclef maintainer** — wants smoke-test runs to start from a truly cold state so results are reproducible.

**Precondition:** cold-adopter machine has `node`, `npm`, and `curl` on PATH. Network reaches `raw.githubusercontent.com` and `registry.npmjs.org`.

**Trigger:** cold adopter pastes a single `curl ... | bash` line into their terminal.

## Main success scenario

1. Adopter pastes the curl one-liner: `curl -sSL https://raw.githubusercontent.com/sunj-labs/bassclef-cli/main/scripts/nuke-and-fresh-install.sh | bash`
2. Script cd's to `$HOME` so any stale CWD stops mattering.
3. If `~/.claude` exists, script moves it to `~/.claude.bak.<timestamp>`.
4. If old global `@thebassclef/lite` install exists, script uninstalls it (silent when none).
5. Script runs `npm install -g @thebassclef/lite@latest`.
6. Script purges `~/tmp/bassclef-smoke-test`.
7. Script creates `~/tmp/bassclef-smoke-test`, cd's into it, runs `git init -q` with inline identity.
8. Script runs `bassclef init` in the fresh workdir.
9. Script prints a summary line naming the installed version + workdir + backup path (or "no backup" when `~/.claude` was absent).

**Postcondition:** adopter has a fresh cli install and a fresh test workdir. No paste-mangling risk. Old `~/.claude` is safe at the backup path.

## Extensions

- **1a. Curl fails to reach GitHub raw.** Adopter sees curl error and exits non-zero. No state changes. Adopter retries or checks network.
- **3a. `~/.claude` is a symlink.** Script refuses to follow (lstat check), backs up the symlink itself. Adopter sees a note.
- **5a. `npm install` fails (network, registry down, bad version).** Script exits non-zero. `~/.claude.bak.<timestamp>` remains; old global cli remains uninstalled. Adopter can restore `~/.claude` via one `mv` and retry.
- **8a. `bassclef init` fails.** Script exits non-zero. Adopter has fresh cli but no initialized workdir; can rerun `bassclef init` manually.

## Flags

- `--version VER` — install a specific npm version instead of `latest`. Default: `latest`.
- `--workdir PATH` — target workdir. Default: `~/tmp/bassclef-smoke-test`.
- `--keep-claude` — do not back up `~/.claude`. Default: back up.
- `--dry-run` — print steps + exit 0. No state changes.
- `--help` / `-h` — print usage.

## Non-goals

- Does NOT drive skills, run smoke assertions, or open a report. Use `scripts/smoke-one-shot.sh` for that.
- Does NOT restore the backup. Adopter restores with `mv ~/.claude.bak.<timestamp> ~/.claude`.
- Does NOT touch `~/.nvm`, `~/.zshrc`, or any auth token file.

## Composes with

- `scripts/smoke-one-shot.sh` — end-to-end smoke chain, includes install step via its own `--install` flag. This script is the minimal-install-only sibling.
- `scripts/smoke-reset.sh` — reset-only sibling (uninstall + purge + back up `~/.claude`). This script adds the install step.
- `.claude/rules/oo-ad-entry-point.md` — brief UC + Tier 0 tests obligation for adopter-facing scripts.
