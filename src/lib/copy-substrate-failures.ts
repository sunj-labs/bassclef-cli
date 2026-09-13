// Shared failure taxonomy for the init walker chain.
//
// Consumers:
//  - src/lib/copy-substrate.ts  (walker; throws ManifestMissing, SchemaIncompatible, BundleMissing)
//  - src/lib/resolve-home.ts    (throws EnvironmentIncomplete, SudoBypassRefused)
//  - src/lib/scope-router.ts    (throws UnknownScopePrefix, PathTraversalRefused; re-throws home-resolver failures)
//
// Extracted from copy-substrate.ts per RFC-0002 P2 fold to break the
// circular import that would otherwise form as scope-router.ts + resolve-home.ts
// come online.
//
// @verifies P2-fold + cross-cutting failure vocabulary per GRASP decomp

export type CopyFailureKind =
  // walker-side kinds (existing since cli 1.0.0)
  | 'ManifestMissing'
  | 'SchemaIncompatible'
  | 'BundleMissing'
  // scope-router + home-resolver kinds (added cli 1.0.1 per RFC-0002 folds)
  | 'EnvironmentIncomplete'
  | 'SudoBypassRefused'
  | 'UnknownScopePrefix'
  | 'PathTraversalRefused';

/**
 * Typed error the init dispatcher maps to exit codes.
 *
 * Nygard fail-loud discipline: each kind carries the specific cure as
 * part of the message; the dispatcher does not fabricate its own.
 */
export class CopyFailure extends Error {
  constructor(readonly kind: CopyFailureKind, message: string) {
    super(message);
    this.name = 'CopyFailure';
  }
}
