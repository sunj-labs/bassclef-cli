# Publish setup — how to release @thebassclef/core

You read this once before the first release. Everything below is a
one-time setup step. After it lands, releases are `git tag` + `gh release
create`.

## One-time setup

### 1. Turn on 2FA on your npm account

Passkey or YubiKey. Not TOTP. Not SMS. Two reasons:

- Trusted publisher config on npmjs.com sits on this account. If your
  account gets stolen, an attacker can swap the config and publish
  anything.
- Provenance attestations bind to npm's identity; a weak factor
  weakens every future release.

Go to `https://www.npmjs.com/settings/<user>/tfa` and set it up.

### 2. Reserve `@thebassclef/core` on npm

Publish 0.0.1 by hand once, from your machine, using `npm login` +
`npm publish --access public`. This reserves the name. Every publish
after this uses the workflow, not your laptop.

```
# One-time — reserves the name only.
npm login
npm publish --access public
```

If someone already reserved the name, file a support ticket with npm.

### 3. Turn on trusted publisher for this package

Finish step 2 first. The trusted-publisher settings page only appears
after `@thebassclef/core` exists on npm. If step 3 looks blank, go
back to step 2.

Go to `https://www.npmjs.com/package/@thebassclef/core/access` →
Publishing access → GitHub Actions.

Fill in:

- Repository owner: `sunj-labs`
- Repository name: `bassclef-cli`
- Workflow filename: `publish.yml`
- Environment name: `npm-publish`

Save.

**Do not skip the environment name.** Without it, any workflow file
in the repo could publish. The environment name pins the specific
workflow AND the specific approval gate to the trusted publisher.

### 4. Create the GitHub Environment `npm-publish`

Go to `https://github.com/sunj-labs/bassclef-cli/settings/environments`.

Click "New environment". Name it `npm-publish`. Configure:

- Required reviewers → add yourself.
- Prevent self-review → leave unchecked (single maintainer; ADR-004
  §Accepted risks).
- Deployment branches → limit to `main` and tags matching `v*`.

Save.

### 5. Turn on 2FA on your GitHub account

Same reason as npm. Passkey or YubiKey. GitHub settings → Password
and authentication → Two-factor authentication.

## Every release

The setup above runs once. After that, every release is:

```
# Bump package.json version by hand OR with npm.
npm version patch    # or minor, or major

# Push the tag.
git push origin main --follow-tags

# Create the release on GitHub.
gh release create v0.0.2 --generate-notes

# Watch the workflow.
gh run watch
```

The workflow triggers on the release event. It runs:

1. Checkout at the tag.
2. Install with `--ignore-scripts`.
3. `validate-tag.mjs` — tag matches package.json + reachable from main.
4. Build + test + typecheck.
5. `npm pack --dry-run` to get the shipped file list.
6. `andon-scan.mjs` — refuses operator-private leaks.
7. `tier-filter.mjs` — refuses `tier: upstream` frontmatter.
8. **Pauses at the Environment gate. Click "Review deployments" →
   Approve.**
9. `npm publish --provenance --ignore-scripts` via trusted publisher.

If any step fails, nothing publishes. Fix the failing check, delete
the tag, re-tag, re-run.

## If publish refuses

The workflow logs name the failing check + the fix. Common shapes:

**"validate-tag: version mismatch"** — `package.json` says one
version, the tag says another. Bump `package.json`, commit, delete
the tag, re-push.

**"validate-tag: not reachable from origin/main"** — you tagged on a
feature branch. Merge to main first, then tag from main.

**"andon-scan: ANDON TRIPPED"** — a file the workflow is about to
ship contains an operator-private term (absolute home path, email
address in an unexpected file, `docs/operator-private/`
reference). Rebuild from a CI-clean checkout. If the reference is
intentional, add `# andon-allow: <regex>` to the file header.

**"tier-filter: REFUSED"** — a Markdown file the workflow is about to
ship has YAML frontmatter with `tier: upstream`. That content is
internal-only per bassclef's tier system. Retag to `tier: lite` or
`tier: standard`, or exclude the file from `package.json` `files`.

## Audit habit — check the log after every publish

You have single-reviewer approval on the Environment gate. That
saves ceremony but means one account compromise can publish. The
mitigation is honest checking after the fact.

After every release:

- Open the run at
  `https://github.com/sunj-labs/bassclef-cli/actions/workflows/publish.yml`.
  Confirm the SHA, tag, and timing match what you intended.
- Open the npm activity log at
  `https://www.npmjs.com/settings/<user>/audit`. Confirm the publish
  shows the workflow's OIDC identity and no other source.

Any surprise (unexpected publish, different SHA, different identity)
means your account is compromised. Rotate immediately.

## Emergency rollback

npm allows `npm unpublish` on versions less than 72 hours old. After
that, no unpublish.

The pipeline's job is refusing to publish something wrong. Once
0.0.2 is out, 0.0.3 is the fix path, not an unpublish.

## Refs

- Contract: `docs/adrs/ADR-004-publish-pipeline-safety-contract.md`
- Workflow: `.github/workflows/publish.yml`
- Scripts: `scripts/validate-tag.mjs`, `scripts/andon-scan.mjs`,
  `scripts/tier-filter.mjs`
- Bet: `docs/iteration-bets/2026-08-06b-launch-npm-thebassclef-core.md`
  L124 (WU-4 scope)
- npm trusted publishers docs:
  https://docs.npmjs.com/trusted-publishers/
