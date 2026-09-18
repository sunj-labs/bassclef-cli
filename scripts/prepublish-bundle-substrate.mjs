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

import {
  readFileSync,
  writeFileSync,
  mkdirSync,
  existsSync,
  chmodSync,
  readdirSync,
  lstatSync,
  statSync,
} from 'node:fs';
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

// Cli 1.1.0 (goal 2026-09-16) — canonical lite catalog at sibling.
// Prepublish reads this manifest and copies every entry to dist/lite/
// via identity path mapping. See ADR-057 D1 for the destination-path
// invariant at init time.
const LITE_MANIFEST_REL = 'lite-manifest.json';
const EXPECTED_LITE_MANIFEST_MAJOR = 1;

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

// Cli 1.1.0 — catalog reader.
//
// @risk N1 (Nygard fail-loud on missing manifest)
// @risk RH (Hickey — schema major check both at build + init)
// @risk F-10 AMBER fold (collision guard against DIST_TEMPLATE_FILES)
// @risk F-8 GREEN (identity path mapping — no transformation)

function loadLiteManifest(siblingRoot) {
  const path = join(siblingRoot, LITE_MANIFEST_REL);
  if (!existsSync(path)) {
    fail(
      `lite-manifest.json missing at ${path}. ` +
        `No such file — expected sibling clone to carry ${LITE_MANIFEST_REL} at v1.6.x. ` +
        `Reinstall bassclef-upstream or upgrade the sibling checkout.`
    );
  }
  const raw = readFileSync(path, 'utf8');
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (e) {
    fail(`lite-manifest.json at ${path} is not valid JSON: ${e.message}`);
  }
  if (typeof parsed.manifest_version !== 'string' || parsed.manifest_version.length === 0) {
    fail(
      `lite-manifest.json missing 'manifest_version' field. ` +
        `Expected schema major ${EXPECTED_LITE_MANIFEST_MAJOR}.x.`
    );
  }
  const major = parseInt(parsed.manifest_version.split('.')[0], 10);
  if (major !== EXPECTED_LITE_MANIFEST_MAJOR) {
    fail(
      `lite-manifest.json schema major mismatch: got manifest_version=${parsed.manifest_version} ` +
        `but cli expects schema major ${EXPECTED_LITE_MANIFEST_MAJOR}.x. ` +
        `Upgrade cli or downgrade bassclef-upstream to a compatible version.`
    );
  }
  if (!Array.isArray(parsed.entries) || parsed.entries.length === 0) {
    fail(
      `lite-manifest.json 'entries' is empty or not an array. ` +
        `Silent-empty guard — refusing to ship a catalog with 0 entries.`
    );
  }
  return { manifest: parsed, path };
}

function assertNoManifestCollisions(manifest, siblingRoot) {
  // F-10 AMBER cure: manifest entry.path must not collide with any
  // file the existing prepublish path lays down in dist/lite/. If it
  // did, the catalog copy would silently overwrite (or be overwritten
  // by) the template layer. Fail-loud instead.
  const distTemplates = new Set(
    DIST_TEMPLATE_FILES.map((n) => (n === '.gitignore' ? 'gitignore' : n))
  );
  const collisions = [];
  for (const entry of manifest.entries) {
    if (typeof entry.path !== 'string' || entry.path.length === 0) {
      fail(`lite-manifest.json entry ${JSON.stringify(entry)} has invalid path field`);
    }
    if (distTemplates.has(entry.path)) {
      collisions.push(entry.path);
    }
  }
  if (collisions.length > 0) {
    fail(
      `ManifestCollision — lite-manifest.json entries collide with DIST_TEMPLATE_FILES: ` +
        collisions.join(', ') +
        `. Templates ship via prepublish's dist-templates path; manifest ships via catalog copy. ` +
        `Conflict at ${collisions[0]}. Amend the manifest or the templates set.`
    );
  }
  // Also assert every entry.path resolves to a real file at sibling
  const missing = [];
  for (const entry of manifest.entries) {
    const sourcePath = join(siblingRoot, entry.path);
    if (!existsSync(sourcePath)) missing.push(entry.path);
  }
  if (missing.length > 0) {
    fail(
      `lite-manifest.json entries reference missing source files: ` +
        missing.slice(0, 3).join(', ') +
        (missing.length > 3 ? ` (and ${missing.length - 3} more)` : '') +
        `. Sibling clone may be out of date with manifest — rerun the manifest generator.`
    );
  }
}

