# Security policy

## Reporting a vulnerability

If you find something that could compromise an adopter's machine,
their credentials, or their code, please tell us privately first.

**Email** — `security@bassclef.dev`

Please include:

- What the vulnerability is, in one paragraph.
- The version affected (`bassclef --version`).
- A minimal way to reproduce, if you have one.
- What impact you think it has.

## Response window

- **72 hours** — the maintainer acknowledges the report.
- **7 days** — the maintainer replies with a plan or a request for more information.
- **30 days** — a fix ships or the maintainer explains why not.

If a report is urgent (active exploit, credential leak), say so in the
subject line — for example, `URGENT: bassclef-cli active exploit`. The
maintainer treats urgent reports as top priority.

## Supported versions

The two most recent minor releases receive security fixes.
Older releases may receive fixes at the maintainer's discretion,
depending on severity.

Current supported line:

- `1.9.x` — supported.
- `1.8.x` — supported.
- Everything older — best effort only.

## Public disclosure

After a fix ships:

- The release notes at [docs.bassclef.dev/docs/whats-new/releases](https://docs.bassclef.dev/docs/whats-new/releases)
  will name the fix.
- The advisory will be published on GitHub Security Advisories.
- The reporter gets credit unless they ask to remain anonymous.

## Scope

This policy covers the `@thebassclef/lite` npm package and everything
it writes to a target repo. It also covers the substrate at
`sunj-labs/bassclef` when bassclef-cli is the delivery path.
