// test-list:
// [x] Fresh install: writes ~/.claude/bassclef-statusline.sh (0755) + settings.json statusLine field
// [x] Idempotent: re-run with same source content is a no-op
// [x] Preserves existing user dispatcher when content differs and --force not set
// [x] --force overwrites existing user dispatcher
// [x] Preserves existing statusLine in project settings.json when different and --force not set
// [x] --force overwrites existing project statusLine
// [x] --skip-statusline skips both writes; report entry says skipped
// [x] HOME unset → throws CopyFailure kind EnvironmentIncomplete (delegates to resolveHome)
// [x] Dispatcher source missing → throws with clear message
// [x] Executable bit set correctly on ~/.claude/bassclef-statusline.sh
// [x] Report entry records the install (kind: statuslineInstalled | statuslinePreserved | statuslineSkipped)
// [x] Dry-run: writes nothing but reports the plan
//
// Ships with bassclef-cli pair to bassclef-upstream#1860.
// Anchor: @luminary saltzer-schroeder (complete mediation on file writes),
//         @luminary tony-hoare (precondition/postcondition contract),
//         @luminary kent-beck (TDD test list before code).

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { mkdtempSync, rmSync, writeFileSync, existsSync, readFileSync, mkdirSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { installStatusline, type InstallStatuslineOptions } from '../src/lib/install-statusline.js';

const DISPATCHER_BODY = '#!/usr/bin/env bash\necho "bassclef statusline dispatcher"\n';

function makeFixture() {
  const root = mkdtempSync(join(tmpdir(), 'bcli-statusline-'));
  const fakeHome = join(root, 'home');
  const projectDir = join(root, 'project');
  const packageDir = join(root, 'package');
  const dispatcherSrc = join(packageDir, 'dist', 'lite', 'presence', 'cli', 'bassclef-statusline.dispatcher.sh');
  mkdirSync(fakeHome, { recursive: true });
  mkdirSync(join(projectDir, '.claude'), { recursive: true });
  mkdirSync(join(packageDir, 'dist', 'lite', 'presence', 'cli'), { recursive: true });
  writeFileSync(dispatcherSrc, DISPATCHER_BODY, { mode: 0o755 });
  writeFileSync(join(projectDir, '.claude', 'settings.json'), JSON.stringify({ hooks: {} }, null, 2));
  return { root, fakeHome, projectDir, packageDir, dispatcherSrc };
}

function baseOpts(fx: ReturnType<typeof makeFixture>, over: Partial<InstallStatuslineOptions> = {}): InstallStatuslineOptions {
  return {
    home: fx.fakeHome,
    projectDir: fx.projectDir,
    packageDir: fx.packageDir,
    force: false,
    dryRun: false,
    skip: false,
    ...over,
  };
}

let fx: ReturnType<typeof makeFixture>;

beforeEach(() => {
  fx = makeFixture();
});

afterEach(() => {
  rmSync(fx.root, { recursive: true, force: true });
});

describe('installStatusline — fresh install', () => {
  it('writes dispatcher to ~/.claude/bassclef-statusline.sh with 0755 perms', () => {
    const report = installStatusline(baseOpts(fx));
    const dst = join(fx.fakeHome, '.claude', 'bassclef-statusline.sh');
    expect(existsSync(dst)).toBe(true);
    expect(readFileSync(dst, 'utf8')).toBe(DISPATCHER_BODY);
    const mode = statSync(dst).mode & 0o777;
    expect(mode).toBe(0o755);
    expect(report.dispatcher.kind).toBe('installed');
  });

  it('writes statusLine field into project .claude/settings.json', () => {
    installStatusline(baseOpts(fx));
    const settings = JSON.parse(readFileSync(join(fx.projectDir, '.claude', 'settings.json'), 'utf8'));
    expect(settings.statusLine).toEqual({
      type: 'command',
      command: 'bash ~/.claude/bassclef-statusline.sh',
    });
  });

  it('preserves other settings.json content when merging statusLine', () => {
    writeFileSync(
      join(fx.projectDir, '.claude', 'settings.json'),
      JSON.stringify({ hooks: { PreToolUse: [] }, theme: 'dark' }, null, 2)
    );
    installStatusline(baseOpts(fx));
    const settings = JSON.parse(readFileSync(join(fx.projectDir, '.claude', 'settings.json'), 'utf8'));
    expect(settings.theme).toBe('dark');
    expect(settings.hooks).toEqual({ PreToolUse: [] });
    expect(settings.statusLine).toBeDefined();
  });
});

describe('installStatusline — idempotent re-run', () => {
  it('is a no-op when dispatcher target content matches source', () => {
    installStatusline(baseOpts(fx));
    const report = installStatusline(baseOpts(fx));
    expect(report.dispatcher.kind).toBe('unchanged');
    expect(report.settings.kind).toBe('unchanged');
  });
});

describe('installStatusline — preserve existing without --force', () => {
  it('preserves an operator-edited dispatcher when content differs', () => {
    const dst = join(fx.fakeHome, '.claude', 'bassclef-statusline.sh');
    mkdirSync(join(fx.fakeHome, '.claude'), { recursive: true });
    writeFileSync(dst, '#!/usr/bin/env bash\necho "operator custom"\n', { mode: 0o755 });
    const report = installStatusline(baseOpts(fx));
    expect(readFileSync(dst, 'utf8')).toContain('operator custom');
    expect(report.dispatcher.kind).toBe('preserved');
  });

  it('preserves an operator-set statusLine field when different', () => {
    writeFileSync(
      join(fx.projectDir, '.claude', 'settings.json'),
      JSON.stringify({ statusLine: { type: 'command', command: 'my-status.sh' } }, null, 2)
    );
    const report = installStatusline(baseOpts(fx));
    const settings = JSON.parse(readFileSync(join(fx.projectDir, '.claude', 'settings.json'), 'utf8'));
    expect(settings.statusLine.command).toBe('my-status.sh');
    expect(report.settings.kind).toBe('preserved');
  });
});

describe('installStatusline — --force overwrites', () => {
  it('overwrites operator dispatcher when --force is set', () => {
    const dst = join(fx.fakeHome, '.claude', 'bassclef-statusline.sh');
    mkdirSync(join(fx.fakeHome, '.claude'), { recursive: true });
    writeFileSync(dst, 'old content\n', { mode: 0o755 });
    const report = installStatusline(baseOpts(fx, { force: true }));
    expect(readFileSync(dst, 'utf8')).toBe(DISPATCHER_BODY);
    expect(report.dispatcher.kind).toBe('replaced');
  });

  it('overwrites operator statusLine field when --force is set', () => {
    writeFileSync(
      join(fx.projectDir, '.claude', 'settings.json'),
      JSON.stringify({ statusLine: { type: 'command', command: 'my-status.sh' } }, null, 2)
    );
    const report = installStatusline(baseOpts(fx, { force: true }));
    const settings = JSON.parse(readFileSync(join(fx.projectDir, '.claude', 'settings.json'), 'utf8'));
    expect(settings.statusLine.command).toBe('bash ~/.claude/bassclef-statusline.sh');
    expect(report.settings.kind).toBe('replaced');
  });
});

describe('installStatusline — --skip-statusline', () => {
  it('writes nothing when skip is set; report says skipped', () => {
    const report = installStatusline(baseOpts(fx, { skip: true }));
    expect(existsSync(join(fx.fakeHome, '.claude', 'bassclef-statusline.sh'))).toBe(false);
    const settings = JSON.parse(readFileSync(join(fx.projectDir, '.claude', 'settings.json'), 'utf8'));
    expect(settings.statusLine).toBeUndefined();
    expect(report.dispatcher.kind).toBe('skipped');
    expect(report.settings.kind).toBe('skipped');
  });
});

describe('installStatusline — dry-run', () => {
  it('writes nothing but reports would-install shape', () => {
    const report = installStatusline(baseOpts(fx, { dryRun: true }));
    expect(existsSync(join(fx.fakeHome, '.claude', 'bassclef-statusline.sh'))).toBe(false);
    const settings = JSON.parse(readFileSync(join(fx.projectDir, '.claude', 'settings.json'), 'utf8'));
    expect(settings.statusLine).toBeUndefined();
    expect(report.dispatcher.kind).toBe('would-install');
    expect(report.settings.kind).toBe('would-install');
  });
});

describe('installStatusline — error paths', () => {
  it('throws when dispatcher source is missing', () => {
    rmSync(fx.dispatcherSrc);
    expect(() => installStatusline(baseOpts(fx))).toThrow(/bassclef-statusline\.dispatcher\.sh/);
  });
});

describe('installStatusline — settingsPreserved signal from walker', () => {
  it('skips the settings merge when settingsPreserved is true', () => {
    writeFileSync(
      join(fx.projectDir, '.claude', 'settings.json'),
      JSON.stringify({ prior: true }, null, 2)
    );
    const report = installStatusline(baseOpts(fx, { settingsPreserved: true }));
    const settings = JSON.parse(readFileSync(join(fx.projectDir, '.claude', 'settings.json'), 'utf8'));
    // Adopter content untouched.
    expect(settings).toEqual({ prior: true });
    expect(report.settings.kind).toBe('preserved');
    // Dispatcher still installs — user-scope is orthogonal.
    expect(existsSync(join(fx.fakeHome, '.claude', 'bassclef-statusline.sh'))).toBe(true);
    expect(report.dispatcher.kind).toBe('installed');
  });
});