function copyLiteCatalogEntries(siblingRoot, distRoot, manifest) {
  let copied = 0;
  for (const entry of manifest.entries) {
    const source = join(siblingRoot, entry.path);
    const target = join(distRoot, entry.path);
    mkdirSync(dirname(target), { recursive: true, mode: 0o755 });
    const content = readFileSync(source);
    // Preserve execute bit for scripts + lib + hooks; 0644 otherwise.
    const executable =
      entry.type === 'script' ||
      entry.type === 'lib' ||
      entry.type === 'hook' ||
      entry.type === 'presence-template' ||
      entry.path.endsWith('.sh');
    writeFileSync(target, content, { mode: executable ? 0o755 : 0o644 });
    copied += 1;
  }
  return copied;
}

function copyLiteManifestIntoDist(siblingRoot, distRoot) {
  const src = join(siblingRoot, LITE_MANIFEST_REL);
  const dstDir = join(distRoot, 'standards');
  mkdirSync(dstDir, { recursive: true, mode: 0o755 });
  const dst = join(dstDir, 'lite-manifest.json');
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
    let content = readFileSync(src);
    if (name === GITIGNORE_SPECIAL) {
      // Per bassclef-cli#99: append a synced-substrate block so `git add -A`
      // on a fresh adopter does not sweep 500+ vendored files. Sibling
      // upstream template lacks the block today; cli fills the gap at
      // pack time so adopters get a working ignore on install.
      content = ensureClaudeIgnored(content);
    }
    writeFileSync(dst, content, { mode: 0o644 });
  }
}

/**
 * Append the synced-substrate block to a gitignore body when missing.
 * Idempotent — if `.claude/` already appears (upstream ships it one day,
 * or an adopter customizes), we do not double-write. Buffer in, Buffer out.
 */
function ensureClaudeIgnored(bodyBuf) {
  const body = Buffer.isBuffer(bodyBuf) ? bodyBuf.toString('utf8') : String(bodyBuf);
  // Match either bare `.claude/` or `.claude` as a whole line (with slash or without).
  if (/^\.claude\/?$/m.test(body)) return bodyBuf;
  const trailer =
    (body.endsWith('\n') ? '' : '\n') +
    '\n' +
    '# Bassclef synced substrate — vendored via `bassclef init` + `bassclef sync`.\n' +
    '# Ignore by default so `git add -A` does not sweep hundreds of files.\n' +
    '# Adopters who want to pin substrate: remove these lines OR add `!path/to/track`.\n' +
    '.claude/\n' +
    '.bassclef/\n';
  return Buffer.from(body + trailer, 'utf8');
}

function postflightDistLite(distRoot, settingsObject, copiedFileCount) {
  // Nygard N2 fold — hook entry count must be >= 1 so dist/lite/ is non-empty.
  const hookCount = countHookEntries(settingsObject);
  // Cli 1.0.3 (bassclef-cli#87) — count equality is no longer the check
  // (copiedFileCount >= hookCount is expected because helpers land alongside
  // commands). Postflight instead runs assertDeclaredCommandsHaveBinaries
  // per-command below. The `>=` sanity check catches truly-broken builds
  // where no files landed at all.
  if (copiedFileCount !== undefined && copiedFileCount < hookCount) {
    fail(
      `dist/lite/ postflight: settings.json declares ${hookCount} hooks but only ` +
        `${copiedFileCount} files landed in dist/lite/.claude/hooks/. ` +
        `Expected count to be >= declared (helpers land alongside commands).`
    );
  }
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
  // Cli 1.0.3 (bassclef-cli#87) — recursive tree copy replaces the prior
  // command-name filter. Upstream applies the tier filter at bundle time;
  // cli trusts the tree and copies it whole. Helpers (trace-helper.sh)
  // and fragment dirs (session-reflection.d/) that hooks source at
  // runtime now ship in the tarball.
  const { copiedFiles, copiedDirs } = copyHookTreeRecursive(siblingRoot, distRoot);
  // Cli 1.1.0 (goal 2026-09-16 cli#90) — read canonical lite catalog and
  // copy all 292 entries into dist/lite/ via identity path mapping.
  // Skills, rules, agents, luminaries, libs, ADRs, standards, templates,
  // presence-templates, scripts, root-docs now ship in the tarball per
  // ADR-057. @risk N1 + RH + F-10 + F-8.
  const { manifest: liteManifest } = loadLiteManifest(siblingRoot);
  assertNoManifestCollisions(liteManifest, siblingRoot);
  const catalogCopied = copyLiteCatalogEntries(siblingRoot, distRoot, liteManifest);
  copyLiteManifestIntoDist(siblingRoot, distRoot);
  // Nygard fail-fast — postflight verifies every declared command has a
  // matching binary in the tree. Helpers pass with an INFO log.
  const treeInfo = assertDeclaredCommandsHaveBinaries(distRoot, filtered);
  const hookCount = postflightDistLite(distRoot, filtered, copiedFiles);
  return {
    wiringManifestPath,
    settingsPath,
    hookCount,
    copiedHookCount: copiedFiles,
    copiedDirs,
    treeFileCount: treeInfo.treeFileCount,
    wiringVersion: wiringManifest.version,
    liteCatalogCount: catalogCopied,
    liteManifestVersion: liteManifest.manifest_version,
  };
}

