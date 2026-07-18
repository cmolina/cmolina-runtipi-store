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

1. Research the app extensively (GitHub repo, project self-host docs, Docker image, ports, env vars, dependencies, security recommendations)
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
2. **Project documentation** — look for a self-host / Docker deployment guide on the project's website (e.g., `docs.project.dev/advanced/self_host`, `docs.project.dev/deploy/docker`). Search for "self-host windmill", "deploy X with docker" patterns. The project's docker-compose.yml and Caddyfile/traefik config are authoritative sources for:
   - **Architecture** — how many services does the official setup use? (server vs worker split, dedicated workers for different job types, sidecars like LSP/indexer)
   - **Security recommendations** — does the project recommend privileged mode, isolation flags (PID namespaces, nsjail), specific capabilities, or security env vars?
   - **Health checks** — what endpoint does the project use for health checks? (e.g., `/api/health` vs `/health`, `pg_isready` format)
   - **Ports** — does the server expose additional ports beyond the main web UI? (e.g., SMTP/email ports, metrics ports)
   - **Optional services** — are there optional but recommended services (LSP for editor intellisense, multi-player, search indexer)? Add them as non-main services.
   - **Volume paths and mounts** — what directories does the project recommend mounting?
   - **Logging configuration** — does the upstream compose define custom log drivers/options?
4. **Docker image** — find the official Docker image name on Docker Hub or GitHub Container Registry. Get the **latest stable version tag** (not `latest`).
   - **⚠️ CRITICAL**: The Docker image tag and the GitHub release tag can differ. Many projects tag GitHub releases with a `v` prefix (e.g., `v1.2.3`) but publish Docker images without it (e.g., `1.2.3`). **Always verify the actual Docker image tag exists** before using it — try `docker pull` or check the registry API. `config.json` `version` uses the GitHub release tag (with `v` if that's how the project releases). `docker-compose.json` `image` uses whatever tag the Docker registry actually has (without `v` if that's what was published).
