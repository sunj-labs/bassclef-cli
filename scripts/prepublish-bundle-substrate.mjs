#!/usr/bin/env node
// scripts/prepublish-bundle-substrate.mjs
//
// Copies substrate files from the sibling bassclef checkout into
// dist/lite/ so npm pack includes them in the tarball.
//
// Post-Phase 3 shape (goal 2026-09-13c cli#73 — MAJOR 1.0.0):
//
//   dist/lite/            — sole bundle path per ADR-055 D1 + ADR-007
//                           D1 amendment 2026-09-13c
//                           6 files: .claude/settings.json + 4 templates
//                           + standards/bassclef-wiring-manifest.json
//                           built inline from standards/bassclef-wiring-manifest.json
//                           + presence/dist-templates/
//
// substrate/ bundle path retired 2026-09-13c under MAJOR 1.0.0 per
// operator directive (zero npm adopters at bump time; compat-shim not
// owed per ADR-031 threshold logic).
//
// Contract per docs/adrs/ADR-007-npm-lite-substrate-bundling.md Amendment
// 2026-09-13c §Phase 3:
//   - D1 — bundle path lock names dist/<tier>/ as sole accepted path;
//          substrate/ retired
//   - D3 — prepublish safety envelope fails fast on missing manifest,
//          missing templates, empty settings, missing wiring manifest
//   - RFC B3 — sibling-only source (no RemoteFetchStrategy)
//
// Risk ledger folds:
// @risk: R2 — pure Node; no execSync/spawn/spawnSync
// @risk: R7 — fail-fast on every precondition + postcondition
// @risk: N1 (Phase 3) — tag-existence check happens in workflow
// @risk: N2 — dist/lite/ settings.json hook entry count >= 1
// @risk: N3 — 4 templates must exist at source before copy
// @risk: L4 (Phase 3 pre-mortem) — wiring manifest MUST land in
//   dist/lite/standards/ so the reader schema check works
//
// Runs via package.json prepublishOnly. Reads sibling manifest via:
//   1. env BASSCLEF_SIBLING_ROOT (test override / CI workflow)
//   2. default ../bassclef-upstream relative to CWD

import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';

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
// dist/lite/ bundle (per ADR-055 D1; sole bundle path post-Phase 3)
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
  // npm-pack strips .gitignore files unconditionally (hard exclusion,
  // not overridable via .npmignore or `files`). Ship .gitignore as
  // `gitignore` in dist/lite/; the walker renames it back at write time
  // per src/lib/copy-substrate.ts §GITIGNORE_RENAME.
  const GITIGNORE_SPECIAL = '.gitignore';
  for (const name of DIST_TEMPLATE_FILES) {
    const src = join(templatesDir, name);
    const dstName = name === GITIGNORE_SPECIAL ? 'gitignore' : name;
    const dst = join(distRoot, dstName);
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
  // 4 templates (with .gitignore renamed to gitignore) + settings.json
  // + wiring manifest = 6 expected files.
  const expected = [
    join(distRoot, '.claude', 'settings.json'),
    join(distRoot, 'standards', 'bassclef-wiring-manifest.json'),
    ...DIST_TEMPLATE_FILES.map((n) => join(distRoot, n === '.gitignore' ? 'gitignore' : n)),
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

  // dist/lite/ tree per ADR-055 D1 — sole bundle path post-Phase 3.
  const distLite = buildDistLiteTree(siblingRoot);

  process.stdout.write(
    `built dist/lite/ from ${distLite.wiringManifestPath} (schema v${distLite.wiringVersion})\n`
  );
  process.stdout.write(
    `dist/lite/.claude/settings.json emitted ${distLite.hookCount} hook entries\n`
  );

  process.exit(0);
}

main();