/**
 * @pattern patterns/code/gof/template-method.md
 *
 * Recursively copy the sibling's dist/lite/.claude/hooks/ tree into cli's
 * dist/lite/.claude/hooks/. The walk shape (enter → decide entry type
 * → recurse or copy → exit) is the template; specific handling per entry
 * type is the variation.
 *
 * Cli 1.0.3 (bassclef-cli#87) — replaces the prior command-name-filtered
 * copy. Upstream applies the tier filter at bundle time; cli trusts the
 * tree and copies it whole. Helpers (like trace-helper.sh) and fragment
 * directories (like session-reflection.d/) that hooks source at runtime
 * now ship in the tarball. See docs/decompositions/2026-09-16-cli-1.0.3-prepublish-domain.md
 * for the GRASP roles.
 *
 * Refuses symlinks via lstat (Saltzer-Schroeder complete mediation) —
 * an npm tarball must not carry a symlink that could escape or duplicate.
 *
 * Do NOT reintroduce a cli-side filter here. Filtering by settings.json
 * commands drops helpers upstream ships intentionally — that is exactly
 * the 1.0.2 crash class this fix cures. See risk ledger L2 for the
 * anti-pattern lock.
 *
 * Returns { copiedFiles, copiedDirs } for postflight logging.
 */
function copyHookTreeRecursive(siblingRoot, distRoot) {
  const sourceDir = join(siblingRoot, 'dist/lite/.claude/hooks');
  if (!existsSync(sourceDir)) {
    fail(
      `hook source dir missing at ${sourceDir}. ` +
        `Expected sibling clone to carry dist/lite/.claude/hooks/ at v0.42.0 or later. ` +
        `Sibling may be pre-v0.42.0; upgrade the sibling checkout.`
    );
  }
  const outDir = join(distRoot, '.claude/hooks');
  mkdirSync(outDir, { recursive: true, mode: 0o755 });

  const counts = { copiedFiles: 0, copiedDirs: 0 };
  walkTree(sourceDir, outDir, counts);

  if (counts.copiedFiles === 0) {
    fail(
      `sibling hook tree at ${sourceDir} appears empty — zero *.sh files copied. ` +
        `Sibling checkout may be missing bundled hooks; may be pre-v0.42.0.`
    );
  }
  return counts;
}

/**
 * Walk `srcDir` recursively, mirroring the tree into `dstDir`. Every entry
 * is `lstat`'d — symlinks are refused before content is touched. Files
 * preserve their executable bit. Directories carry mode 0o755.
 *
 * @param {string} srcDir source directory (already exists)
 * @param {string} dstDir destination directory (already exists)
 * @param {{copiedFiles: number, copiedDirs: number}} counts mutated per entry
 */
