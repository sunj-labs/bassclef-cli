---
bassclef_template: substrate.config.md
bassclef_template_version: 0.0.1
generated_by: "@thebassclef/core"
generated_by_version: "0.0.2"
---

# substrate.config.md

## Configuration
gating: operator-gated
execution_mode: sequential

## Active agents
agents: Shaper, PM, Designer, Architect, Builder, Reviewer, Deployer, Closer

## Phases
phases: [Inception, Elaboration, Construction, Transition]

## Iteration planning
iterations: informal

## Risk register
risk-register: no

## Budget
budget:
  session_ceiling:
  iteration_ceiling:

## Hosting platform
# Leave `none` unless this project deploys a web UI.
# Enum: amplify | ec2-tailscale | vercel | netlify | cloudflare-pages | none
hosting_platform: none

## Deploy targets
deploy_targets:
  local: true
  staging: false
  prod: false
