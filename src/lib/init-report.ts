// One description of an init run, read by three writers.
//
// @pattern patterns/code/fowler/value-object.md
//
// Per ADR-010 D8 and the decomposition at
// docs/decompositions/2026-09-17-cli-1.1.1-init-reporting.md: the banner,
// the JSON report, and the init manifest used to each walk the copied
// list and count it their own way. Three counters drift. This module
// counts once; everything downstream reads the same object.

import { classifyEntry, emptyCatalogCounts, type Family } from './catalog-classify.js';

/** One file the walker copied, as recorded at the moment of the write. */
export interface ReportEntry {
  path: string;
  scope: 'user' | 'project';
  content_hash_sha256?: string;
}

/** One file cli composed from a template. */
export interface ReportConfig {
  path: string;
  hash?: string;
}

export interface InitReportInput {
  entries: readonly ReportEntry[];
  configs: readonly ReportConfig[];
  refused: readonly string[];
  errored: readonly string[];
  /** Hook commands the copied settings.json declares. */
  hookCount: number;
  /**
   * Of the copied entries, how many are hook files the settings.json
   * actually names as a command. Hook helpers and fragments ship
   * alongside declared commands and are not counted here, so this number
   * is comparable to `hookCount`. Without it the report would pair a
   * declared-command count with a file count and invite the reader to
   * subtract them.
   */
  declaredHooksCopied: number;
  tier: string;
}

export interface InitReport {
  /** Shape marker for readers. Bumped when a field changes meaning. */
  schema_version: 3;
  tier: string;
  totals: {
    /**
     * Every file the run touched: composed configs, copied entries, and
     * the files it refused or errored on. This is the number the init
     * manifest records, so the two cannot disagree. An earlier shape
     * counted only successes and drifted from the manifest by exactly
     * the refused count on any re-run (RFC-0005 A-1).
     */
    files: number;
    /** Files actually written this run: configs plus copied entries. */
    written: number;
    /** Copied entries that landed inside the adopter repo. */
    project: number;
    /** Copied entries that landed under the operator's home directory. */
    user: number;
    /** Files cli composed from a template. */
    configs: number;
  };
  /** Count per catalog family. Sums to the number of copied entries. */
  catalog: Record<Family, number>;
  hooks: {
    /** Hook commands the copied settings.json names. */
    declared: number;
    /**
     * Of those declared commands, how many landed. Comparable to
     * `declared` — same unit.
     */
    copied: number;
    /**
     * Every hook file copied, across both scopes. Larger than `copied`
     * because helpers and fragments ship alongside declared commands.
     * Named separately so a reader does not subtract two different units.
     */
    files: number;
  };
  /** Files an existing file blocked. Not an error; init exits 0. */
  refused: number;
  /** Files that could not be read or written. */
  errored: number;
  /**
   * refused + errored.
   *
   * Kept for one release per ADR-010 D7 and RFC-0004 H-1. A reader
   * holding `if (report.failed > 0)` does not crash when the field is
   * removed — it reads undefined, which is falsy, and stops reporting
   * failures while appearing to work. Retires at 1.2.0.
   */
  failed: number;
}

/**
 * Build the run description.
 *
 * Precondition: `entries` came from one completed copy run.
 * Postcondition: `totals.written === configs.length + entries.length`;
 * `totals.files` additionally counts refused and errored files, so it
 * equals the number of entries the manifest records; and the per-family
 * counts sum to `entries.length`. Because all three writers read this
 * object, they cannot disagree about the numbers.
 */
export function buildInitReport(input: InitReportInput): InitReport {
  const catalog = emptyCatalogCounts();
  let project = 0;
  let user = 0;

  for (const e of input.entries) {
    catalog[classifyEntry(e.path)] += 1;
    if (e.scope === 'user') user += 1;
    else project += 1;
  }

  const refused = input.refused.length;
  const errored = input.errored.length;
  const written = input.configs.length + input.entries.length;

  return {
    schema_version: 3,
    tier: input.tier,
    totals: {
      files: written + refused + errored,
      written,
      project,
      user,
      configs: input.configs.length,
    },
    catalog,
    hooks: {
      declared: input.hookCount,
      copied: input.declaredHooksCopied,
      files: catalog.hooks,
    },
    refused,
    errored,
    failed: refused + errored,
  };
}

/**
 * Write the report as the entire content of a stream.
 *
 * Precondition: the adopter passed `--json`.
 * Postcondition: the stream received one JSON object and one newline.
 * Nothing else. An assertion that the output merely *parses* would pass
 * with a human line appended, which is the defect this closes (#94).
 */
export function renderJsonReport(report: InitReport, write: (s: string) => void): void {
  write(JSON.stringify(report) + '\n');
}
