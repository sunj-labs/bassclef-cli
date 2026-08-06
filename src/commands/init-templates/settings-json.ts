// Template for .claude/settings.json — Claude Code settings.
//
// The 0.0.x template ships MINIMAL. bassclef substrate is not yet
// available to the user at init time — the sync command (later work)
// downloads it and points settings.json at where it landed. Init
// writes a valid empty settings.json with a marker block so `bassclef
// sync` can identify what it wrote and upgrade in place.
//
// Do NOT assume `../bassclef` sibling checkout here. Do NOT reference
// `$HOME/.claude/hooks/bassclef-sync.sh` here. Both were WU-2's
// architect-review ship-blocker: cold-start adopters have neither.

export const SETTINGS_TEMPLATE_VERSION = '0.0.1' as const;

export function settingsJsonTemplate(pkgVersion: string): string {
  const value = {
    $bassclef: {
      template: 'settings.json',
      template_version: SETTINGS_TEMPLATE_VERSION,
      generated_by: '@thebassclef/core',
      generated_by_version: pkgVersion,
    },
    permissions: {
      additionalDirectories: [] as string[],
    },
    hooks: {},
  };
  return JSON.stringify(value, null, 2) + '\n';
}
