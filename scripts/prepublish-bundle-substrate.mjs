#!/usr/bin/env node
// scripts/prepublish-bundle-substrate.mjs
//
// Copies substrate files from the sibling bassclef checkout into two
// bundle trees so npm pack includes them in the tarball.
//
// Post-Phase 2 dual-write shape (goal 2026-09-13b cli#25):
//
//   substrate/            — legacy bundle path per ADR-007 D1 (Phase 1)
//                           149 files from lite-manifest.json + bundled
//                           manifest at substrate/.bassclef/lite-manifest.json
//   dist/lite/            — new bundle path per ADR-055 D1 + ADR-007 D1
//                           amendment (Phase 2 shipped this)
//                           5 files: .claude/settings.json + 4 templates
//                           built inline from standards/bassclef-wiring-manifest.json
//                           + presence/dist-templates/
//
// Contract per docs/adrs/ADR-007-npm-lite-substrate-bundling.md Amendment
// 2026-09-13 §Phase 2:
//   - D1 — bundle path lock adds dist/<tier>/ as second accepted path;
//          substrate/ preserved for Phase 3 drop
//   - D3 — prepublish safety envelope fails fast on missing manifest,
//          missing templates, empty settings, count mismatch
//   - RFC B3 — sibling-only source (no RemoteFetchStrategy)
//
// Risk ledger v3 build wiring + goal 2026-09-13b Phase 2 folds:
// @risk: R2 — pure Node; no execSync/spawn/spawnSync
// @risk: R7 — fail-fast on every precondition + postcondition
// @risk: R9 — reject when total bundled size passes 5MB (substrate/ only)
// @risk: N1 (Phase 2) — tag-existence check happens in workflow (Step 2)
// @risk: N2 (Phase 2) — dist/lite/ settings.json hook entry count >= 1
// @risk: N3 (Phase 2) — 4 templates must exist at source before copy
//
// Runs via package.json prepublishOnly. Reads sibling manifest via:
//   1. env BASSCLEF_SIBLING_ROOT (test override / CI workflow)
//   2. default ../bassclef relative to CWD (public downstream, not upstream)

