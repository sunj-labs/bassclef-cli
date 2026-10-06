# louis-sprint fixtures

**Provenance (2026-10-07):** Hand-crafted scaffold. Replace with live `claude -p "/sprint"` captures from the cold-adopter docker container once operator OAuth refresh (PR #381) lands clean.

Follow-on: cli#TBD-session-l — replace hand-crafted louis-sprint fixtures with live captures.

Shape pattern mirrors `scripts/tests/fixtures/louis-whereami/` (shipped as real captures in PR #382 Session J).

## Fixtures

- `golden-capture.txt` — passes all 3 Cooper goal levels (end + experience + life)
- `bad-jargon-capture.txt` — FAILS experience goal (dancing-bear catch; carries operationalize + load-bearing + primitive + blast radius + composer jargon)
- `bad-wall-capture.txt` — FAILS life goal (exceeds 40-line scan ceiling; Louis's budget is 90s not 5 min)

## Live capture (future)

Run inside docker cold-adopter container:

```bash
docker run --rm \
  --platform linux/amd64 \
  -e CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_CODE_OAUTH_TOKEN" \
  -e CLI_VERSION=latest \
  bassclef-cli-cold-adopter:latest \
  claude --dangerously-skip-permissions -p "/sprint"
```

Capture stdout to `golden-capture.txt`. Follow the 5-line header shape (per `scripts/lib/claude-chain.sh`).

Hand-crafted negatives (bad-jargon, bad-wall) stay stable regardless of live-capture refreshes — they test persona-assert lib catch logic, not current /sprint output.
