---
plan_id: 2026-09-26-1953-probes
tier: standard
authored_by: bassclef-cli-aa @ 2026-09-25T22:15Z
handoff_from: bassclef-upstream-5c coord message @ 2026-09-25T22:10Z
---

# Next session — bassclef-upstream#1953 probes + one cross-check

## Peer's ask (bassclef-upstream-5c handoff)

Peer diagnosed structural gaps at bassclef-upstream that partly explain the 44-hook leak. They need two probes from the cold-adopter Mac before building a repro fixture locally.

### Peer's structural findings on their side

- `dist/lite/presence/install/bassclef-hook-connect.sh` — missing from their view of the tarball
- `dist/lite/lite-manifest.json` — missing from their view
- `scripts/build-adopter-tree.sh` never copies `presence/install/` or manifests into `dist/*/`

That accounts for +44 wrong entries when merge fires without the filter. Fragment sources from `${BASSCLEF_DIR}/presence/install/bassclef-hook-connect.sh`; if missing, tier filter can't run.

### Cross-check to add

Operator's `ls ~/tmp/bassclef-smoke-test/presence/install/bassclef-hook-connect.sh` returned the file EXISTS post-init. Init reported "presence/install: 6 files copied." So either:
- v1.9.3 tarball ships those files (contradicts peer's view of the tarball)
- Init pulls them from somewhere else

Verify against `/tmp/lite-1.9.3/package/dist/lite/presence/install/` fetched earlier tonight (I confirmed dist/lite/.claude/settings.json had 29 entries via the same tarball fetch).

## Probe 1 — resolve_bassclef_dir output

On cold-adopter Mac profile:

```bash
source ~/.claude/hooks/../../lib/bassclef-dir-resolver.sh 2>/dev/null || \
  source ~/lib/bassclef-dir-resolver.sh 2>/dev/null || \
  source "$(node -p 'path.join(require.resolve("@thebassclef/lite/package.json"), "..", "dist", "lite", "lib", "bassclef-dir-resolver.sh")')" 2>/dev/null

HOOK_REAL_PATH="$(readlink -f ~/.claude/hooks/session-reflection.sh 2>/dev/null || readlink ~/.claude/hooks/session-reflection.sh 2>/dev/null || echo ~/.claude/hooks/session-reflection.sh)" \
CWD="$PWD" \
resolve_bassclef_dir

ls -la $(resolve_bassclef_dir)/presence/install/bassclef-hook-connect.sh 2>&1
ls -la $(resolve_bassclef_dir)/lite-manifest.json 2>&1
```

Reveals the exact bassclef_root + whether it carries the tier-filter lib + the manifest.

## Probe 2 — diff init manifest against leaked settings.json

Find what dropped the 3 correct SessionStart entries (`session-reflection.sh`, `session-start-recap-inject.sh`, `vendored-dispatcher-refresh.sh`):

```bash
# Compare init's baseline against the leaked live settings
jq '.hooks.SessionStart' ~/tmp/bassclef-smoke-test/.bassclef/init.manifest.json > /tmp/init-sessionstart.json
jq '.hooks.SessionStart' ~/tmp/bassclef-smoke-test/.claude/settings.json > /tmp/live-sessionstart.json
diff /tmp/init-sessionstart.json /tmp/live-sessionstart.json
```

Peer's jq merge (`presence/install/bassclef-hook-connect.sh` L250-288) is additive-only. It never deletes adopter entries. If those 3 are missing, something else removed them. Candidates:

- Cli init's Path C top-up logic (not run on this cold-adopter — it was fresh init, not top-up)
- A SessionStart fragment that rewrites settings.json between init and merge
- Something in bassclef-sync even under auto_sync=false

## Once probes land

Peer will build a repro fixture locally from probe 1 output. Then fix at bassclef-upstream. Then cascade through v1.6.1 or v1.7.0.

## Related open work

- **PR #242** — smoke-one-shot script, needs final smoke verification after peer's cure lands
- **cli#243** — auto_sync=true smoke variant follow-on
- **bassclef-upstream#1951** — dedupe compounding-axis vs compounding-sequence
- **bassclef-upstream#1952** — lite substrate exceeds Claude Code's 150k instruction budget

## Time budget

- Probe 1 + probe 2 + cross-check: 15-30 turns
- Peer's fix + cascade: peer's territory
- Total cli-side involvement tomorrow: 30-50 turns operator-attended