function walkTree(srcDir, dstDir, counts) {
  const entries = readdirSync(srcDir);
  for (const entry of entries) {
    const src = join(srcDir, entry);
    const dst = join(dstDir, entry);
    let stat;
    try {
      stat = lstatSync(src);
    } catch (err) {
      fail(`cannot lstat ${src}: ${err.code ?? err.message}`);
    }
    if (stat.isSymbolicLink()) {
      fail(
        `refusing to follow symlink at ${src}. ` +
          `An npm tarball must not carry a symlink that could escape or duplicate. ` +
          `If upstream intentionally added this symlink, resolve to a plain file first.`
      );
    }
    if (stat.isDirectory()) {
      mkdirSync(dst, { recursive: true, mode: 0o755 });
      counts.copiedDirs += 1;
      walkTree(src, dst, counts);
      continue;
    }
    if (stat.isFile()) {
      let content;
      try {
        content = readFileSync(src);
      } catch (err) {
        fail(`cannot read ${src}: ${err.code ?? err.message}`);
      }
      try {
        writeFileSync(dst, content);
      } catch (err) {
        fail(`cannot write ${dst}: ${err.code ?? err.message}`);
      }
      // Preserve executable bit. On POSIX systems the source mode reflects
      // reality; on Windows the mode may not encode the exec bit. Best-effort.
      try {
        const srcMode = stat.mode & 0o777;
        const isExecutable = (srcMode & 0o100) !== 0 || src.endsWith('.sh');
        if (isExecutable) {
          chmodSync(dst, 0o755);
        }
      } catch (err) {
        if (process.platform !== 'win32') {
          fail(`cannot chmod ${dst}: ${err.code ?? err.message}`);
        }
        // Windows — log INFO, continue.
        process.stderr.write(`INFO: chmod skipped on Windows for ${dst}\n`);
      }
      counts.copiedFiles += 1;
      continue;
    }
    // Any other type (socket, fifo, device) — refuse.
    fail(`refusing to copy non-regular entry at ${src}`);
  }
}

/**
 * @pattern patterns/code/nygard/fail-fast.md
 *
 * Postflight — verify every command declared in the filtered settings.json
 * has a matching *.sh binary somewhere in the copied tree. Fails loud with
 * the missing command name if any command lacks a binary.
 *
 * Extra files in the tree (helpers, fragments) are logged INFO and pass —
 * that is the whole point of the recursive copy. See risk ledger HT-1 for
 * why postflight lives here, not in the walk.
 *
 * @param {string} distRoot cli's dist/lite/
 * @param {object} settingsObject filtered lite-tier settings.json object
 * @returns {{ declaredCount: number, treeFileCount: number }}
 */
function assertDeclaredCommandsHaveBinaries(distRoot, settingsObject) {
  const treeDir = join(distRoot, '.claude/hooks');
  const declared = new Set();
  for (const eventBlocks of Object.values(settingsObject.hooks ?? {})) {
    for (const block of eventBlocks) {
      for (const entry of block.hooks ?? []) {
        const cmd = entry.command;
        if (typeof cmd !== 'string' || cmd.length === 0) continue;
        if (!cmd.startsWith('$')) continue;
        const leaf = cmd.slice(cmd.lastIndexOf('/') + 1);
        if (leaf.endsWith('.sh')) declared.add(leaf);
      }
    }
  }

  // Collect all *.sh files anywhere in the tree.
  const treeFiles = new Set();
  collectShFiles(treeDir, treeFiles);

  const missing = [];
  for (const leaf of declared) {
    if (!treeFiles.has(leaf)) missing.push(leaf);
  }
  if (missing.length > 0) {
    fail(
      `postflight: settings.json declares ${missing[0]}` +
        (missing.length > 1 ? ` (and ${missing.length - 1} more)` : '') +
        ` but no matching binary in ${treeDir}. ` +
        `Sibling checkout may be stale or upstream settings.json drifted from its own tree — ` +
        `verify sibling tag ships this hook.`
    );
  }
  // Log helper INFO — files present in tree but not declared as commands.
  const helpers = [...treeFiles].filter((leaf) => !declared.has(leaf));
  if (helpers.length > 0) {
    process.stderr.write(
      `INFO: ${helpers.length} helper file(s) in tree without settings.json command entry ` +
        `(expected — sourced by other hooks): ${helpers.slice(0, 3).join(', ')}` +
        (helpers.length > 3 ? ` +${helpers.length - 3} more` : '') +
        `\n`
    );
  }
  return { declaredCount: declared.size, treeFileCount: treeFiles.size };
}

/**
 * Collect leaf names of all *.sh files under `dir` (recursive) into `acc`.
 * Assumes the tree contains no symlinks — copyHookTreeRecursive would have
 * failed loud before this runs.
 */
function collectShFiles(dir, acc) {
  if (!existsSync(dir)) return;
  const entries = readdirSync(dir);
  for (const entry of entries) {
    const p = join(dir, entry);
    const stat = statSync(p);
    if (stat.isDirectory()) {
      collectShFiles(p, acc);
      continue;
    }
    if (stat.isFile() && entry.endsWith('.sh')) {
      acc.add(entry);
    }
  }
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
  process.stdout.write(
    `dist/lite/.claude/hooks/ copied ${distLite.copiedHookCount} hook binaries (mode 0755)\n`
  );

  process.exit(0);
}

main();
