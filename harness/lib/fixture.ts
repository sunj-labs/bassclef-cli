// @requirement R-NPM-014
//
// Fixture — scoped temp dir + npm prefix for one HarnessRun instance.
// Owns cleanup on all exit paths per ADR-006 Decision 5 + Nygard fail-safe.
// See docs/decompositions/npm-install-harness.md § "Fixture" for GRASP rationale.
//
// Pattern note (Step 8): Meszaros/Fowler Test Fixture pattern applies here
// but bassclef-upstream catalog does not yet carry the entry. Annotation
// removed per .claude/rules/pattern-annotation.md L46-49. Follow-on ticket
// tracks catalog fill.

import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';

export class Fixture {
  private tempDir: string | null = null;
  private cleanupCalled = false;

  async create(): Promise<void> {
    if (this.tempDir !== null) {
      throw new Error('Fixture.create() called twice');
    }
    // fs.mkdtempSync creates a unique dir under the OS temp root. The XXXXXX
    // suffix gets replaced with a random string per mkdtemp(3). Fresh dir
    // per Fixture instance means zero collision between parallel HarnessRun
    // instances if we ever go parallel.
    this.tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'bassclef-harness-'));
    // Ensure the npm prefix subdir exists so InstallScope can use it.
    fs.mkdirSync(this.npmPrefix(), { recursive: true });
  }

  npmPrefix(): string {
    if (this.tempDir === null) {
      throw new Error('Fixture.npmPrefix() called before create()');
    }
    return path.join(this.tempDir, '.npm-global');
  }

  workDir(): string {
    if (this.tempDir === null) {
      throw new Error('Fixture.workDir() called before create()');
    }
    // Subdir for `bassclef init` to operate on. Kept separate from
    // .npm-global so the install prefix stays clean from init output.
    const dir = path.join(this.tempDir, 'work');
    fs.mkdirSync(dir, { recursive: true });
    return dir;
  }

  root(): string {
    if (this.tempDir === null) {
      throw new Error('Fixture.root() called before create()');
    }
    return this.tempDir;
  }

  async cleanup(): Promise<void> {
    if (this.cleanupCalled || this.tempDir === null) {
      return;
    }
    this.cleanupCalled = true;
    try {
      fs.rmSync(this.tempDir, { recursive: true, force: true });
    } catch (err) {
      // Log-and-continue per ADR-006 + UC Extension 8a. Cleanup failure
      // after a successful HarnessRun is warn-only, not a hard fail.
      // eslint-disable-next-line no-console
      console.warn(`Fixture cleanup warning: ${(err as Error).message}`);
    }
  }
}
