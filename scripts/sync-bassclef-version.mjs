#!/usr/bin/env node
// scripts/sync-bassclef-version.mjs — cli#439 helper.
//
// Reads .bassclef-pin at repo root. Reads bassclef-version.json from
// the sibling `~/src/sunj-labs/bassclef/bassclef-version.json` (or
// $BASSCLEF_SIBLING_ROOT/bassclef-version.json). Writes a copy at the
// bassclef-cli repo root as bassclef-version.json.
//
// Why: the statusline resolver chain reads $cwd/bassclef-version.json
// before any sibling path. Having this file at bassclef-cli root means
// the dev-repo statusline reads a committed source of truth, not
// whatever adjacent checkout happens to live in HOME.
//
// Content tracks `.bassclef-pin`. Advancing the pin should trigger a
// re-run of this script so the two stay in sync. Tier 0 test
// scripts/tests/sync-bassclef-version.test.sh asserts .version matches
// .bassclef-pin.
//
// Env:
//   BASSCLEF_SIBLING_ROOT — override sibling path (default
//     $HOME/src/sunj-labs/bassclef).
//
// Exits:
//   0 — wrote the file (OR file is already current)
//   1 — pin file missing OR malformed
//   2 — sibling repo missing OR has no bassclef-version.json
//   3 — pin value does not match the sibling's current .version
//
// Anchors:
//   @luminary parnas — information hiding; dev-repo doesn't need to
//                      know what version lives upstream, just read the
//                      canonical file for its pinned tag
//   @luminary hoare — pre/postcondition; precondition is pin value
//                     matches sibling, postcondition is both files
//                     agree on .version

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const REPO_ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const PIN_FILE = path.join(REPO_ROOT, '.bassclef-pin');
const OUT_FILE = path.join(REPO_ROOT, 'bassclef-version.json');
const SIBLING_ROOT = process.env.BASSCLEF_SIBLING_ROOT
  || path.join(os.homedir(), 'src', 'sunj-labs', 'bassclef');
const SIBLING_VERSION_FILE = path.join(SIBLING_ROOT, 'bassclef-version.json');

function die(code, msg) {
  process.stderr.write(`sync-bassclef-version: ${msg}\n`);
  process.exit(code);
}

if (!fs.existsSync(PIN_FILE)) {
  die(1, `.bassclef-pin missing at ${PIN_FILE}`);
}
const pin = fs.readFileSync(PIN_FILE, 'utf8').trim();
if (!/^v[0-9]+\.[0-9]+\.[0-9]+$/.test(pin)) {
  die(1, `.bassclef-pin value "${pin}" does not match v<N>.<N>.<N> shape`);
}

if (!fs.existsSync(SIBLING_VERSION_FILE)) {
  die(2, `sibling bassclef-version.json missing at ${SIBLING_VERSION_FILE} — set BASSCLEF_SIBLING_ROOT or clone sunj-labs/bassclef`);
}
const siblingRaw = fs.readFileSync(SIBLING_VERSION_FILE, 'utf8');
let sibling;
try {
  sibling = JSON.parse(siblingRaw);
} catch (e) {
  die(2, `sibling bassclef-version.json is not valid JSON: ${e.message}`);
}

if (sibling.version !== pin) {
  die(3, `pin (${pin}) does not match sibling version (${sibling.version}) — pin update needs sibling at the same tag`);
}

// Write the sibling's version object verbatim at the cli root. Keep
// the shape identical so any downstream reader treats the two files
// as interchangeable.
const serialized = JSON.stringify(sibling, null, 2) + '\n';

if (fs.existsSync(OUT_FILE)) {
  const current = fs.readFileSync(OUT_FILE, 'utf8');
  if (current === serialized) {
    process.stdout.write(`sync-bassclef-version: ${OUT_FILE} already current at ${pin}\n`);
    process.exit(0);
  }
}

fs.writeFileSync(OUT_FILE, serialized);
process.stdout.write(`sync-bassclef-version: wrote ${OUT_FILE} at ${pin}\n`);