import { readFileSync, writeFileSync, mkdirSync, existsSync, statSync, readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';

const SIZE_CEILING_BYTES = 5 * 1024 * 1024;
const BUNDLE_DIR_NAME = 'substrate';
const DIST_LITE_DIR = 'dist/lite';
const WIRING_MANIFEST_REL = 'standards/bassclef-wiring-manifest.json';
const DIST_TEMPLATES_REL = 'presence/dist-templates';
const DIST_TEMPLATE_FILES = [
  'CLAUDE.md',
  'whereami.md',
  '.bassclef-source.json',
  '.gitignore',
];
const EXPECTED_WIRING_MAJOR = 2;

// Tier hierarchy per ADR-055 D7: ultra ⊇ standard ⊇ lite.
const TIER_SUPERSETS = {
  lite: ['lite'],
  standard: ['lite', 'standard'],
  ultra: ['lite', 'standard', 'ultra'],
};

function fail(message) {
  process.stderr.write(`prepublish-bundle-substrate: ${message}\n`);
  process.exit(1);
}

function resolveSiblingRoot() {
  const override = process.env.BASSCLEF_SIBLING_ROOT;
  if (override && override.length > 0) return resolve(override);
  return resolve(process.cwd(), '..', 'bassclef-upstream');
}

// ============================================================
// substrate/ bundle (legacy — preserved for Phase 3 drop)
// ============================================================

function loadManifest(siblingRoot) {
  const manifestPath = join(siblingRoot, 'lite-manifest.json');
  if (!existsSync(manifestPath)) {
    fail(
      `manifest missing at ${manifestPath}. ` +
        `Check out sunj-labs/bassclef as a sibling directory, ` +
        `or set BASSCLEF_SIBLING_ROOT to point at the checkout.`
    );
  }
  let raw;
  try {
    raw = readFileSync(manifestPath, 'utf8');
  } catch (err) {
    fail(`cannot read manifest at ${manifestPath}: ${err.code ?? err.message}`);
  }
  let manifest;
  try {
    manifest = JSON.parse(raw);
  } catch (err) {
    fail(`manifest at ${manifestPath} is not valid JSON: ${err.message}`);
  }
  if (!Array.isArray(manifest.entries) || manifest.entries.length === 0) {
    fail(`manifest at ${manifestPath} has no entries[] array or the array is empty.`);
  }
  return { manifest, manifestPath };
}

function preflightSourcesExist(siblingRoot, manifest) {
  const missing = [];
  for (const entry of manifest.entries) {
    const sourcePath = join(siblingRoot, entry.path);
    if (!existsSync(sourcePath)) {
      missing.push(sourcePath);
    }
  }
  if (missing.length > 0) {
    fail(
      `source missing at ${missing[0]}` +
        (missing.length > 1 ? ` (and ${missing.length - 1} more)` : '') +
        `. Check the sibling checkout is current with the manifest.`
    );
  }
}

function copyEntry(siblingRoot, bundleRoot, entry) {
  const sourcePath = join(siblingRoot, entry.path);
  const targetPath = join(bundleRoot, entry.path);
  mkdirSync(dirname(targetPath), { recursive: true, mode: 0o755 });
  const content = readFileSync(sourcePath);
  writeFileSync(targetPath, content);
  return content.length;
}

function postflightChecks(bundleRoot, manifest, totalBytes) {
  const expectedCount = manifest.entries.length + 1;
  function walk(dir) {
    const names = readdirSync(dir);
    let count = 0;
    for (const name of names) {
      const p = join(dir, name);
      const st = statSync(p);
      if (st.isDirectory()) count += walk(p);
      else count += 1;
    }
    return count;
  }
  const actualCount = walk(bundleRoot);
  if (actualCount !== expectedCount) {
    fail(
      `postflight count mismatch: bundled ${actualCount} files but expected ${expectedCount} ` +
        `(${manifest.entries.length} manifest entries + 1 bundled manifest). ` +
        `Re-run the script; investigate if the mismatch persists.`
    );
  }
  if (totalBytes > SIZE_CEILING_BYTES) {
    const mb = (totalBytes / (1024 * 1024)).toFixed(2);
    fail(
      `bundled size ${mb}MB is over the 5MB ceiling. ` +
        `Trim the manifest at sunj-labs/bassclef or raise the ceiling in ADR-007 D3.`
    );
  }
}

function writeBundledManifest(bundleRoot, manifest) {
  const targetDir = join(bundleRoot, '.bassclef');
  mkdirSync(targetDir, { recursive: true, mode: 0o755 });
  const targetPath = join(targetDir, 'lite-manifest.json');
  const body = JSON.stringify(manifest, null, 2) + '\n';
  writeFileSync(targetPath, body, { mode: 0o644 });
  return targetPath;
}

function assertBundledManifestPresent(bundleRoot, expectedEntryCount) {
  const targetPath = join(bundleRoot, '.bassclef', 'lite-manifest.json');
  if (!existsSync(targetPath)) {
    fail(
      `bundled manifest missing at ${targetPath}. ` +
        `writeBundledManifest did not run OR the write silently failed. ` +
        `Re-run the script; if the miss persists, investigate the mkdir + write path.`
    );
  }
  let parsed;
  try {
    parsed = JSON.parse(readFileSync(targetPath, 'utf8'));
  } catch (err) {
    fail(
      `bundled manifest at ${targetPath} is not valid JSON: ${err.message}. ` +
        `The write likely corrupted the file. Re-run the script.`
    );
  }
  if (!Array.isArray(parsed.entries) || parsed.entries.length !== expectedEntryCount) {
    const actual = Array.isArray(parsed.entries) ? parsed.entries.length : 'not-an-array';
    fail(
      `bundled manifest entries[] shape wrong at ${targetPath}: got ${actual}, ` +
        `expected ${expectedEntryCount}. Re-run the script.`
    );
  }
}

// ============================================================
// dist/lite/ bundle (Phase 2 — new per ADR-055 D1)
// ============================================================

function loadWiringManifest(siblingRoot) {
  const manifestPath = join(siblingRoot, WIRING_MANIFEST_REL);
  if (!existsSync(manifestPath)) {
    fail(
      `wiring manifest missing at ${manifestPath}. ` +
        `Expected sibling clone to carry ${WIRING_MANIFEST_REL} at v0.39.0 or later.`
    );
  }
  let raw;
  try {
    raw = readFileSync(manifestPath, 'utf8');
  } catch (err) {
    fail(`cannot read wiring manifest at ${manifestPath}: ${err.code ?? err.message}`);
  }
  let manifest;
  try {
    manifest = JSON.parse(raw);
  } catch (err) {
    fail(`wiring manifest at ${manifestPath} is not valid JSON: ${err.message}`);
  }
  if (typeof manifest.version !== 'string' || manifest.version.length === 0) {
    fail(`wiring manifest at ${manifestPath} missing 'version' field — cannot verify schema.`);
  }
  const major = parseInt(manifest.version.split('.')[0], 10);
  if (major !== EXPECTED_WIRING_MAJOR) {
    fail(
      `wiring manifest version ${manifest.version} incompatible with cli ` +
        `(expected major ${EXPECTED_WIRING_MAJOR}.x). Upgrade cli OR downgrade sibling checkout.`
    );
  }
  if (!manifest.hooks || typeof manifest.hooks !== 'object' || Object.keys(manifest.hooks).length === 0) {
    fail(
      `wiring manifest at ${manifestPath} has empty 'hooks' block — refusing to write empty ` +
        `dist/lite/. Silent-empty class guard per bassclef-upstream#1505.`
    );
  }
  return { wiringManifest: manifest, wiringManifestPath: manifestPath };
}

// Port of bassclef-upstream's scripts/build-adopter-tree.sh jq filter to Node.
// Filter each event's matcher blocks' hook entries by tier ⊆ superset.
// Preserve the settings.json shape (hooks + permissions + env + etc.).
function filterHooksByTier(wiringManifest, targetTier) {
  const superset = TIER_SUPERSETS[targetTier];
  if (!superset) {
    fail(`unknown target tier '${targetTier}'. Expected one of: lite, standard, ultra.`);
  }
  const filteredHooks = {};
  for (const [event, matcherBlocks] of Object.entries(wiringManifest.hooks)) {
    if (!Array.isArray(matcherBlocks)) continue;
    const keptMatchers = [];
    for (const block of matcherBlocks) {
      if (!Array.isArray(block.hooks)) continue;
      // Filter hooks[] by tier; strip the tier field from each kept entry.
      const keptHooks = block.hooks
        .filter((h) => {
          const t = typeof h.tier === 'string' ? h.tier : 'lite';
          return superset.includes(t);
        })
        .map((h) => {
          // Drop the tier field — settings.json shape does not carry it.
          const { tier, ...rest } = h;
          return rest;
        });
      if (keptHooks.length > 0) {
        keptMatchers.push({
          matcher: block.matcher ?? '',
          hooks: keptHooks,
        });
      }
    }
    if (keptMatchers.length > 0) {
      filteredHooks[event] = keptMatchers;
    }
  }
  const out = {
    hooks: filteredHooks,
    permissions: wiringManifest.permissions ?? { allow: [], deny: [] },
    env: wiringManifest.env ?? {},
    additionalDirectories: wiringManifest.additionalDirectories ?? [],
  };
  if (typeof wiringManifest.$schema === 'string') {
    out.$schema = wiringManifest.$schema;
  }
  return out;
}

function countHookEntries(settingsObject) {
  let count = 0;
  for (const matcherBlocks of Object.values(settingsObject.hooks ?? {})) {
    for (const block of matcherBlocks) {
      count += (block.hooks ?? []).length;
    }
  }
  return count;
}

function emitDistLiteSettings(distRoot, settingsObject) {
  const outDir = join(distRoot, '.claude');
  mkdirSync(outDir, { recursive: true, mode: 0o755 });
  const outPath = join(outDir, 'settings.json');
  const body = JSON.stringify(settingsObject, null, 2) + '\n';
  writeFileSync(outPath, body, { mode: 0o644 });
  return outPath;
}

// Phase 3 addition — copy the wiring manifest itself into dist/lite/
// standards/ so the reader (bassclef init) can verify schema version
// per ADR-055 D4. Without this the reader has no manifest to check
// against and every init call exits 4 (ManifestMissing).
function copyWiringManifestIntoDist(siblingRoot, distRoot) {
  const src = join(siblingRoot, WIRING_MANIFEST_REL);
  const dstDir = join(distRoot, 'standards');
  mkdirSync(dstDir, { recursive: true, mode: 0o755 });
  const dst = join(dstDir, 'bassclef-wiring-manifest.json');
  const content = readFileSync(src);
  writeFileSync(dst, content, { mode: 0o644 });
}

function copyDistTemplates(siblingRoot, distRoot) {
  const templatesDir = join(siblingRoot, DIST_TEMPLATES_REL);
  if (!existsSync(templatesDir)) {
    fail(
      `dist-templates dir missing at ${templatesDir}. ` +
        `Expected sibling clone to carry ${DIST_TEMPLATES_REL} at v0.39.0 or later.`
    );
  }
  const missing = [];
  for (const name of DIST_TEMPLATE_FILES) {
    const src = join(templatesDir, name);
    if (!existsSync(src)) missing.push(src);
  }
  if (missing.length > 0) {
    fail(
      `dist-template file missing at ${missing[0]}` +
        (missing.length > 1 ? ` (and ${missing.length - 1} more)` : '') +
        `. Expected sibling clone to carry all 4 templates.`
    );
  }
  for (const name of DIST_TEMPLATE_FILES) {
    const src = join(templatesDir, name);
    const dst = join(distRoot, name);
    const content = readFileSync(src);
    writeFileSync(dst, content, { mode: 0o644 });
  }
}

function postflightDistLite(distRoot, settingsObject) {
  // Nygard N2 fold — hook entry count must be >= 1 so dist/lite/ is non-empty.
  const hookCount = countHookEntries(settingsObject);
  if (hookCount < 1) {
    fail(
      `dist/lite/.claude/settings.json has 0 hook entries — refusing to ship an empty ` +
        `settings.json. Silent-empty class guard per bassclef-upstream#1505.`
    );
  }
  // Phase 3 addition — assert wiring manifest present at
  // dist/lite/standards/bassclef-wiring-manifest.json. Reader per ADR-055
  // D4 fails with exit code 4 when this file is missing at init time.
  // Post-flight catches the broken build before it ships.
  const wiringManifestInDist = join(distRoot, 'standards', 'bassclef-wiring-manifest.json');
  if (!existsSync(wiringManifestInDist)) {
    fail(
      `dist/lite/ postflight: wiring manifest missing at ${wiringManifestInDist}. ` +
        `Reader would fail with exit code 4 at every init call. ` +
        `copyWiringManifestIntoDist did not run OR the write silently failed.`
    );
  }
  // All 5 template + 1 settings.json + 1 wiring manifest = 7 expected files.
  const expected = [
    join(distRoot, '.claude', 'settings.json'),
    join(distRoot, 'standards', 'bassclef-wiring-manifest.json'),
    ...DIST_TEMPLATE_FILES.map((n) => join(distRoot, n)),
  ];
  for (const p of expected) {
    if (!existsSync(p)) {
      fail(`dist/lite/ postflight: expected file missing at ${p}.`);
    }
  }
  return hookCount;
}

function buildDistLiteTree(siblingRoot) {
  const { wiringManifest, wiringManifestPath } = loadWiringManifest(siblingRoot);
  const filtered = filterHooksByTier(wiringManifest, 'lite');
  const distRoot = resolve(process.cwd(), DIST_LITE_DIR);
  mkdirSync(distRoot, { recursive: true, mode: 0o755 });
  const settingsPath = emitDistLiteSettings(distRoot, filtered);
  copyDistTemplates(siblingRoot, distRoot);
  // Phase 3 — put the wiring manifest at dist/lite/standards/ so the
  // reader can verify schema version per ADR-055 D4.
  copyWiringManifestIntoDist(siblingRoot, distRoot);
  const hookCount = postflightDistLite(distRoot, filtered);
  return { wiringManifestPath, settingsPath, hookCount, wiringVersion: wiringManifest.version };
}

// ============================================================
// main
// ============================================================

function main() {
  const siblingRoot = resolveSiblingRoot();

  // Legacy substrate/ tree (backward compat for cli code through Phase 3).
  const { manifest, manifestPath } = loadManifest(siblingRoot);
  preflightSourcesExist(siblingRoot, manifest);

  const bundleRoot = resolve(process.cwd(), BUNDLE_DIR_NAME);
  mkdirSync(bundleRoot, { recursive: true, mode: 0o755 });

  let totalBytes = 0;
  for (const entry of manifest.entries) {
    totalBytes += copyEntry(siblingRoot, bundleRoot, entry);
  }

  const bundledManifestPath = writeBundledManifest(bundleRoot, manifest);
  assertBundledManifestPresent(bundleRoot, manifest.entries.length);
  postflightChecks(bundleRoot, manifest, totalBytes);

  process.stdout.write(
    `bundled ${manifest.entries.length} files from ${manifestPath} into ${bundleRoot}\n`
  );
  process.stdout.write(
    `bundled manifest written to ${bundledManifestPath}\n`
  );

  // dist/lite/ tree (Phase 2 — new per ADR-055 D1).
  // Env gate lets characterization tests keep the pre-Phase-2 shape.
  // Default is on; tests that only seed the legacy lite-manifest.json set
  // BASSCLEF_BUILD_DIST_LITE=0. Production CI leaves the env unset → build fires.
  if (process.env.BASSCLEF_BUILD_DIST_LITE !== '0') {
    const distLite = buildDistLiteTree(siblingRoot);

    process.stdout.write(
      `built dist/lite/ from ${distLite.wiringManifestPath} (schema v${distLite.wiringVersion})\n`
    );
    process.stdout.write(
      `dist/lite/.claude/settings.json emitted ${distLite.hookCount} hook entries\n`
    );
  } else {
    process.stdout.write(
      `skipped dist/lite/ build (BASSCLEF_BUILD_DIST_LITE=0)\n`
    );
  }

  process.exit(0);
}

main();
