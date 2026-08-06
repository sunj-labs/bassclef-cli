// Content hash — SHA-256 of a NORMALIZED UTF-8 string.
//
// Normalization steps (in order):
//   1. Strip a UTF-8 BOM at the start of the string if present.
//      Editors on Windows and older tools sometimes add one on save
//      to files that never had one; without stripping, sync would
//      falsely report the file as "edited by you" on a first save.
//   2. Normalize CRLF sequences to LF. Windows adopters and POSIX
//      adopters read + write the same files through Git; a git
//      checkout on Windows may convert LF to CRLF. Sync should not
//      treat that as an edit.
//   3. SHA-256 of the UTF-8 bytes of the result.
//
// Intentionally NOT normalized:
//   - Trailing whitespace on lines. Whitespace can be semantic in
//     Markdown code fences and YAML; treating it as an edit is safer.
//   - Unicode NFC/NFD normalization. Adopters editing on macOS
//     Finder-created filenames vs Linux command-line may differ, but
//     canonicalizing the FILE content is an over-reach for the
//     sync-diff use case.
//   - Whitespace inside strings (multi-space, tabs vs spaces).
//     Re-indentation is a legitimate edit signal.
//
// Any change to the above steps is a MAJOR bump under semver.
// Once 0.0.2 tags, every adopter manifest carries hashes computed
// under these exact rules.

import { createHash } from 'node:crypto';

const BOM = '﻿';

export function hashContent(content: string): string {
  let normalized = content;
  if (normalized.charCodeAt(0) === 0xfeff) {
    normalized = normalized.slice(1);
  }
  normalized = normalized.replace(/\r\n/g, '\n');
  return createHash('sha256').update(normalized, 'utf8').digest('hex');
}
