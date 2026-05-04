---
name: update-app
description: Update an existing runtipi store app to its latest version — fetches the latest GitHub release, bumps version in config.json and docker-compose.json, detects new env vars, adds missing form_fields, runs tests, and opens a PR. Triggered by /update-app <app_name>.
license: MIT
compatibility: claude-code
metadata:
  audience: maintainers
  workflow: github
---

## What I do

Given an app name (e.g., `dawarich`), I:

1. Fetch the latest release tag from GitHub
2. Compare it with the current version in `apps/<app>/config.json`
3. If already up to date — stop and say so
4. Otherwise: create a new git worktree from `origin/main`, update all version strings, detect new env vars, update `form_fields` and `docker-compose.json` environment sections, bump `tipi_version` and `updated_at`, run tests, ship a PR, and open it in the browser

---

## Step 0 — Fetch origin/main and read current version

The repo is a **bare git repo** at `$REPO_DIR`. There is no checkout at the repo root — always run git commands with `-C $REPO_DIR` or from inside a worktree.

First, resolve the bare repo path (works regardless of where the repo was cloned):

```bash
REPO_DIR=$(git rev-parse --absolute-git-dir)
```

**NEVER run `git status` or `git diff` with `-C` on the bare repo** — those commands require a work tree and will fail with `fatal: this operation must be run in a work tree`. Only run them inside a worktree (Step 2+).

**ALWAYS fetch origin/main first** before reading any files — the local `main` ref may be stale:

```bash
git -C $REPO_DIR fetch origin +refs/heads/main:refs/remotes/origin/main
```

Then read the current app config from `origin/main` (not `main`):

```bash
git -C $REPO_DIR show origin/main:apps/<app-name>/config.json
```

Extract `version` and `source` fields. Parse `source` to get the GitHub owner/repo (e.g., `https://github.com/Freika/dawarich` → `Freika/dawarich`).

---

## Step 1 — Fetch latest GitHub release and all skipped versions

```bash
gh release list --repo <owner>/<repo> --limit 20
```

Pick the **latest stable** tag — skip pre-releases (`-rc.`, `-beta.`, `-alpha.`).

Extract the **latest stable version tag** (strip leading `v` if needed — match the format already used in `config.json` exactly, e.g. if config has `"1.3.1"` use `"1.3.2"` not `"v1.3.2"`).

If the latest release tag matches the current `version` field → print "Already up to date at <version>" and **stop**.

**Collect release notes for ALL skipped versions** (every stable release between current version and the latest, inclusive of the latest). Fetch each one:

```bash
gh release view <tag> --repo <owner>/<repo> --json tagName,body
```

Concatenate these into a `$SKIPPED_RELEASE_NOTES` variable ordered from oldest-skipped to newest. This consolidated body is used in Step 3 for env var detection and in the PR body.

---

## Step 2 — Create a fresh git worktree from latest origin/main

Worktrees go in `/private/tmp/`. The branch is created inline during `worktree add` — do NOT run a separate `git checkout -b` afterward.

The fetch was already done in Step 0 — `origin/main` is current. Just verify, clean, and create:

```bash
# Verify we have the latest
git -C $REPO_DIR log origin/main --oneline -1

# Remove any stale worktree at that path
git -C $REPO_DIR worktree remove --force $REPO_DIR/<app-name>-update 2>/dev/null || true
rm -rf $REPO_DIR/<app-name>-update
git -C $REPO_DIR worktree prune

# Create the worktree on a new branch pointing at origin/main (latest)
git -C $REPO_DIR worktree add $REPO_DIR/<app-name>-update -b update-<app-name>-<new-version> origin/main
```

All subsequent file edits happen inside `$REPO_DIR/<app-name>-update/apps/<app-name>/`.

---

## Step 3 — Detect new environment variables

Use **two complementary sources** — the release body AND the upstream compose file. The upstream compose is sometimes updated later than the release, so the release notes are the authoritative source for breaking changes.

### 3a — Scan the release body for env var mentions

Use the consolidated `$SKIPPED_RELEASE_NOTES` from Step 1 (all skipped versions). Scan it for:
- Any `UPPER_SNAKE_CASE` tokens that look like env var names
- Explicit migration instructions (e.g. "set these env vars", "required in production")
- Linked issues or comments — if the release references an issue/comment URL, fetch it with `gh api` and extract any env var names mentioned there

```bash
# Example: fetch a linked issue comment
gh api repos/<owner>/<repo>/issues/comments/<comment-id> --jq '.body'
```

Extract every env var name mentioned. These are candidates regardless of whether the upstream compose has them yet.

### 3b — Scan the upstream compose and .env.example

The upstream repo may not have `docker-compose.yml` or `.env.example` at the **repo root**. Always list the root directory first to find where these files live:

```bash
gh api repos/<owner>/<repo>/contents/ --jq '.[].name'
```

