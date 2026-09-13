// Template-version lock test — per WU-3 decomp P6.
//
// The whole trust model of sync depends on template versions being
// bumped when template output changes. If a future step changes the
// output of a template but forgets to change its template version,
// sync will miss the update.
//
// Post-Phase 3 (cli#73 MAJOR 1.0.0): sync manages substrate.config.md
// only. Settings.json moved to walker-owned dist/lite/ verbatim per
// ADR-055 D1 — no cli-composed settings template anymore.

import { describe, it, expect } from 'vitest';
import { createHash } from 'node:crypto';
import {
  substrateConfigMdTemplate,
  SUBSTRATE_CONFIG_TEMPLATE_VERSION,
} from '../src/commands/init-templates/substrate-config-md.js';

function sha256(s: string): string {
  return createHash('sha256').update(s.replace(/\r\n/g, '\n')).digest('hex');
}

describe('template-version lock (WU-3 P6)', () => {
  it('substrate.config.md output at v0.0.1 has a locked hash', () => {
    const key = `substrate.config.md@${SUBSTRATE_CONFIG_TEMPLATE_VERSION}`;
    const hash = sha256(substrateConfigMdTemplate('0.0.1'));
    expect({ key, hash }).toMatchSnapshot();
  });
});
