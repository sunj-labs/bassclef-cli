#!/usr/bin/env bash
# tier: standard
# Docker harness exit-code contract (single source of truth per RFC-0002 R13).
#
# Sourced by:
#   - harness/docker/entry.sh (in-container orchestrator)
#   - .claude/hooks/tests/docker-harness-entry.test.sh (Tier 0 tests)
#
# Refs:
#   - docs/use-cases/UC-docker-cold-adopter-harness.md § Postconditions + Extensions
#   - docs/rfcs/RFC-0002-docker-harness-code-shape.md R13
#
# Contract: readonly constants only. No logic. No side effects on source.

# Success path
readonly EXIT_OK=0

# V1 assertion failures (detection classes)
readonly EXIT_HOOKS_MISSING=3       # settings-hooks-present exit 3: 12-hook cascade class (bassclef-upstream#1827)
readonly EXIT_SKILL_HARDCODE=4      # V2 skill drive: hardcoded operator paths (bassclef-upstream#1824)
readonly EXIT_SKILL_TIMEOUT=5       # V2 skill drive: skill exceeded timeout budget
readonly EXIT_MANIFEST_MISMATCH=6   # init manifest count mismatch

# Infrastructure failures (fail-loud per Nygard)
readonly EXIT_BUILD_FAIL=20         # docker build failed after retries
readonly EXIT_INSTALL_FAIL=21       # npm install -g @thebassclef/lite failed after retries
readonly EXIT_VERSION_NOT_FOUND=22  # target version not on npm registry (npm ERR! 404)
readonly EXIT_INIT_FAIL=23          # bassclef init failed
readonly EXIT_ASSERT_NOT_FOUND=24   # smoke-assert-*.sh script not on PATH
readonly EXIT_ENV_MISSING=25        # ANTHROPIC_API_KEY missing for V2 skill drive
readonly EXIT_REPORT_WRITE_FAIL=26  # report path not writable

# Unknown-defect class (Saltzer-Schroeder complete mediation catch)
readonly EXIT_UNKNOWN=99            # unmapped exit code fell through; bug in ExitCodeMapper

# Signal-trap propagation (per pre-mortem-2 S3)
readonly EXIT_SIGTERM=130
readonly EXIT_SIGINT=131
