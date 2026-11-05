---
tier: lite
---

# Pre-mortem — publish gate toggle (cli#462)

Three lenses, light mode per `.claude/skills/pre-mortem/SKILL.md`. Premise:
it is three months from now and the npm-publish gate has failed us. What
happened?

## Saltzer & Schroeder — fail-safe defaults, complete mediation

1. **`off` succeeded, `on` never ran.** A dispatch died between clearing
   the reviewer and restoring it. The gate sat open for weeks. → Every
   mutation verifies by read-back, and `off` prints the exact restore
   command so a human can finish it.
2. **An agent ran `off` on its own initiative.** → `off` refuses without an
   explicit authorization argument naming who approved it. No default.
3. **`status` lied.** The GitHub API shape shifted and the parse fell
   through to "ON". The operator trusted a gate that was not there. →
   `status` fails to `UNKNOWN`, never to `ON`. Unknown is reported as a
   problem, not a pass.
4. **The environment did not exist.** A `PUT` created a fresh one carrying
   no rules — worse than an error, because it looks like success. → Assert
   the environment exists before any write.
5. **The reviewer id belonged to someone else.** The gate named an account
   that cannot approve, so every publish hung. → Resolve the id from
   `gh api user` and echo the login back.
6. **`gh` was not authenticated.** Output was ambiguous. → Check first, fail
   with the fix.

## Michael Nygard — stability, fail-soft, visible state

1. **A partial write left `protection_rules` empty.** → Treat empty as
   gate-off and say so loudly; never report it as a transient.
2. **Network died mid-sequence.** → Every verb is idempotent; re-running
   `on` when already on is a no-op, not an error.
3. **Rate limit returned a non-zero exit with no explanation.** → Surface
   the API's own message rather than a generic failure.
4. **`can_admins_bypass: true` made the gate weaker than it read.** The
   operator believed approval was mandatory; an admin could click through.
   → `status` prints that flag every time. It is part of the gate's real
   strength.
5. **Nobody could reconstruct when the gate was opened.** → Append an audit
   line on every mutation: verb, version, resolved login, timestamp.

## Tony Hoare — pre/postconditions

1. **Preconditions** for any write: `gh` authenticated, environment exists,
   operator login resolvable. Checked, not assumed.
2. **Postcondition of `on`**: `protection_rules` contains a
   `required_reviewers` rule naming the operator. Verified by reading the
   environment back. A zero exit from `gh api` is not proof.
3. **Postcondition of `off`**: `protection_rules` is empty. Also verified by
   read-back.
4. **`status` is pure.** It mutates nothing, so it is safe to run anywhere,
   including from a hook.
5. **Idempotence** holds for both `on` and `off`.

## Folded into the design before the first line

- Read-back verification on every mutation. Exit 0 is not evidence.
- `status` fails to UNKNOWN.
- `off` requires an explicit authorization argument.
- `can_admins_bypass` surfaced in every status line.
- Audit line appended per mutation.
- Environment existence asserted before any write.
