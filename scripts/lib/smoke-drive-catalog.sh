#!/usr/bin/env bash
# tier: standard
# @pattern patterns/code/gof/strategy.md
# @pattern patterns/code/parnas/information-hiding.md
#
# smoke-drive-catalog.sh — per-skill drive configuration lookup.
#
# Batch A (this file's initial ship) covers 7 dev-flow skills:
#   sprint / whereami / temperance / diagnose / verify / kiss / luminary
# Batch B extends with 7 SDLC-chain skills (spec, shape, decompose, etc.).
#
# Bash 3.2 portable — function-based case-statement lookup (no assoc arrays).
#
# Consumers (per Parnas information-hiding fold BA2):
#   scripts/smoke-drive-generic.sh — takes SKILL_NAME, calls these lookups
# Consumers do NOT edit patterns per-skill; they call the accessors below.

# _catalog_prompt SKILL_NAME
# Emits default SMOKE_DRIVE_PROMPT_TEXT for the named skill.
_catalog_prompt() {
  case "$1" in
    # Batch A — dev-flow skills
    sprint)           echo "run /sprint" ;;
    whereami)         echo "run /whereami" ;;
    temperance)       echo "run /temperance" ;;
    diagnose)         echo "run /diagnose" ;;
    verify)           echo "run /verify" ;;
    kiss)             echo "run /kiss" ;;
    luminary)         echo "run /luminary" ;;
    # Batch B — SDLC-chain skills
    shape)            echo "run /shape" ;;
    spec)             echo "run /spec" ;;
    decompose)        echo "run /decompose" ;;
    build)            echo "run /build" ;;
    architect-review) echo "run /architect-review" ;;
    longrun-prep)     echo "run /longrun prep" ;;
    session-end)      echo "run /session-end" ;;
    # Batch C — authoring / thought skills (safe smoke; no prod side effects)
    state-a-problem)  echo "run /state-a-problem brief" ;;
    value-prop)       echo "run /value-prop tweet" ;;
    whats-the-plan)   echo "run /whats-the-plan" ;;
    roadmap-reconcile) echo "run /roadmap-reconcile --dry-run" ;;
    promote)          echo "run /promote bassclef-evolution" ;;
    interpret-input)  echo "run /interpret-input" ;;
    use-case)         echo "run /use-case brief" ;;
    *)                return 1 ;;
  esac
}

# _catalog_ready SKILL_NAME
# Emits default SMOKE_DRIVE_READY_PATTERN for the named skill.
# Defaults match both fake_claude fixture ("READY>") and real claude's
# common prompt shapes ("> ", "> \n").
_catalog_ready() {
  case "$1" in
    sprint|whereami|temperance|diagnose|verify|kiss|luminary|\
    shape|spec|decompose|build|architect-review|longrun-prep|session-end|\
    state-a-problem|value-prop|whats-the-plan|roadmap-reconcile|promote|interpret-input|use-case)
      echo "READY>|>"
      ;;
    *) return 1 ;;
  esac
}

# _catalog_done SKILL_NAME
# Emits default SMOKE_DRIVE_DONE_PATTERN for the named skill.
_catalog_done() {
  case "$1" in
    sprint|whereami|temperance|diagnose|verify|kiss|luminary|\
    shape|spec|decompose|build|architect-review|longrun-prep|session-end|\
    state-a-problem|value-prop|whats-the-plan|roadmap-reconcile|promote|interpret-input|use-case)
      echo "DONE>|complete|done"
      ;;
    *) return 1 ;;
  esac
}

# _catalog_timeout SKILL_NAME
# Emits default TIMEOUT_SEC for the named skill.
_catalog_timeout() {
  case "$1" in
    # Batch A
    whereami)         echo "60"  ;;   # snapshot read; fast
    temperance)       echo "60"  ;;   # short marker touch
    verify)           echo "120" ;;   # verification checks
    sprint)           echo "120" ;;   # orientation output
    kiss)             echo "120" ;;   # compression
    luminary)         echo "120" ;;   # lens picker
    diagnose)         echo "180" ;;   # multi-step diagnosis
    # Batch B — SDLC skills; longer phases
    session-end)      echo "120" ;;   # closeout
    shape)            echo "180" ;;   # canvas + spec tier picker
    decompose)        echo "180" ;;   # GRASP + BCE
    spec)             echo "240" ;;   # spec authoring
    build)            echo "300" ;;   # construction chain
    architect-review) echo "300" ;;   # audit
    longrun-prep)     echo "300" ;;   # meta-prep
    # Batch C — authoring / thought skills; typically fast
    value-prop)       echo "60"  ;;   # ≤280 chars tweet
    whats-the-plan)   echo "60"  ;;   # plan declaration
    state-a-problem)  echo "90"  ;;   # brief problem statement
    interpret-input)  echo "120" ;;   # input classifier
    use-case)         echo "120" ;;   # brief use case
    promote)          echo "120" ;;   # promote candidate
    roadmap-reconcile) echo "180" ;;  # canvas reconciliation
    *) return 1 ;;
  esac
}

# _catalog_setup SKILL_NAME
# Emits space-separated setup helper function names for the named skill.
# Empty output means "no setup needed" — driver treats that as OK.
# Names refer to functions in scripts/lib/smoke-drive-setup.sh.
_catalog_setup() {
  case "$1" in
    # Skills that need a fresh git repo
    onboard-repo)                echo "setup_git_init_clean" ;;
    build)                       echo "setup_git_init_clean setup_git_remote_scratch setup_gh_inject_smoke_label" ;;
    session-end)                 echo "setup_git_init_clean setup_chronicle_dir_writable" ;;
    longrun-prep)                echo "setup_git_init_clean setup_iteration_goals_dir_writable" ;;
    # Skills that fire `gh issue create`
    promote)                     echo "setup_gh_inject_smoke_label" ;;
    # All others need no setup
    *)                           echo "" ;;
  esac
}

# _catalog_teardown SKILL_NAME
# Emits space-separated teardown helper function names for the named skill.
# Empty output means "no teardown needed".
_catalog_teardown() {
  case "$1" in
    promote)                     echo "teardown_close_smoke_tickets" ;;
    build)                       echo "teardown_close_smoke_tickets teardown_delete_created_branch" ;;
    *)                           echo "" ;;
  esac
}

# _catalog_list_batch BATCH_NAME
# Emits space-separated skill names for the named batch.
_catalog_list_batch() {
  case "$1" in
    batch-a) echo "sprint whereami temperance diagnose verify kiss luminary" ;;
    batch-b) echo "shape spec decompose build architect-review longrun-prep session-end" ;;
    batch-c) echo "state-a-problem value-prop whats-the-plan roadmap-reconcile promote interpret-input use-case" ;;
    *) return 1 ;;
  esac
}

# _catalog_all_skills
# Emits space-separated list of every skill in the catalog.
_catalog_all_skills() {
  local a b c
  a=$(_catalog_list_batch batch-a)
  b=$(_catalog_list_batch batch-b)
  c=$(_catalog_list_batch batch-c)
  echo "$a $b $c"
}
