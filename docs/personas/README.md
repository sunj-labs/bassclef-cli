---
tier: upstream
type: reference
title: Where bassclef personas live
---

# Where bassclef personas live

bassclef-cli does not keep its own copies of the bassclef personas. Read
them from bassclef-upstream instead. This file is the pointer.

## Why a pointer and not copies

Every persona file carries `tier: upstream` in its frontmatter. Upstream-tier
files never ship to public bassclef, so they cannot reach bassclef-cli through
`bassclef-sync`. A hand-copied snapshot would drift the moment upstream edits
the persona, and nothing in cli would catch the drift.

The same reasoning governs bassclef's design models. See
`.claude/rules/bassclef-models-discovery.md` — keep the content in bassclef,
distribute the pointer.

## The files

Source of truth: `sunj-labs/bassclef-upstream`, path `docs/personas/`.

| Persona | Path | Role | Budget |
|---|---|---|---|
| Sam | `docs/personas/sam.md` | Mid-level engineer, first touch | 15-30 min |
| Jamie | `docs/personas/jamie.md` | Positioning + maturity reader | ~90 seconds |
| Morgan | `docs/personas/morgan.md` | Senior staff engineer | see file |
| Louis | `docs/personas/2026-07-12-bet11c-louis.md` | Solo operator, many surfaces | see file |
| CI/CD subsystem | `docs/personas/ci-cd-subsystem.md` | Subsystem persona | see file |

Dated variants also live there (`2026-07-12-bet11c-sam.md`, `-jamie`, `-morgan`).
Longer-form audience notes sit under `strategy/personas/`.

## How to read one

Local checkout (fastest, works offline):

```
cat ~/src/sunj-labs/bassclef-upstream/docs/personas/sam.md
```

Check the checkout is current before you trust it:

```
cd ~/src/sunj-labs/bassclef-upstream && git fetch origin main \
  && git log -1 origin/main --format='%H %s'
```

No local checkout — read through the GitHub API:

```
gh api repos/sunj-labs/bassclef-upstream/contents/docs/personas/sam.md \
  --jq '.content' | base64 -d
```

bassclef-upstream is a private repo, so the browser path needs an authorized
session.

## When cli work needs a persona

Cite the upstream path in the artifact. Do not copy the body into cli. If a
rule or hook in cli needs a reader standard it can cite locally, cite
`.claude/rules/plain-english-discipline.md` (grade-8 target) instead — that
rule does ship to adopters.

## Refs

- `.claude/rules/bassclef-models-discovery.md` — the pointer pattern this file follows
- `docs/canvases/2026-10-25-persona-ux-test-tier.md` — cli#448, names Sam, Louis, Jamie
- bassclef-upstream `docs/personas/` at `bd2f3b70` (read 2026-10-25)