5. **Default port** — what port the app listens on inside the container
6. **Environment variables** — ALL of them. Classify each as:
   - Required (app won't start without it)
   - Optional (has sensible defaults)
   - Generated (secrets, passwords, keys - use `"type": "random"`)
7. **Dependencies** — does it need a database (postgres, mysql, mariadb), cache (redis, valkey), or other services?
8. **Description** — what the app does, key features, what it replaces
9. **Categories** — pick from: `network`, `media`, `development`, `automation`, `social`, `utilities`, `photography`, `security`, `featured`, `books`, `data`, `music`, `finance`, `gaming`, `ai`
10. **Supported architectures** — typically `["arm64", "amd64"]`, verify from Docker Hub
11. **Logo** — find a URL to the app's logo/icon (PNG or JPG)

### Searching GitHub source code

When you need to look up runtipi internals (e.g. available built-in env vars, schema fields), use the `mcp__github__search_code` MCP tool — load it with ToolSearch first:

```
ToolSearch("select:mcp__github__search_code")
mcp__github__search_code({ query: "APP_PROTOCOL repo:runtipi/runtipi" })
```

> **Note:** `mcp__github__get_file_contents` is restricted to this store's repo only. For runtipi source files use `mcp__github__search_code` to get the relevant fragments directly from search result snippets.

---

## Step 2: Create a git worktree from latest origin/main

This is a bare git repo. All work must happen in a worktree checked out from `origin/main`.

First, resolve the bare repo path (works regardless of where the repo was cloned):

```bash
REPO_DIR=$(git rev-parse --absolute-git-dir)
```

**NEVER run `git status` or `git diff` with `-C` on the bare repo** — those require a work tree and will fail with `fatal: this operation must be run in a work tree`.

```bash
# Fetch main with explicit refspec to create proper origin/main reference
git -C $REPO_DIR fetch origin +refs/heads/main:refs/remotes/origin/main

# Remove any stale worktree
git -C $REPO_DIR worktree remove --force $REPO_DIR/add-<app-id> 2>/dev/null || true
rm -rf $REPO_DIR/add-<app-id>
git -C $REPO_DIR worktree prune

# Create worktree from origin/main on a new branch
git -C $REPO_DIR worktree add $REPO_DIR/add-<app-id> -b add-<app-id> origin/main

# Now create the app directory inside the worktree
mkdir -p $REPO_DIR/add-<app-id>/apps/<app-id>/metadata
```

The `<app-id>` must be lowercase kebab-case (e.g., `my-app`).

**All subsequent file creation/editing must use paths inside `$REPO_DIR/add-<app-id>/apps/<app-id>/`**

---

## Step 3: Create config.json

Create at `$REPO_DIR/add-<app-id>/apps/<app-id>/config.json`

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

Create at `$REPO_DIR/add-<app-id>/apps/<app-id>/docker-compose.json`

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
| `${APP_PROTOCOL}` | `http` when not exposed, `https` when exposed via reverse proxy |
| `${APP_DOMAIN}` | `<internalIp>:<port>` when not exposed; `<subdomain>.<localDomain>` or custom domain when exposed |
| `${APP_HOST}` | Same as APP_DOMAIN |
| `${APP_PORT}` | The host port mapped to the app |
| `${APP_LOCAL_DOMAIN}` | The local subdomain (e.g. `airtrail.local.domain`) |
| `${APP_EXPOSED_DOMAIN}` | The custom external domain when the app is exposed with one |
| `${APP_EXPOSED}` | `"true"` when the app is exposed, unset otherwise |

#### For apps that need their public URL (e.g. ORIGIN, BASE_URL, PUBLIC_URL):

**Always use `${APP_PROTOCOL}://${APP_DOMAIN}`** — this auto-adapts to all cases:
- Not exposed: `http://192.168.1.x:3000`
- Exposed (local subdomain): `https://airtrail.local.domain`
- Exposed (custom domain): `https://airtrail.example.com`

Never hard-code `http://` or make this a form_field — runtipi sets these vars automatically.

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

### Apply project docs recommendations to docker-compose.json

The research from Step 1 (item 2 — project documentation) **must** shape the service architecture:

#### Service splitting
- If the project's docker-compose has separate services for different modes (e.g., `windmill_server` + `windmill_worker` + `windmill_worker_native`), **follow that split**. Each service gets its own entry in the runtipi services array.
- Only mark the publicly-exposed web service as `"isMain": true`. Backend workers and sidecars get `"isMain": false`.
- If the project recommends service replicas for scale, apply that via `deploy.resources` limits and note it — runtipi handles replicas differently.

#### Security and isolation
- Check the upstream compose for `privileged: true`, security-related env vars (`FAVOR_UNSHARE_PID`, `ENABLE_UNSHARE_PID`, `DISABLE_NSJAIL`), or capability requirements.
- If the project recommends isolation (PID namespaces, nsjail), add `"privileged": true` to the relevant worker services and include the required env vars.
- Add boolean `form_fields` for isolation settings the user might want to toggle (e.g., enable/disable nsjail, enable/disable PID isolation).

#### Optional but recommended services
- If the project includes optional services for better UX (LSP, search indexer, multi-player), add them as `"isMain": false` services.
- Give them reasonable resource limits.

#### Volume paths and mounts
- Match the project's container paths exactly (e.g., `/tmp/windmill/cache`, `/tmp/windmill/logs`, `/pyls/.cache`).
- Map those to `${APP_DATA_DIR}/data/...` host paths.

#### Ports
- If the upstream compose exposes additional ports beyond the main web port (e.g., port 2525 for email triggers, port 8002 for metrics), add `"exposePort"` on the main service.

#### Health checks
- Use the health check command from the project's official compose file as a **starting point**, but **you must verify the endpoint actually works** before shipping.
- **⚠️ Critical: Upstream healthcheck endpoints can be wrong.** The Windmill project's own compose uses `GET /api/health` which returns 404 — the correct endpoint is `/api/health/status`. Always verify by running the container locally and testing the endpoint.
- **How to verify**: After writing the docker-compose.json, run the app on your local Runtipi instance (or via `docker compose up`). Check `docker inspect <container> --format '{{json .State.Health}}'` and confirm it shows `"Status": "healthy"`. If it's `unhealthy`, fix the `test` command before shipping.
- **Traefik v3 filters unhealthy containers**: Runtipi uses Traefik v3 as its reverse proxy. Traefik **skips containers marked `unhealthy`** by Docker — no router or service is created for them. This means the app will be unreachable via its domain even though the container is running and serving HTTP. A broken healthcheck = a broken domain route.
- **Check project docs, not just the compose file**: The project's self-host documentation may document a different (correct) health endpoint than what's in the compose file. Cross-reference both sources. If they disagree, **verify by testing**.
- **Common patterns**: Many projects expose health at `/health`, `/api/health/status`, `/api/health`, or `/status`. Some use `pg_isready` for database services. Always confirm the endpoint returns HTTP 200.

#### Logging
- If the upstream compose configures custom logging (max-size, max-file, compress), replicate it in the runtipi service.

### Additional rules

- Exactly ONE service must have `"isMain": true`
- Use `"internalPort"` on the main service (the port the container listens on)
- Reference form_field env vars with `${VAR_NAME}` syntax in environment values
- For databases, use dedicated service containers (e.g., `postgres:17-alpine`, `redis:7-alpine`, `mariadb:11`)
- Internal service names should be prefixed with the app id (e.g., `myapp_db`, `myapp_redis`)
- Use `"dependsOn"` to order service startup
- Hard-code reasonable defaults for internal config (database names, usernames) — only expose user-facing config as form_fields
- Pin image versions — never use `latest` tag

### ⚠️ CRITICAL: Version naming — GitHub release tag vs Docker image tag

These two are **NOT always the same**. You must verify each independently:

| Field | File | Uses | Example |
|-------|------|------|---------|
| `version` | `config.json` | **GitHub release tag** (whatever the project publishes on GitHub Releases) | `v1.753.0`, `1.6.0` |
| `image` tag | `docker-compose.json` | **Actual Docker image tag** (whatever the registry has) | `1.753.0`, `1.6.0` |

**Common mismatch:** Many projects tag GitHub releases as `v1.2.3` but publish Docker images as just `1.2.3`.

**Always verify the Docker image tag before using it:**

```bash
# For Docker Hub images:
docker pull author/image:1.2.3

# For GHCR images:
docker pull ghcr.io/author/image:1.2.3
docker pull ghcr.io/author/image:v1.2.3  # try both with and without v
```

Use the tag that actually resolves. If the GitHub release is `v1.2.3` and `docker pull` succeeds with `1.2.3` but fails with `v1.2.3`, use `1.2.3` in the docker-compose.json image field. The `version` field in config.json keeps the GitHub release tag as-is (e.g., `v1.2.3`).

---

## Step 5: Create metadata/description.md

Create at `$REPO_DIR/add-<app-id>/apps/<app-id>/metadata/description.md`

Write a markdown description with:
- What the app is and what problem it solves
- Key features as a bullet list
- Keep it concise (5-15 lines)

Reference `apps/dawarich/metadata/description.md` for style.

---

## Step 6: Download logo

Download the app's official logo/icon and save it as `$REPO_DIR/add-<app-id>/apps/<app-id>/metadata/logo.jpg`.

- Try the GitHub repo's avatar, social preview, or icon from the app's website
- If the source is PNG, convert to JPG with `bunx sharp-cli --input logo.png --output logo.jpg` (works on Linux and macOS)
- Target a square image, reasonable size (128x128 to 512x512)
- If you absolutely cannot find a logo, generate a simple placeholder

---

## Step 7: Run tests

```bash
cd $REPO_DIR/add-<app-id> && bun install && bun run test
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
export GIT_DIR=$REPO_DIR/worktrees/add-<app-id>
export GIT_WORK_TREE=$REPO_DIR/add-<app-id>
```

Then run all subsequent git commands normally.

```bash
git add apps/<app-id>/
git commit --no-gpg-sign -m "Add <App Name> app - <short description>"
git push -u origin add-<app-id>
```

Then create the PR using the GitHub MCP tool (load it first via ToolSearch):

```
ToolSearch("select:mcp__github__create_pull_request")
mcp__github__create_pull_request({
  owner: "<repo-owner>",
  repo: "<repo-name>",
  title: "Add <App Name>",
  head: "add-<app-id>",
  base: "main",
  body: "..."
})
```

> **Do not use `gh pr create`** — the `gh` CLI is not available in remote sessions. Always use the MCP tool.

---

## Rules

- **NEVER** modify files outside `apps/<app-id>/`
- **NEVER** touch unrelated apps
- **ALWAYS** consult the project's official self-host / Docker documentation before designing docker-compose.json — the upstream compose file and docs are authoritative over any assumptions about service architecture, security settings, ports, health checks, volumes, and optional services
- `app-id` must be lowercase kebab-case
- Always use explicit refspec when fetching (`+refs/heads/main:refs/remotes/origin/main`)
- Always use `origin/main` as the base for worktrees (never `FETCH_HEAD`)
- If git commands in the worktree fail with "must be run in a work tree", explicitly set `GIT_DIR` and `GIT_WORK_TREE` env vars (see Step 8 troubleshooting)
- Always run tests before shipping PR
- Never use `latest` as an image tag — always pin to exact version
- **Docker image tag must be verified** — always check the actual Docker registry tag resolves before using it. The GitHub release tag (`v1.2.3`) and Docker image tag (`1.2.3`) can differ.
- All 4 files required: `config.json`, `docker-compose.json`, `metadata/description.md`, `metadata/logo.jpg`
- Match categories to the official list: `network`, `media`, `development`, `automation`, `social`, `utilities`, `photography`, `security`, `featured`, `books`, `data`, `music`, `finance`, `gaming`, `ai`
- Reference existing apps (dawarich, whoami) for style and structure
