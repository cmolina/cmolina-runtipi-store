---
description: Add a self-hosted app to this runtipi store
argument-hint: <app-name>
---

[search-mode]
MAXIMIZE SEARCH EFFORT. Launch multiple background agents IN PARALLEL:
- explore agents (codebase patterns, file structures)
- librarian agents (remote repos, official docs, Docker Hub, GitHub)
NEVER stop at first result - be exhaustive.

Add the self-hosted application **$ARGUMENTS** to this runtipi app store.

## Context

This is a custom runtipi app store repo. Apps live under `apps/<app-id>/`. Each app requires exactly 4 files:

```
apps/<app-id>/
  config.json
  docker-compose.json
  metadata/
    description.md
    logo.jpg
```

Validation uses `@runtipi/common` schemas (`appInfoSchema`, `dynamicComposeSchema`) via `bun test`.

## Step 1: Research the app

Search extensively for **$ARGUMENTS** to gather:

1. **GitHub repository** - find the official repo, read the README, docker-compose examples, and `.env.example` or environment variable docs
2. **Docker image** - find the official Docker image name on Docker Hub or GitHub Container Registry. Get the **latest stable version tag** (not `latest`)
3. **Default port** - what port the app listens on inside the container
4. **Environment variables** - ALL of them. Classify each as:
   - Required (app won't start without it)
   - Optional (has sensible defaults)
   - Generated (secrets, passwords, keys - use `"type": "random"`)
5. **Dependencies** - does it need a database (postgres, mysql, mariadb), cache (redis, valkey), or other services?
6. **Description** - what the app does, key features, what it replaces
7. **Categories** - pick from: `network`, `media`, `development`, `automation`, `social`, `utilities`, `photography`, `security`, `featured`, `books`, `data`, `music`, `finance`, `gaming`, `ai`
8. **Supported architectures** - typically `["arm64", "amd64"]`, verify from Docker Hub
9. **Logo** - find a URL to the app's logo/icon (PNG or JPG)

Use librarian agents to search GitHub, Docker Hub, and the app's official docs IN PARALLEL.

## Step 2: Create the app directory

```bash
mkdir -p apps/<app-id>/metadata
```

The `<app-id>` must be lowercase kebab-case (e.g., `my-app`).

## Step 3: Create config.json

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

## Step 4: Create docker-compose.json

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

## Step 5: Create metadata/description.md

Write a markdown description with:
- What the app is and what problem it solves
- Key features as a bullet list
- Keep it concise (5-15 lines)

Reference `apps/dawarich/metadata/description.md` for style.

## Step 6: Download logo

Download the app's official logo/icon and save it as `apps/<app-id>/metadata/logo.jpg`.

- Try the GitHub repo's avatar, social preview, or icon from the app's website
- If the source is PNG, convert to JPG: `sips -s format jpeg logo.png --out logo.jpg` (macOS)
- Target a square image, reasonable size (128x128 to 512x512)
- If you absolutely cannot find a logo, generate a simple placeholder

## Step 7: Run tests

```bash
bun install && bun run test
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

## Step 8: Create PR and open in browser

Once tests pass:

1. Create a new branch: `git checkout -b <app-id>`
2. Stage all new files: `git add apps/<app-id>/`
3. Commit: `git commit -m "Add <App Name> app - <short description>"`
4. Push: `git push -u origin HEAD`
5. Create PR: `gh pr create --title "Add <App Name>" --body "<description of the app and what it does>"`
6. Open in browser: `open <PR_URL>`
