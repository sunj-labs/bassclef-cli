// `bassclef sync` command — stub for WU-1.
//
// WU-3 will land the real implementation: read the current package version,
// diff against the adopter's substrate, upgrade in place. See bet
// 2026-08-06b WU-3 for the full acceptance list.

export function runSync(): number {
  process.stderr.write(
    'bassclef sync — WU-3 will land this command.\n' +
      'You are running 0.0.1 (scaffold only). Track WU-3 status at\n' +
      'https://github.com/sunj-labs/bassclef-cli/issues.\n'
  );
  return 2;
}
