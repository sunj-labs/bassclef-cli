import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['tests/**/*.test.ts'],
    testTimeout: 10000,
    // These tests spawn the compiled CLI. Build must run before test.
    // We do NOT set globalSetup to auto-build — that would hide build
    // failures behind test failures. Run `npm run build && npm test`
    // explicitly, per the split-mechanism discipline in Evil Martians'
    // 2026 guide (bet L98).
  },
});
