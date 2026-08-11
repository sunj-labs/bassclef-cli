// @requirement R-NPM-001
// Registry: docs/requirements/2026-08-11-npm-distribution.md.
// R-NPM-001 covers repo scaffold shape — TypeScript + Vite + files
// whitelist + Apache-2.0 license per bet L152.

import { defineConfig } from 'vite';
import dts from 'vite-plugin-dts';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));

// Vite library mode: two entrypoints (CLI + programmatic API).
// - cli.ts becomes dist/cli.js (ESM only; consumed by `bin: bassclef`)
// - index.ts becomes dist/index.{js,cjs} + dist/index.d.ts (dual module + types)
// Externalize Node builtins so `require('fs')` etc. stay resolved by the
// runtime, not the bundle. This keeps the shipped dist small and cold-start
// fast (Ousterhout: economy of mechanism).
export default defineConfig({
  build: {
    target: 'node20',
    outDir: 'dist',
    emptyOutDir: true,
    lib: {
      entry: {
        cli: resolve(__dirname, 'src/cli.ts'),
        index: resolve(__dirname, 'src/index.ts'),
      },
      formats: ['es', 'cjs'],
      fileName: (format, entryName) => {
        // Vite's lib.formats applies to every entry uniformly. We want the
        // CLI to run as ESM (package.json `type: module`) and the
        // programmatic API to ship both. Use distinct extensions per
        // format so the two builds do not overwrite one another. The
        // `bin` field points at `dist/cli.js` (the ESM one). `dist/cli.cjs`
        // is emitted but not referenced by any manifest — a small,
        // harmless artifact of Vite's uniform-per-entry format policy.
        // Alternative considered: two-config build split so the CLI
        // emits ESM only. Rejected as premature — the size overhead
        // is under 2 KB and a single config is simpler to read.
        const ext = format === 'es' ? 'js' : 'cjs';
        return `${entryName}.${ext}`;
      },
    },
    rollupOptions: {
      external: [
        /^node:/,
        'fs',
        'path',
        'os',
        'process',
        'child_process',
        'url',
        'util',
      ],
      output: {
        // npm's `bin` shim on POSIX resolves through the shebang, not the
        // file extension. Without `#!/usr/bin/env node` on cli.js, `bassclef`
        // installed globally fails with an exec-format error on macOS + Linux.
        banner: (chunk) => (chunk.fileName === 'cli.js' ? '#!/usr/bin/env node' : ''),
      },
    },
    // sourcemap: 'hidden' emits .map files for local debugging but strips
    // the //# sourceMappingURL= reference from .js/.cjs so shipped code
    // does not point at the maps. Belt and suspenders: package.json
    // files field explicitly whitelists only .js, .cjs, .d.ts so .map
    // files never enter the npm tarball even if a future build change
    // re-enables inline references. See ADR-001 §Invariants (source-map
    // exclusion, added 2026-08-11 in feat/iter-a-source-map-safety) for
    // the semver-locked contract. Reason for the discipline: Anthropic
    // v2.1.88 shipped 59.8 MB source map from a similar Bun default
    // config in March 2026 (per InfoQ + Layer5 write-ups).
    sourcemap: 'hidden',
    minify: false,
  },
  plugins: [
    dts({
      // Only emit types for the programmatic API entry.
      // The CLI has no consumers importing its exports.
      entryRoot: 'src',
      include: ['src/index.ts'],
      outDir: 'dist',
    }),
  ],
});
