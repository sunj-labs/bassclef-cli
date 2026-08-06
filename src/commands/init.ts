// `bassclef init` command — stub for WU-1.
//
// WU-2 will land the real implementation: write settings.json + kilo.json +
// substrate.config.md into the adopter's project directory, idempotent on
// re-run. See bet 2026-08-06b WU-2 for the full acceptance list.

export function runInit(): number {
  process.stderr.write(
    'bassclef init — WU-2 will land this command.\n' +
      'You are running 0.0.1 (scaffold only). Track WU-2 status at\n' +
      'https://github.com/sunj-labs/bassclef-cli/issues.\n'
  );
  return 2;
}
