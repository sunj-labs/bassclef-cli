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

## Onboarding follow-on skip state
#
# Set by /onboard-repo when the operator explicitly skips a follow-on
# step. This repo skips both because it ships an npm package, not a
# deployed web app.
#
onboarding_deploy_host_skipped: true
onboarding_secrets_skipped: true
