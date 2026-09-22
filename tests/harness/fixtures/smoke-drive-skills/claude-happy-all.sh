#!/usr/bin/env bash
# Mock claude — happy path for the natural-language skill drive.
# Reads the -p prompt from argv and returns skill-shaped output
# matching what a real LLM+skill dispatch would produce.
#
# Signals per-skill happy output based on which skill the prompt names.
# Also touches state/markers/temperance/* under CWD so the marker check passes.
set -eu

PROMPT=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -p) PROMPT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

case "$PROMPT" in
  *temperance*)
    mkdir -p state/markers/temperance
    touch "state/markers/temperance/drive-test-$$.marker"
    cat << 'EOF'
Firing /temperance skill.
Scope decision: add a login button to the test app.
Right thing: yes — the app needs it for the demo.
Right way: use the shipped Cooper component.
Drift trigger: any pull toward a full auth pipeline.
Marker written.
EOF
    ;;
  *luminary*don-norman*|*don-norman*)
    cat << 'EOF'
Loaded lens: Don Norman.
Norman's core principles: signifiers, mapping, feedback, constraints, affordances.
Applied to your surface, the lens catches missing feedback loops.
EOF
    ;;
  *kiss*)
    cat << 'EOF'
Ran /kiss words --rewrite on the input.
Original grade: 13.
Rewritten to grade 8: We noticed reporting could be more detailed.
Words swapped: "It has come to our attention" → "We noticed".
EOF
    ;;
  *state-a-problem*)
    cat << 'EOF'
Problem: session-start hooks fire twice on cold-adopter installs.
Who: cold adopters on first install.
What: hooks fire twice per session-start.
When: only on the first install of a new machine.
Why now: adopter noise from duplicate output.
Outcome: hooks fire once per SessionStart event.
EOF
    ;;
  *whats-the-plan*)
    cat << 'EOF'
Plan: ship a login button to the test app in 4 steps.
Step 1: /temperance to scope the change.
Step 2: /decompose to identify the boundary.
Step 3: TDD RED on the click handler.
Step 4: Ship + verify.
Chain complete.
EOF
    ;;
  *)
    echo "mock claude — unrecognized prompt: $PROMPT" >&2
    exit 1
    ;;
esac

exit 0
