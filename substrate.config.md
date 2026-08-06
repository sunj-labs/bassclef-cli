# substrate.config.md

## Configuration
gating: orchestrator-gated
execution_mode: sequential

## Active agents
agents: Shaper, PM, Designer, Architect, Builder, Reviewer, Deployer, Closer

## Phases
phases: [Inception, Elaboration, Construction, Transition]

## Iteration planning
iterations: formal

## Risk register
risk-register: yes

## Budget
budget:
  session_ceiling:
  iteration_ceiling:
  warning_threshold: 75%
  replenish_floor:

## Hosting platform
#
# `none` — this repo ships an npm package (@thebassclef/core), not a web
# UI. `/bind-subdomain` + `/launch-preview` refuse on `none` unless
# BIND_SUBDOMAIN_OVERRIDE=1 is set.
#
hosting_platform: none

## Deploy targets
deploy_targets:
  local: true
  staging: false
  prod: false

## Distribution
#
# npm registry — no tarball, no S3, no `.bassclef-source.json`. Goal A is
# to replace the tarball distribution path.
#
distribution: npm
npm_package: "@thebassclef/core"
npm_registry: https://registry.npmjs.org

## Bassclef substrate location (dev-time)
#
# Where WU-2/3 tests read bassclef substrate from during THIS repo's
# development. Runtime shipped-adopter workflow reads from the installed
# npm package assets (dist/substrate/**), not from this path. Adding
# this key preemptively per architect-review 2026-08-06 (item 6):
# without it, WU-2's first read from disk lands the boundary decision
# accidentally.
#
# Override at runtime with the BASSCLEF_REPO_PATH env var.
#
bassclef_peer_repo_path: ~/src/sunj-labs/bassclef
bassclef_peer_repo_env: BASSCLEF_REPO_PATH

## Onboarding follow-on skip state
#
# Set by /onboard-repo when the operator explicitly skips a follow-on
# step. This repo skips both because it ships an npm package, not a
# deployed web app.
#
onboarding_deploy_host_skipped: true
onboarding_secrets_skipped: true
