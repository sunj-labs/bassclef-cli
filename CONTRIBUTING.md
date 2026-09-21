# Contributing to `@thebassclef/lite`

Short guide. Two sections. Read the second one before you touch the version string.

## First-time setup

Clone + install:

```bash
git clone https://github.com/sunj-labs/bassclef-cli.git
cd bassclef-cli
npm install
```

Install the local git hooks:

```bash
npm run install-hooks
```

That command writes one section to `.git/hooks/pre-commit`. The section is wrapped in bassclef-cli sentinels. Prior hook content stays intact — the installer chains, it does not clobber.

The pre-commit hook checks that the four version-bearing files agree before every commit that touches one of them. Bypass one commit with `git commit --no-verify`. The PR-CI workflow catches drift at the merge gate — the local hook is belt and suspenders.

## Version bumps

Four files carry the version string:

- `package.json` — `.version`
- `src/index.ts` — `export const version = 'X.Y.Z' as const;`
- `README.md` — between `<!-- version-start -->` and `<!-- version-end -->`
- `CHANGELOG.md` — the top non-Unreleased heading

The bump script `scripts/bump-version.mjs` writes all four in one shot. Use it. Never hand-edit `package.json` alone:

```bash
# Standard patch bump — updates all 4 files atomically
npm run bump patch

# Minor + major work the same way
npm run bump minor
npm run bump major
```

The pre-commit hook + PR-CI workflow both catch drift when the four fall out of sync. See `docs/specs/2026-09-21-pre-tag-version-sync.md` for the design.

### Why four files instead of one

Consumers read the version in different places:

- `package.json` — npm registry + `npm view`
- `src/index.ts` — TypeScript consumers via `import { version } from '@thebassclef/lite'`
- `README.md` — humans browsing GitHub
- `CHANGELOG.md` — release history

Deriving three from one saves duplication. It also breaks static reads. The four-file design is intentional per ADR-004. The check is the mediator that keeps them in sync.

## Running tests

Full suite:

```bash
npm test
```

Watch mode during development:

```bash
npm run test:watch
```

Typecheck without emitting:

```bash
npm run typecheck
```

Every PR runs `npm test` + `npm run typecheck` per `.github/workflows/pr-checks.yml`.

## Commit conventions

Format per `.claude/rules/commit-conventions.md`:

```
type: description in imperative mood
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `ci`, `chore`, `security`.

Keep the title under 72 characters. Body explains the "why," not the "what."

## Release

Releases follow ADR-004. Bump, PR, merge, tag, publish workflow, Touch ID at the environment gate. See `docs/adrs/ADR-004-publish-pipeline-safety-contract.md`.

## Reporting bugs

Open a GitHub issue at [sunj-labs/bassclef-cli/issues](https://github.com/sunj-labs/bassclef-cli/issues).
