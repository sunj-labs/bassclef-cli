# louis-sprint fixtures

**Provenance (2026-10-07):** `golden-capture.txt` is a real `claude -p` capture from the cold-adopter docker container running `@thebassclef/lite@1.9.11`. Captured at Session L. Replaces the Session K scaffold.

Shape pattern mirrors `scripts/tests/fixtures/louis-whereami/` (Session J real capture).

## Fixtures

- `golden-capture.txt` — REAL capture, 41 output lines. Passes all 3 Cooper goal levels. Driver ceiling set to 41 (not 40) to count the 1-line `-p` trust-dialog warning as harness overhead; real /sprint content is 40 lines.
- `bad-jargon-capture.txt` — SCAFFOLD. Fails experience goal. Carries operationalize + load-bearing + primitive + blast radius + composer jargon.
- `bad-wall-capture.txt` — SCAFFOLD. Fails life goal. Over Louis's scan ceiling.

## Capture command

```bash
docker run --rm --platform linux/amd64 \
  -e CLAUDE_CODE_OAUTH_TOKEN="$(cat ~/.config/claude/oauth-token)" \
  -e CLI_VERSION=1.9.11 \
  -e HOME="$CONTAINER_HOME" \
  -v "$(pwd)/harness-out/session-l:/output" \
  -v "/tmp/capture.sh:/tmp/capture.sh:ro" \
  --entrypoint /bin/bash \
  bassclef-cli-cold-adopter:latest \
  /tmp/capture.sh
```

`$CONTAINER_HOME` is the in-container adopter user home dir (per the Dockerfile — see `harness/docker/Dockerfile.cold-adopter`). The capture script runs `npm install -g @thebassclef/lite@1.9.11`, `bassclef init ~/test`, then `claude --dangerously-skip-permissions -p "<natural-language-/sprint-prompt>"` and writes stdout+stderr to `/output/sprint-louis.out`. In-container absolute paths get scrubbed to `~` per `.claude/rules/identifier-leak-prevention.md` before the fixture lands.

Hand-crafted negatives (bad-jargon, bad-wall) stay stable regardless of live-capture refreshes — they test persona-assert lib catch logic, not current /sprint output.
