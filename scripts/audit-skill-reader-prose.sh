#!/usr/bin/env bash
# tier: upstream
# audit-skill-reader-prose.sh — report wording a first-time reader bounces on.
#
# Reads the assembled package at dist/lite/.claude/skills/ — what adopters
# actually receive. Fixes land in bassclef-upstream, so output names the
# skill and line so the upstream path is easy to find.
#
# Reports four patterns, named P1 to P4 after the audit at
# docs/audits/2026-10-26-persona-coherence-first-touch.md:
#
#   P1  a long skill with no "## Details below the fold" boundary
#   P2  a ticket reference in reader-facing prose
#   P3  an imperative aimed at the model in reader-facing prose
#   P4  a BLOCK-tier jargon term in reader-facing prose
#
# Reader-facing means above the boundary. Code fences and inline backtick
# spans are stripped first, so a path inside backticks does not count.
#
# Exit codes: 0 clean, 1 findings reported, 2 nothing to read.
#
# Usage:
#   bash scripts/audit-skill-reader-prose.sh                 # every skill
#   bash scripts/audit-skill-reader-prose.sh whereami sprint # named skills
#   SKILL_DIR=/other/path bash scripts/audit-skill-reader-prose.sh
#
# Contract: docs/use-cases/UC-script-453-audit-skill-reader-prose.md
# Anchors: @luminary alan-cooper (serve the reader's goal),
#          @luminary michael-feathers (pin what it does before naming it).

set -euo pipefail

SCRIPT_NAME="$(basename "$0" .sh)"
SKILL_DIR="${SKILL_DIR:-dist/lite/.claude/skills}"
LONG_SKILL_LINES="${LONG_SKILL_LINES:-300}"

if [ ! -d "$SKILL_DIR" ]; then
  echo "${SCRIPT_NAME}: no skills at ${SKILL_DIR}" >&2
  echo "  The assembled package is built by scripts/prepublish-bundle-substrate.mjs." >&2
  echo "  Run that first, or set SKILL_DIR to a directory of skills." >&2
  exit 2
fi

shopt -s nullglob
if [ "$#" -gt 0 ]; then
  TARGETS=()
  for name in "$@"; do TARGETS+=("${SKILL_DIR}/${name}/SKILL.md"); done
else
  TARGETS=("${SKILL_DIR}"/*/SKILL.md)
fi

if [ "${#TARGETS[@]}" -eq 0 ]; then
  echo "${SCRIPT_NAME}: no SKILL.md files matched" >&2
  exit 2
fi

python3 - "$LONG_SKILL_LINES" "${TARGETS[@]}" <<'PY'
import re, sys, os

long_limit = int(sys.argv[1])
paths = sys.argv[2:]

TICKET = re.compile(r"\b(?:bassclef(?:-upstream|-cli|-web)?#\d+|Task \d+(?:\.\d+)*|ADR-\d+)")
INSTR  = re.compile(r"(?:^|\s)(Print |Dispatch |Resolve tier|Touch |Emit |Fire |Skip this step)", re.I)
JARGON = ["composer","primitive","tier-preset","load-bearing","blast radius",
          "compose-with","scope-bounded","operationalize","wirings","operator-eyes",
          "discipline-debt","meta-pattern","meta-loop","leverage","synergies",
          "verticals","circle back","deep dive","low-hanging fruit","ideate",
          "value-add","move the needle"]

findings = []

for p in paths:
    if not os.path.isfile(p):
        continue
    slug = os.path.basename(os.path.dirname(p))
    lines = open(p, encoding="utf-8").read().split("\n")
    total = len(lines)

    fold = None
    for n, l in enumerate(lines):
        if l.startswith("## Details below the fold"):
            fold = n
            break

    # P1 — a long skill with no reader/detail boundary.
    if fold is None and total >= long_limit:
        findings.append((slug, "-", "P1", "high",
                         f"{total} lines, no '## Details below the fold' boundary"))

    # Reader-facing prose, fences and inline code stripped.
    cut = fold if fold is not None else total
    reader, fenced = [], False
    for n, l in enumerate(lines[:cut], 1):
        if l.strip().startswith("```"):
            fenced = not fenced
            continue
        if fenced:
            continue
        reader.append((n, re.sub(r"`[^`]*`", "", l)))

    for n, l in reader:
        for m in TICKET.findall(l):
            findings.append((slug, n, "P2", "med", f'ticket reference "{m}"'))
        m = INSTR.search(l)
        if m:
            findings.append((slug, n, "P3", "med",
                             f'reads as an order to the model ("{m.group(1).strip()}...")'))
        low = l.lower()
        for t in JARGON:
            if re.search(r"\b" + re.escape(t) + r"\b", low):
                findings.append((slug, n, "P4", "med", f'jargon "{t}"'))

if not findings:
    print("No findings. Every skill read clean.")
    sys.exit(0)

order = {"high": 0, "med": 1, "low": 2}
findings.sort(key=lambda f: (order[f[3]], f[0], f[2]))

print(f"{'skill':16} {'line':>6}  {'':4} {'sev':5} finding")
print("-" * 92)
for slug, line, pat, sev, msg in findings:
    print(f"{slug:16} {str(line):>6}  {pat:4} {sev:5} {msg}")

print()
counts = {}
for f in findings:
    counts[f[2]] = counts.get(f[2], 0) + 1
print("By pattern: " + " · ".join(f"{k} x{v}" for k, v in sorted(counts.items())))
print(f"Total: {len(findings)} findings across {len(set(f[0] for f in findings))} skills")
print()
print("P1 is the cheapest to fix — one heading in the right place.")
print("Fixes land in sunj-labs/bassclef-upstream at .claude/skills/<slug>/SKILL.md.")
sys.exit(1)
PY
