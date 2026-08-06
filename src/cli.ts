// bassclef CLI entrypoint.
//
// Ousterhout: this is a shallow-interface / deep-implementation shell.
// WU-1 ships the shell; WU-2/3 fill the commands.
//
// Cooper: Sam runs `bassclef`, `bassclef --version`, `bassclef --help`, or
// `bassclef init`. All four MUST return within 100ms with a message that
// makes sense to a person who has not read the docs.
//
// Saltzer-Schroeder (economy of mechanism): argv is a small hand-rolled
// switch. No dependency on `commander` / `yargs` yet — the surface is
// four verbs and two flags. A parser library would carry hidden state.
// Add it when the surface widens.

import { version } from './index.js';
import { runInit, usage as initUsage } from './commands/init.js';
import { runSync } from './commands/sync.js';

const USAGE = `bassclef — install and upgrade bassclef in your project

Usage:
  bassclef init [options] Write bassclef config into a project directory
  bassclef sync           Upgrade bassclef config in place (later work)
  bassclef --version      Print the running version
  bassclef --help         Print this message

Run \`bassclef init --help\` for init options + the safety defaults.

Version: ${version}
Docs:    https://github.com/sunj-labs/bassclef-cli
`;

function main(argv: readonly string[]): number {
  const first = argv[0];

  if (first === undefined || first === '--help' || first === '-h' || first === 'help') {
    process.stdout.write(USAGE);
    return 0;
  }

  if (first === '--version' || first === '-v' || first === 'version') {
    process.stdout.write(`${version}\n`);
    return 0;
  }

  if (first === 'init') {
    const rest = argv.slice(1);
    // `bassclef init --help` prints init-specific usage without running.
    if (rest.includes('--help') || rest.includes('-h')) {
      process.stdout.write(initUsage());
      return 0;
    }
    return runInit(rest);
  }

  if (first === 'sync') {
    return runSync();
  }

  process.stderr.write(
    `bassclef: unknown command '${first}'\n\n` + USAGE
  );
  return 1;
}

const exitCode = main(process.argv.slice(2));
process.exit(exitCode);
