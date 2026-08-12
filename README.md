# @thebassclef/core

Install bassclef in your project. Two commands.

```
npm install -g @thebassclef/core
bassclef init
```

Five minutes from install to a working bassclef in your repo.

## What it does

`bassclef init` writes a small set of files into your project — a
settings file for Claude Code, a config file for the CLI, and a
project manifest. Your project inherits bassclef's skills, rules, and
agents on the next Claude Code session.

`bassclef sync` upgrades those files in place when a newer package
version publishes.

## Requirements

- Node.js 20 or newer.
- npm 10 or newer.

## Status

`0.0.1` — scaffold only. Real behavior lands over the next work units:

- WU-1 (this release) — package shape, README, LICENSE, CLI shell.
- WU-2 — `bassclef init` writes your project files.
- WU-3 — `bassclef sync` upgrades in place.
- WU-4 — publish pipeline with security defaults.
- WU-5 — semver + changelog discipline.

`bassclef init` and `bassclef sync` in `0.0.1` print a "not yet — WU-2
will land this" message and exit non-zero. This is intentional; the
scaffold ships before the behavior so publish + install can be
tested end-to-end.

## Contributing

Traceability check runs on every commit that touches source, tests,
`vite.config.ts`, or `docs/requirements/`. One-time install:

```
bash scripts/install-git-hooks.sh
```

The hook fires the traceability test at
`tests/requirements-traceability.test.ts`. The test walks source for
`@requirement R-NPM-XXX` comments and tests for `@verifies R-NPM-XXX`
comments. It fails if a satisfied requirement is missing an edge or
if a referenced ID is not in the registry at
`docs/requirements/2026-08-11-npm-distribution.md`.

Bypass in a bind:

```
SKIP_TRACEABILITY_CHECK=1 git commit -m "..."
```

The workflow's `checks` job still runs the full test suite (including
the traceability check) so bypassed commits get caught at CI.

## License

Apache-2.0. See [LICENSE](./LICENSE).

## Source

Development happens at
[sunj-labs/bassclef-cli](https://github.com/sunj-labs/bassclef-cli).
Bassclef's core work happens at
[sunj-labs/bassclef](https://github.com/sunj-labs/bassclef); the CLI
here ships the packaged form.

## Sibling repos

- `sunj-labs/bassclef-upstream` — substrate source of truth (private R&D)
- `sunj-labs/bassclef` — public release target for the substrate

## Docs

- `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md` — active goal doc
- `docs/decompositions/wu-1-repo-shape.md` — WU-1 responsibility split
- `HANDOFF.md` — first-session bootstrap instructions
