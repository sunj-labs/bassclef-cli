# @thebassclef/lite

Install bassclef in your project. Two commands.

```bash
npm install -g @thebassclef/lite
bassclef init
```

Five minutes from install to a working bassclef in your repo.

**New here?** Read [docs.bassclef.dev](https://docs.bassclef.dev) for the full guide — what bassclef is, how to onboard your repo, what each skill does.

## What it does

`bassclef init` writes a small set of files into your project — a
settings file for Claude Code, a config file for the CLI, and a
project manifest. Your project inherits bassclef's skills, rules,
and agents on the next Claude Code session.

`bassclef sync` upgrades those files in place when a newer package
version publishes.

### What `bassclef sync` touches

If you want to know exactly what gets written to your repo before you
run it — see [docs.bassclef.dev/docs/config/substrate-config](https://docs.bassclef.dev/docs/config/substrate-config).
Short version — the file list is bounded to `.claude/`, `docs/whereami.md`,
and the project manifest. Nothing outside that footprint moves.

## Supported systems

- **macOS** — first-class. Every release is tested here.
- **Linux** — supported. `npm install` works. First-class support waits on the substrate bash portability audit at [sunj-labs/bassclef#1497](https://github.com/sunj-labs/bassclef/issues/1497). File a ticket if a hook breaks.
- **WSL 2** (Windows Subsystem for Linux 2) — supported. WSL 2 reports as `linux` to npm, so install works. Same audit note as Linux.
- **Windows (native PowerShell)** — not supported. `npm install` returns `EBADPLATFORM` by design. Use WSL 2.

See [`standards/os-support.md`](standards/os-support.md) for the full policy.

## Requirements

- Node.js 20 or newer.
- npm 10 or newer.

## Hit a red BLOCKED banner?

Bassclef fires BLOCKED banners at the start of a session when a check
does not pass. Most banners come with a "how to fix" line right in the
banner text. Read that line first — it names the file or command that
resolves the block.

Still stuck? Check the [troubleshooting page](https://docs.bassclef.dev/docs/architecture/failure-mode)
on the docs site, or [file a bug](#file-a-bug-or-ask-a-question) below.

## File a bug or ask a question

- **Something broke** — [open a bug report](https://github.com/sunj-labs/bassclef-cli/issues/new?template=bug_report.md).
- **Question about how it works** — [open a question](https://github.com/sunj-labs/bassclef-cli/issues/new?template=question.md).
- **Idea for a feature** — [open a feature request](https://github.com/sunj-labs/bassclef-cli/issues/new?template=feature_request.md).

`npm bugs @thebassclef/lite` also works — it opens the issue tracker in
your browser.

## Current release

<!-- version-start -->1.9.1<!-- version-end -->

See [CHANGELOG.md](CHANGELOG.md) for the full changelog. Adopter-facing
release notes live at [docs.bassclef.dev/docs/whats-new/releases](https://docs.bassclef.dev/docs/whats-new/releases).

## Community + security

- [Code of Conduct](CODE_OF_CONDUCT.md) — how we treat each other in issues + PRs.
- [Security policy](SECURITY.md) — how to report a vulnerability privately.
- [Contributing](CONTRIBUTING.md) — how to send a PR.

## License

Apache-2.0. See [LICENSE](LICENSE).
