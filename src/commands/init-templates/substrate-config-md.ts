// Template for substrate.config.md — the project manifest a bassclef
// project reads at session start.
//
// The first block is YAML front-matter carrying the template version
// so `bassclef sync` can identify what init wrote. Adopters fill in
// placeholders after init. The file is intentionally small; a follow-on
// WU may ship an `--interactive` mode that asks the caller about
// hosting platform etc.

export const SUBSTRATE_CONFIG_TEMPLATE_VERSION = '0.0.1' as const;

export function substrateConfigMdTemplate(pkgVersion: string): string {
  return [
    '---',
    `bassclef_template: substrate.config.md`,
    `bassclef_template_version: ${SUBSTRATE_CONFIG_TEMPLATE_VERSION}`,
    `generated_by: "@thebassclef/core"`,
    `generated_by_version: "${pkgVersion}"`,
    '---',
    '',
    '# substrate.config.md',
    '',
    '## Configuration',
    'gating: operator-gated',
    'execution_mode: sequential',
    '',
    '## Active agents',
    'agents: Shaper, PM, Designer, Architect, Builder, Reviewer, Deployer, Closer',
    '',
    '## Phases',
    'phases: [Inception, Elaboration, Construction, Transition]',
    '',
    '## Iteration planning',
    'iterations: informal',
    '',
    '## Risk register',
    'risk-register: no',
    '',
    '## Budget',
    'budget:',
    '  session_ceiling:',
    '  iteration_ceiling:',
    '',
    '## Hosting platform',
    '# Leave `none` unless this project deploys a web UI.',
    '# Enum: amplify | ec2-tailscale | vercel | netlify | cloudflare-pages | none',
    'hosting_platform: none',
    '',
    '## Deploy targets',
    'deploy_targets:',
    '  local: true',
    '  staging: false',
    '  prod: false',
    '',
  ].join('\n');
}
