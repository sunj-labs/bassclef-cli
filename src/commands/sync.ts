// `bassclef sync` command — stub.
//
// Later work will land the real implementation: read the current package
// version, diff against the project's substrate, upgrade in place. See
// bet 2026-08-06b for the full acceptance list.

export function runSync(): number {
  process.stderr.write(
    'bassclef sync — later work will land this command.\n' +
      'You are running the scaffold release. Track status at\n' +
      'https://github.com/sunj-labs/bassclef-cli/issues.\n'
  );
  return 2;
}
