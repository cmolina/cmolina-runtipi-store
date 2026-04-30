---
name: add-app
description: Add a self-hosted app to the runtipi store — researches the app, creates config.json, docker-compose.json, metadata files, downloads logo, runs tests, and opens a PR. Triggered by /add-app <app-name>.
license: MIT
compatibility: claude-code
metadata:
  audience: maintainers
  workflow: github
---

## What I do

Given an app name, I:

1. Research the app extensively (GitHub repo, Docker image, ports, env vars, dependencies)
2. Create app directory structure at `apps/<app-id>/`
3. Generate `config.json` with metadata, categories, and form_fields
4. Generate `docker-compose.json` with service definitions
5. Create `metadata/description.md` with app description
6. Download the app's logo to `metadata/logo.jpg`
7. Run tests
8. Ship a PR

---

## Step 1: Research the app

Search extensively for **$ARGUMENTS** to gather:

1. **GitHub repository** — find the official repo, read the README, docker-compose examples, and `.env.example` or environment variable docs
2. **Docker image** — find the official Docker image name on Docker Hub or GitHub Container Registry. Get the **latest stable version tag** (not `latest`)
3. **Default port** — what port the app listens on inside the container
4. **Environment variables** — ALL of them. Classify each as:
   - Required (app won't start without it)
   - Optional (has sensible defaults)
   - Generated (secrets, passwords, keys - use `"type": "random"`)
5. **Dependencies** — does it need a database (postgres, mysql, mariadb), cache (redis, valkey), or other services?
6. **Description** — what the app does, key features, what it replaces
7. **Categories** — pick from: `network`, `media`, `development`, `automation`, `social`, `utilities`, `photography`, `security`, `featured`, `books`, `data`, `music`, `finance`, `gaming`, `ai`
8. **Supported architectures** — typically `["arm64", "amd64"]`, verify from Docker Hub
9. **Logo** — find a URL to the app's logo/icon (PNG or JPG)

---

## Step 2: Create a git worktree from latest origin/main

This is a bare git repo. All work must happen in a worktree checked out from `origin/main`.

```bash
# Fetch main with explicit refspec to create proper origin/main reference
git -C /Users/cmolina/code/cmolina-runtipi-store.git fetch origin +refs/heads/main:refs/remotes/origin/main

# Remove any stale worktree
git -C /Users/cmolina/code/cmolina-runtipi-store.git worktree remove --force /private/tmp/add-<app-id> 2>/dev/null || true
rm -rf /private/tmp/add-<app-id>
git -C /Users/cmolina/code/cmolina-runtipi-store.git worktree prune

# Create worktree from origin/main on a new branch
git -C /Users/cmolina/code/cmolina-runtipi-store.git worktree add /private/tmp/add-<app-id> -b add-<app-id> origin/main

# Now create the app directory inside the worktree
mkdir -p /private/tmp/add-<app-id>/apps/<app-id>/metadata
```

The `<app-id>` must be lowercase kebab-case (e.g., `my-app`).

**All subsequent file creation/editing must use paths inside `/private/tmp/add-<app-id>/apps/<app-id>/`**

---

## Step 3: Create config.json

Create at `/private/tmp/add-<app-id>/apps/<app-id>/config.json`

Use this structure — reference existing apps `apps/dawarich/config.json` and `apps/whoami/config.json` for style:

```json
{
  "name": "App Display Name",
  "id": "<app-id>",
  "available": true,
  "short_desc": "One-line description (keep it concise)",
  "author": "Author or org name",
  "port": 8080,
  "categories": ["utilities"],
  "description": "Longer description of the app and what it does.",
  "tipi_version": 1,
  "version": "<latest-stable-version>",
  "source": "https://github.com/...",
  "website": "https://...",
  "exposable": true,
  "force_expose": false,
  "supported_architectures": ["amd64", "arm64"],
  "form_fields": [],
  "dynamic_config": true,
  "min_tipi_version": "v4.0.0",
  "created_at": <current-unix-ms>,
  "updated_at": <current-unix-ms>
}
```

### form_fields rules

For each environment variable the user needs to configure:

- **Passwords/secrets**: `{"type": "random", "label": "...", "env_variable": "...", "required": true, "min": 32}`
- **Secret keys (hex)**: `{"type": "random", "label": "...", "env_variable": "...", "required": true, "min": 64, "encoding": "hex"}`
- **Text inputs**: `{"type": "text", "label": "...", "env_variable": "...", "required": true/false, "hint": "...", "default": "..."}`
- **Booleans**: `{"type": "boolean", "label": "...", "env_variable": "...", "required": false, "default": false}`
- **Passwords user sets**: `{"type": "password", "label": "...", "env_variable": "...", "required": true, "min": 8}`

`env_variable` values MUST be `UPPER_SNAKE_CASE`.

---

## Step 4: Create docker-compose.json

Create at `/private/tmp/add-<app-id>/apps/<app-id>/docker-compose.json`

Use dynamic compose schema v2. Reference `apps/dawarich/docker-compose.json` for multi-service and `apps/whoami/docker-compose.json` for single-service examples.

```json
{
  "schemaVersion": 2,
  "services": [
    {
      "name": "<app-id>",
      "image": "author/image:<version>",
      "isMain": true,
      "internalPort": 8080,
      "environment": [
        {"key": "VAR_NAME", "value": "${VAR_NAME}"}
      ]
    }
  ]
}
```

### CRITICAL: Use runtipi environment variables correctly

Runtipi provides built-in environment variables you MUST use for volumes:

#### App-specific variables (use these in docker-compose.json):
| Variable | Description |
|----------|-------------|
| `${APP_DATA_DIR}` | Path to the app's data folder (e.g., `/root/.local/share/runtipi/statedirs/appstore/apps/<app-id>`) |
| `${ROOT_FOLDER_HOST}` | The root folder of the Runtipi installation |

#### Global variables (commonly used):
| Variable | Description |
|----------|-------------|
| `${TZ}` | Server timezone (e.g., `America/New_York`, `UTC`) |
| `${POSTGRES_HOST}`, `${POSTGRES_PASSWORD}`, etc. | Database connection (if app uses postgres) |
| `${REDIS_HOST}`, `${REDIS_PASSWORD}`, etc. | Redis connection (if app uses redis) |

#### Volume path patterns (from official runtipi-appstore):

**Config storage** — use `${APP_DATA_DIR}/data/config`:
```json
{"hostPath": "${APP_DATA_DIR}/data/config", "containerPath": "/config"}
```

**Media/data storage** — use `${ROOT_FOLDER_HOST}/media/data/...`:
```json
{"hostPath": "${ROOT_FOLDER_HOST}/media/data/audiobooks", "containerPath": "/audiobooks"}
{"hostPath": "${ROOT_FOLDER_HOST}/media/data/books", "containerPath": "/books"}
```

**Examples from official store:**
- Audiobookshelf: `${ROOT_FOLDER_HOST}/media/data/books/spoken` + `${APP_DATA_DIR}/data/config`
- Calibre-web: `${ROOT_FOLDER_HOST}/media/data/books` + `${APP_DATA_DIR}/data/config` + `${APP_DATA_DIR}/data/calibre`
- Actual-budget: `${APP_DATA_DIR}/data`

### Additional rules

- Exactly ONE service must have `"isMain": true`
- Use `"internalPort"` on the main service (the port the container listens on)
- Reference form_field env vars with `${VAR_NAME}` syntax in environment values
- For databases, use dedicated service containers (e.g., `postgres:17-alpine`, `redis:7-alpine`, `mariadb:11`)
- Internal service names should be prefixed with the app id (e.g., `myapp_db`, `myapp_redis`)
- Use `"dependsOn"` to order service startup
- Hard-code reasonable defaults for internal config (database names, usernames) — only expose user-facing config as form_fields
- Pin image versions — never use `latest` tag

---

## Step 5: Create metadata/description.md

Create at `/private/tmp/add-<app-id>/apps/<app-id>/metadata/description.md`

Write a markdown description with:
- What the app is and what problem it solves
- Key features as a bullet list
- Keep it concise (5-15 lines)

Reference `apps/dawarich/metadata/description.md` for style.

---

## Step 6: Download logo

Download the app's official logo/icon and save it as `/private/tmp/add-<app-id>/apps/<app-id>/metadata/logo.jpg`.

- Try the GitHub repo's avatar, social preview, or icon from the app's website
- If the source is PNG, convert to JPG: `sips -s format jpeg logo.png --out logo.jpg` (macOS)
- Target a square image, reasonable size (128x128 to 512x512)
- If you absolutely cannot find a logo, generate a simple placeholder

---

## Step 7: Run tests

```bash
cd /private/tmp/add-<app-id> && bun install && bun run test
```

Tests validate:
1. All 4 required files exist
2. `config.json` matches `appInfoSchema`
3. `docker-compose.json` matches `dynamicComposeSchema`

If tests fail, read the error output carefully. Fix the issues and re-run. Common problems:
- Missing required fields in config.json
- Invalid category name
- `schemaVersion` not set to `2`
- `internalPort` type mismatch (try both string and number)
- Invalid form_field type

---

## Step 8: Commit, push and create PR from worktree

Once tests pass, commit from the worktree:

**NOTE**: If git commands fail with "fatal: this operation must be run in a work tree", set explicit environment variables:

```bash
export GIT_DIR=/Users/cmolina/code/cmolina-runtipi-store.git/worktrees/add-<app-id>
export GIT_WORK_TREE=/private/tmp/add-<app-id>
```

Then run all subsequent git commands normally.

```bash
git add apps/<app-id>/
git commit --no-gpg-sign -m "Add <App Name> app - <short description>"
git push -u origin add-<app-id>

gh pr create --repo cmolina/cmolina-runtipi-store \
  --head add-<app-id> \
  --base main \
  --title "Add <App Name>" \
  --body "<description of the app and what it does>"

# Open PR in browser for review
open <PR_URL>
```

---

## Rules

- **NEVER** modify files outside `apps/<app-id>/`
- **NEVER** touch unrelated apps
- `app-id` must be lowercase kebab-case
- Always use explicit refspec when fetching (`+refs/heads/main:refs/remotes/origin/main`)
- Always use `origin/main` as the base for worktrees (never `FETCH_HEAD`)
- If git commands in the worktree fail with "must be run in a work tree", explicitly set `GIT_DIR` and `GIT_WORK_TREE` env vars (see Step 8 troubleshooting)
- Always run tests before shipping PR
- Never use `latest` as an image tag — always pin to exact version
- All 4 files required: `config.json`, `docker-compose.json`, `metadata/description.md`, `metadata/logo.jpg`
- Match categories to the official list: `network`, `media`, `development`, `automation`, `social`, `utilities`, `photography`, `security`, `featured`, `books`, `data`, `music`, `finance`, `gaming`, `ai`
- Reference existing apps (dawarich, whoami) for style and structure
