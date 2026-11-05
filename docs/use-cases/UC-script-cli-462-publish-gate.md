---
tier: lite
---

# UC-script-cli-462 — hold or clear the npm publish gate

Brief use case per Cockburn, at the ceremony `.claude/rules/oo-ad-entry-point.md`
sets for a new adopter-facing script.

**Primary actor.** The operator.

**Scope.** `scripts/publish-gate.sh` and the `npm-publish` GitHub Environment.

**Stakeholders.** The operator, who wants a gate that holds by default and
yields when they say so. Adopters, who receive whatever a publish ships and
cannot un-receive it, because an npm version is never reusable.

**Precondition.** `gh` is authenticated. The `npm-publish` environment exists
on `sunj-labs/bassclef-cli`.

**Main success scenario — hold the gate.**

1. The operator runs `publish-gate.sh on`.
2. The script resolves their GitHub login and id.
3. It reads the environment. If the gate is already on, it says so and stops.
4. It writes a `required_reviewers` rule naming them.
5. It reads the environment back and confirms the rule is there.
6. It appends an audit line and reports the state, including whether admins
   can bypass.

**Main success scenario — clear it for one publish.**

1. The operator runs `publish-gate.sh off --authorized-by operator`.
2. The script clears the reviewer list.
3. It reads the environment back and confirms the rules are empty.
4. It appends an audit line naming who authorized the change.
5. It prints the command that restores the gate.

**Extensions.**

- **2a. `gh` is not authenticated.** Exit 3, naming `gh auth login`. No write.
- **3a. The environment does not exist.** Exit 3. No write — a write would
  create a fresh environment carrying no rules, which looks like success and
  is strictly worse than failing.
- **5a. The read-back disagrees with the write.** Exit 2, saying plainly that
  the gate is not protecting publish. A zero exit from `gh api` is not
  evidence that a rule landed.
- **5b. The response cannot be parsed.** Report `UNKNOWN` and exit 2. Never
  report `ON`, because an unreadable gate must not read as a protected one.
- **1a. `off` without `--authorized-by`.** Exit 3. No write. The argument is
  the record of who decided, and clearing the gate is not an inference an
  agent gets to make.

**Postcondition on success.** The environment's protection rules match what
was asked for, verified by reading them back, and the audit log carries a
line for the change.

**Postcondition on failure.** The gate is either unchanged or reported as
untrustworthy. No path leaves the operator believing publish is gated when it
is not.

**Open.** Restoring the gate after a `trust` publish is the operator's or the
dispatch's responsibility today. Nothing yet notices a gate left open. Session-start
reporting is the obvious follow-on, and it is named in the runbook rather than
pretended away.
