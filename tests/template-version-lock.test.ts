// Template-version lock test — per WU-3 decomp P6.
//
// The whole trust model of sync depends on template versions being
// bumped when template output changes. If a future WU changes the
// output of `settingsJsonTemplate` but forgets to change
// `SETTINGS_TEMPLATE_VERSION`, sync will miss the update.
//
// This test snapshots the hash of each template's output. Vitest
// generates the snapshot on first run and fails on subsequent runs
// when the output hash changes. When a template revision is
// intentional, the developer:
//   1. Bumps `_TEMPLATE_VERSION` in the source template.
//   2. Reruns tests with `--update-snapshots` to accept the new hash.
//   3. Commits the updated snapshot file alongside the source change.

import { describe, it, expect } from 'vitest';
import { createHash } from 'node:crypto';
import {
  settingsJsonTemplate,
  SETTINGS_TEMPLATE_VERSION,
} from '../src/commands/init-templates/settings-json.js';
import {
  substrateConfigMdTemplate,
  SUBSTRATE_CONFIG_TEMPLATE_VERSION,
} from '../src/commands/init-templates/substrate-config-md.js';

function sha256(s: string): string {
  return createHash('sha256').update(s.replace(/\r\n/g, '\n')).digest('hex');
}

describe('template-version lock (WU-3 P6)', () => {
  it('settings.json output at v0.0.1 has a locked hash', () => {
    const key = `settings.json@${SETTINGS_TEMPLATE_VERSION}`;
    const hash = sha256(settingsJsonTemplate('0.0.1'));
    expect({ key, hash }).toMatchSnapshot();
  });

  it('substrate.config.md output at v0.0.1 has a locked hash', () => {
    const key = `substrate.config.md@${SUBSTRATE_CONFIG_TEMPLATE_VERSION}`;
    const hash = sha256(substrateConfigMdTemplate('0.0.1'));
    expect({ key, hash }).toMatchSnapshot();
  });
});