If they're not at root, look for a `docker/` subdirectory:

```bash
gh api repos/<owner>/<repo>/contents/docker --jq '.[].name'
```

Then fetch whichever paths exist:

```bash
gh api repos/<owner>/<repo>/contents/<path>/docker-compose.yml --jq '.content' | base64 -d
gh api repos/<owner>/<repo>/contents/<path>/.env.example --jq '.content' | base64 -d 2>/dev/null || true
```

Collect all env var keys from the upstream compose file (all services).

### 3c — Merge and evaluate

Combine candidates from 3a and 3b. Compare the full set against keys already present in `docker-compose.json` environment arrays across all services. The **difference** = new env vars to evaluate.

For each new env var:
- Classify it: `random` secret, user-set `password`, `text`, `boolean`
- Decide if it should become a `form_field` (user-configurable) or be hard-coded internally
- If user-configurable → add a `form_field` entry AND an environment entry in docker-compose
- If internal/hardcoded → add only to docker-compose with the hardcoded value

---

## Step 4 — Update config.json

File: `$REPO_DIR/<app-name>-update/apps/<app-name>/config.json`

Changes to make:
1. `"version"`: set to new version string (match existing format exactly)
2. `"tipi_version"`: increment by 1
3. `"updated_at"`: set to current Unix timestamp in milliseconds
4. `"form_fields"`: append any new user-configurable env vars identified in Step 3

Get current timestamp in ms:
```bash
python3 -c "import time; print(int(time.time() * 1000))"
```

**Preserve all existing fields exactly.** Only change the four fields listed above.

---

## Step 5 — Update docker-compose.json

File: `$REPO_DIR/<app-name>-update/apps/<app-name>/docker-compose.json`

Changes to make:
1. Update **all** `"image"` fields that contain the old version string to the new version across every service
2. Add new env var entries to all services that need them (if a var appears in both app and worker services upstream, add to both)

**Preserve all existing fields, formatting, and structure exactly.**

---

## Step 6 — Run tests

```bash
cd $REPO_DIR/<app-name>-update && bun install && bun run test
```

If tests fail: read the error, fix the issue, re-run. Do NOT proceed until all tests pass.

---

## Step 7 — Ship the PR

Commit and push from **inside the worktree**. Use `--head` and `--base` explicitly with `gh pr create` — omitting them fails from a worktree context.

**NOTE**: If git commands fail with "fatal: this operation must be run in a work tree", set explicit environment variables:

```bash
export GIT_DIR=$REPO_DIR/worktrees/<app-name>-update
export GIT_WORK_TREE=$REPO_DIR/<app-name>-update
```

Then run all subsequent git commands normally.

```bash
git add apps/<app-name>/config.json apps/<app-name>/docker-compose.json
git commit --no-gpg-sign -m "Update <AppName> to <new-version>"
git push -u origin update-<app-name>-<new-version>

gh pr create \
  --head update-<app-name>-<new-version> \
  --base main \
  --title "Update <AppName> to <new-version>" \
  --body "..."

# Open PR in browser for review
open <PR_URL>
```

PR body template:
```markdown
## Update <AppName> <old-version> → <new-version>

### Changes
- Bumped version from `<old>` to `<new>`
- Updated Docker image tag(s)
- Added new environment variables: <list them, or omit section if none>

### Release notes
<!-- Include ALL skipped versions, oldest first. If only one version was skipped, one section is fine. -->
#### <intermediate-version-1> (if any)
<release notes for that version>

#### <new-version>
<release notes for latest version>

### Checklist
- [x] Version bumped in config.json and docker-compose.json
- [x] tipi_version incremented
- [x] Tests pass (`bun run test`)
```

---

## Rules

- **NEVER** modify files outside `apps/<app-name>/` in the worktree
- **NEVER** touch unrelated apps
- **NEVER** change `config.json` fields other than `version`, `tipi_version`, `updated_at`, and `form_fields`
- **NEVER** use `latest` as an image tag — always pin to the exact version
- **ALWAYS** fetch `origin/main` in Step 0 before reading any files — local `main` may be stale. Use `origin/main` everywhere, never `main` or `FETCH_HEAD`
- **NEVER** run `gh pr create` without `--head` and `--base` — it will fail from a worktree
- **NEVER** run a separate `git checkout -b` after `worktree add` — the branch is created inline
- If git commands in the worktree fail with "must be run in a work tree", explicitly set `GIT_DIR` and `GIT_WORK_TREE` env vars (see Step 7 troubleshooting)
- If the app is already at the latest version, stop and say so
- If no `.env.example` or compose file is found via `gh api`, skip env var detection and note it in the PR body
- Match the **exact version string format** already used in `config.json`
- When in doubt about whether a new env var should be a `form_field`, prefer keeping it internal with a hardcoded default and mention it in the PR body for human review
