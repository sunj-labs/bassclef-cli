// @requirement R-NPM-014
// @pattern patterns/code/gof/command.md (catalog check pending Step 8)
//
// CliInvocation — one CLI run. Captures exit + stdout + stderr. Shields
// callers from Node child_process quirks (Indirection per GRASP Step 3).
// See docs/decompositions/npm-install-harness.md § "CliInvocation".

import { spawnSync } from 'node:child_process';

export interface CliCaptured {
  exitCode: number;
  stdout: string;
  stderr: string;
  timedOut: boolean;
}

export interface CliInvokeOpts {
  timeoutMs?: number;
  cwd?: string;
}

export class CliInvocation {
  constructor(
    private binPath: string,
    private verb: string,
    private args: string[],
  ) {}

  async run(opts: CliInvokeOpts = {}): Promise<CliCaptured> {
    const timeoutMs = opts.timeoutMs ?? 30000;
    // The bassclef binary is a Node script with #!/usr/bin/env node shebang
    // (per dist/cli.js output). spawnSync can invoke it directly on Unix;
    // Windows would need explicit `node` invocation, deferred per ADR-006.
    const finalArgs = [this.verb, ...this.args];
    const result = spawnSync(this.binPath, finalArgs, {
      encoding: 'utf8',
      cwd: opts.cwd,
      timeout: timeoutMs,
    });
    return {
      exitCode: result.status ?? -1,
      stdout: result.stdout ?? '',
      stderr: result.stderr ?? '',
      timedOut: result.signal === 'SIGTERM',
    };
  }
}
