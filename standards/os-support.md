---
tier: lite
title: OS support policy for `@thebassclef/lite`
last_updated: 2026-09-19
---

# OS support

Which operating systems `@thebassclef/lite` supports today, and what changes when.

## Declared systems

`package.json` pins `"os": ["darwin", "linux"]`. `npm install` succeeds on those platforms and returns `EBADPLATFORM` on any other. This is the honest claim as of the 1.2.0 launch.

## What each label means

**macOS (`darwin`).** First-class support. Every release is smoke-tested on macOS. Substrate bash was written and tested here first.

**Linux (`linux`).** Supported. `npm install` works. Substrate bash is macOS-tested; Linux paths may hit BSD-vs-GNU coreutils differences (e.g., `md5 -q` vs `md5sum`, `sed -i` suffix behavior, `find -mtime` semantics). The upstream portability audit tracks this at [sunj-labs/bassclef#1497](https://github.com/sunj-labs/bassclef/issues/1497). File a ticket if you hit divergence.

**WSL 2 (Windows Subsystem for Linux 2).** Supported. WSL 2 reports `process.platform === 'linux'` to npm, so `linux` in the pin covers it. Same substrate-bash caveat as native Linux applies.

**Windows (native PowerShell).** Not supported. `npm install -g @thebassclef/lite` from PowerShell returns `EBADPLATFORM` by design. Use WSL 2 instead.

## Why the pin includes both darwin and linux

Three reasons.

1. **Adopter copy names both.** The launch README says darwin + linux. `package.json` and the README must agree, or adopters lose trust in the docs.
2. **WSL 2 needs the linux pin.** Cutting linux would block Windows adopters who followed the WSL 2 pointer — worse experience than a clear install error.
3. **First Linux adopter is the audit test bed.** The substrate portability work runs anyway per [#1497](https://github.com/sunj-labs/bassclef/issues/1497). Turning Linux adopters away at install would delay the signal we need.

## What breaks and how we cure it

If a Linux adopter files a substrate bash bug (e.g., a hook fails with `md5: illegal option`), the cure is:

1. Patch the substrate hook to use POSIX or dual-form syntax (upstream).
2. Bassclef ships a patch release.
3. `@thebassclef/lite` pins the new upstream tag and ships a matching release.

Cure path is bounded to a few days per adopter-blocking bug.

## Phases

Phase 1 — declare the contract. Shipped 2026-09-19 as part of [bassclef-cli#151](https://github.com/sunj-labs/bassclef-cli/issues/151).

Phase 2 — substrate portability audit. Upstream work at [sunj-labs/bassclef#1497](https://github.com/sunj-labs/bassclef/issues/1497). Blocks Phase 3.

Phase 3 — matrix CI. `.github/workflows/publish.yml` gains a `strategy.matrix.os` covering macOS + Linux; every release runs the smoke against both before publish. Blocks the first cross-platform claim (`@thebassclef/lite@1.3.0` or later).

Phase 4 — Windows coverage. Signal from first Windows adopter friction triggers this. Either WSL 2 install test on GHA `windows-latest` runner OR a PowerShell-native rewrite of substrate hooks. Reopens a follow-on ticket when live.

## Related

- [`package.json`](../package.json) — `"os": ["darwin", "linux"]`
- [README supported-systems section](../README.md#supported-systems)
- [bassclef-cli#151](https://github.com/sunj-labs/bassclef-cli/issues/151) — parent ticket
- [sunj-labs/bassclef#1497](https://github.com/sunj-labs/bassclef/issues/1497) — upstream substrate portability audit
- [`standards/bash-hook-safety.md`](https://github.com/sunj-labs/bassclef/blob/main/standards/bash-hook-safety.md) — substrate bash discipline (safety + portability once Phase 2 lands)
