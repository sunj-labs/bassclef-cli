# @thebassclef/lite

Install bassclef in your project. Two commands.

```bash
npm install -g @thebassclef/lite
bassclef init
```

Five minutes from install to a working bassclef in your repo.

## What it does

`bassclef init` writes a small set of files into your project — a
settings file for Claude Code, a config file for the CLI, and a
project manifest. Your project inherits bassclef's skills, rules,
and agents on the next Claude Code session.

`bassclef sync` upgrades those files in place when a newer package
version publishes.

## Supported systems

- **macOS** — first-class. Every release is tested here.
- **Linux** — supported. `npm install` works. First-class support waits on the substrate bash portability audit at [sunj-labs/bassclef#1497](https://github.com/sunj-labs/bassclef/issues/1497). File a ticket if a hook breaks.
- **WSL 2** (Windows Subsystem for Linux 2) — supported. WSL 2 reports as `linux` to npm, so install works. Same audit note as Linux.
- **Windows (native PowerShell)** — not supported. `npm install` returns `EBADPLATFORM` by design. Use WSL 2.

See [`standards/os-support.md`](standards/os-support.md) for the full policy.

## Requirements

- Node.js 20 or newer.
- npm 10 or newer.

## Current release

<!-- version-start -->1.2.2<!-- version-end -->

See [CHANGELOG.md](CHANGELOG.md) for release notes.

## License

Apache-2.0. See [LICENSE](LICENSE).
