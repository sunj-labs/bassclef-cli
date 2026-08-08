---
tier: standard
id: ADR-002
title: Pin the safety contract for `bassclef init` — fail-safe defaults + atomic writes + path scoping
status: accepted
date: 2026-08-06
accepted: 2026-08-08
accepted_via: PR #4 merged — WU-2 init command shipped the safety contract this ADR pins
supersedes: null
superseded_by: null
---

# ADR-002 — Pin the safety contract for `bassclef init` — fail-safe defaults + atomic writes + path scoping

## Context

WU-2 of iteration bet `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md`
lands the first `@thebassclef/core` command that writes files to a
user's disk. `bassclef init` creates two files under the target
directory:

- `.claude/settings.json`
- `substrate.config.md`

(`.claude/kilo.json` deferred to a later WU pending Kilo schema
decision — see decomposition N1.)

This package is public. The command runs on user machines the
maintainers do not control. Every choice about default behavior
becomes part of a contract that later versions cannot break without
tripping ADR-031 (we-don't-break-adopters).

Forces at play:

- **First adopter install is the highest-blast-radius moment.** If
  init silently overwrites Sam's existing Claude Code config, we
  lose her before she runs the second command.
- **Shared filesystems are common.** Users may cd into `/tmp` or
  shared workspace paths. The default cannot assume "the current
  directory is safe."
- **Root shells happen accidentally.** Users forget they are in a
  `sudo -i` shell. The default cannot assume "the current uid is
  the user."
- **Symlink races are real** (TOCTOU). Any lstat-then-write pattern
  has a window an attacker can exploit on a shared filesystem.
- **Later versions of this package will change defaults.** Whatever
  0.0.2 ships as the DEFAULT becomes the SEMVER-STABLE contract.
  Breaking it later is a MAJOR bump.

Alternatives considered:

1. **Silent-overwrite default.** `bassclef init` clobbers everything
   without asking. Chosen by many install tools (npm's `init` is
   like this for `package.json`). Rejected: bassclef adopters may
   be running mid-project; silent clobber destroys their state.
2. **Interactive prompt.** `bassclef init` asks "overwrite? [y/N]"
   per file. Rejected for this WU: TTY detection + prompt loop is
   surface a scripted-CI caller cannot cleanly consume. May land in
   a later WU with `--interactive` opt-in.
3. **Merge on conflict.** For settings.json, parse existing content
   and merge new keys. Rejected for this WU: needs a schema-aware
   merger that respects existing keys and adds only new ones.
   Deferred to the sync-command WU or a follow-on.

## Decision

`bassclef init` ships with the following safety contract for 0.0.2
and all subsequent 0.x releases. Any change to a default listed below
is a MAJOR-bump-triggering change under semver.

**Default behavior when no flags are passed:**

1. Refuse to overwrite any file that already exists at the target
   path. Exit code `1` with a message naming `--force` as the
   remediation.
2. Refuse to run if the current uid is 0 (root). Exit code `1` with
   a message naming `--allow-root` as the remediation.
3. Refuse to write to a target directory that is not under the
   current user's `$HOME`. Exit code `1` with a message naming
   `--allow-any-dir` as the remediation.
4. Refuse to write to a target directory that is not owned by the
   current uid. Exit code `1` with the same message as (3).
5. Refuse to write if the target path is a symlink at write time
   (via `O_NOFOLLOW`). Exit code `2` with a message naming the
   path. `--force` does NOT override this — symlink refusal is
   unconditional. This blocks the TOCTOU class of attack.

**Atomic writes.**

Every file write uses `fs.openSync(path, O_CREAT | O_EXCL |
O_NOFOLLOW | O_WRONLY, 0o644)` followed by `fs.writeSync` +
`fs.closeSync`. `O_EXCL` gives an atomic existence check. `O_NOFOLLOW`
refuses to follow a symlink at the final path component. When
`--force` is in play and the target file already exists, we first
`fs.unlinkSync(path)` (which itself refuses to follow the final
symlink component), then retry the open. There is no temp-file-then-
rename dance; the atomic open is the safety.

**Complete mediation.**

Every file write in the codebase runs through `src/lib/write-safely.ts`
`writeSafely(path, content, options)`. No `fs.writeFileSync`,
`fs.appendFileSync`, or stream-write appears anywhere else in the
init command chain. Enforced by convention + review; a follow-on
lint rule may make this mechanical.

**Escape-hatch matrix.**

| Flag | Disables |
|---|---|
| `--force` | The existence check for each file. Every other safety check still runs. |
| `--allow-root` | The root refusal. No other check disabled. |
| `--allow-any-dir` | The `$HOME` scoping AND the target-directory ownership check. No other check disabled. |

Flags are orthogonal. Combined `--allow-root --allow-any-dir --force`
disables the three explicitly-named checks; symlink refusal via
`O_NOFOLLOW`, parent-directory writability, and post-write
verification still fire.

**Dry-run.**

`--dry-run` prints one line per target file describing the planned
action (`would create`, `would skip`, `would refuse`) and exits 0.
No files are written. The output shape does not depend on
`--verbose`.

## Status

`proposed` — this ADR ships with the WU-2 PR. Operator review flips
to `accepted` before 0.0.2 tags.

## Consequences

**Easier:**

- Sam's happy path is boring. Empty directory + `bassclef init` →
  files written → done. She never sees the safety machinery unless
  she trips it.
- Scripted CI installs know the exit-code contract and can wrap
  accordingly.
- Security incidents get a clear reference — the ADR names the
  defaults and the escape hatches.

**Harder:**

- Adding a new flag requires an ADR amendment (or a new ADR
  superseding) because defaults are part of the contract.
- The symlink-unconditional refusal will surprise power users who
  intentionally symlink their config. Documented in `--help` and
  README. `--force` deliberately does not override; symlink use is
  a separate opt-in that WU-2 does not ship.
- Path traversal defense means `--dir /tmp/xyz` fails by default,
  which some CI shapes will hit. `--allow-any-dir` is the answer.

**Enables:**

- Future WUs can trust `writeSafely` as the single audited write
  point.
- The sync command can reuse the resolver + writer with confidence
  the safety checks are shared.
- A future security-scanner adapter can grep for `fs.writeFileSync`
  outside `write-safely.ts` and flag any leakage.

**Blocks (until reconsidered):**

- No interactive prompt. Users on a TTY get the same behavior as a
  scripted invoke. Later WU may add `--interactive` opt-in.
- No merge semantics. Existing settings.json is either kept
  (default) or clobbered (`--force`). A schema-aware merger is a
  later WU.

**Invariants established (semver-locked for 0.x):**

Defaults:

- Default refuses to overwrite existing files.
- Default refuses to run as root (uid 0).
- Default refuses to write outside `$HOME`.
- Default refuses to write to a directory not owned by the current uid.
- Symlink refusal is unconditional. No flag can bypass in 0.x.

Files written:

- `.claude/settings.json` — minimal shape with a `$bassclef` marker
  key + empty `permissions.additionalDirectories` + empty `hooks`.
- `substrate.config.md` — YAML front-matter with template version +
  the standard configuration + phases + budget blocks.
- `.bassclef/init.manifest.json` — machine-readable record of what
  init wrote (path + template + template version + outcome). Used by
  the sync command to know exactly what to upgrade.

Escape-hatch matrix:

- `--force` disables the existence check per file. No other check.
- `--allow-root` disables the root refusal. No other check.
- `--allow-any-dir` disables the `$HOME` scope check AND the ownership
  check. No other check.
- Flags are orthogonal. All-three combined disables only the three
  named checks; symlink refusal + parent-directory writability +
  post-write file identity still fire.

Exit codes:

- `0` — success (all writes succeeded, or all files already correct,
  or partial success where some created + some kept because they
  existed and `--force` was not passed).
- `1` — refused by policy: file exists without `--force`; root run
  without `--allow-root`; target outside `$HOME` without
  `--allow-any-dir`; target dir not owned without `--allow-any-dir`.
- `2` — safety check failed at write time: symlink at target path;
  parent not writable; write itself failed.
- `3` — invalid args: unknown flag, missing value for a flag, or
  positional argument.

Any change to a listed default, file, matrix entry, or exit code is a
MAJOR bump under semver.

## References

- Bet: `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md`
  L122 (WU-2 scope), L147 (pre-mortem light discipline)
- Decomposition: `docs/decompositions/wu-2-init.md` (full luminary
  consult + challenger pass + revised test list)
- ADR-001 — build toolchain pin (invariants this ADR builds on:
  no source shipped, files whitelist)
- ADR-031 — we-don't-break-adopters (the reason default choices are
  semver-locked)
- Luminaries:
  - `saltzer-schroeder.md` — 8 principles; principles 2, 3, 5, 6, 8
    directly shape this contract
  - `alan-cooper.md` — Sam persona lens on install workflow
  - `john-ousterhout.md` — define errors out of existence; deep
    modules
- POSIX man pages: `open(2)` for `O_EXCL`, `O_NOFOLLOW` semantics
- Prior art: `git init` (default refuses to reinit but warns),
  `npm init` (default overwrites), `create-react-app` (default
  refuses to init in a non-empty dir)
