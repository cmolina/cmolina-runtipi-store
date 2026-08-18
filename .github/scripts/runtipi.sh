# Shell functions for interacting with the runtipi API.
# Source this file: source /path/to/runtipi.sh

runtipi() {
  local method="$1" path="$2"
  shift 2
  local tmp body
  tmp=$(mktemp)
  RUNTIPI_HTTP_CODE=$(curl -sS -L \
    -b /tmp/jar -c /tmp/jar \
    -H "CF-Access-Client-Id: $CF_CLIENT_ID" \
    -H "CF-Access-Client-Secret: $CF_CLIENT_SECRET" \
    -H "Content-Type: application/json" \
    -H "Origin: $RUNTIPI_URL" \
    -X "$method" \
    "$@" \
    -o "$tmp" -w "%{http_code}" \
    "$RUNTIPI_URL$path")
  body=$(cat "$tmp"); rm -f "$tmp"
  echo "[$method $path] HTTP $RUNTIPI_HTTP_CODE $body" >&2
  echo "$body"
}

wait_for_app_status() {
  local urn="$1" target="$2" timeout="${3:-300}"
  local elapsed=0 delay=1 status
  while [ "$elapsed" -lt "$timeout" ]; do
    status=$(runtipi GET /api/apps/$urn 2>/dev/null | jq -r '.app.status // "missing"' 2>/dev/null)
    echo "[wait] $urn status=$status (target=$target, ${elapsed}s elapsed)" >&2
    [ "$status" = "$target" ] && return 0
    sleep "$delay"
    elapsed=$((elapsed + delay))
    delay=$((delay * 2))
    [ "$delay" -gt 30 ] && delay=30
  done
  echo "[wait] $urn timed out after ${elapsed}s, last status=$status" >&2
  return 1
}

# Waits past installing/starting/stopping so installs stay serial on runtipi's shared 3-worker app-events queue. Returns: 0=running, 1=stopped/missing, 2=timeout
wait_for_app_terminal() {
  local urn="$1" timeout="${2:-600}" terminal_drain="${3:-300}"
  local elapsed=0 delay=1 status
  while [ "$elapsed" -lt "$timeout" ]; do
    status=$(runtipi GET /api/apps/$urn 2>/dev/null | jq -r '.app.status // "missing"' 2>/dev/null)
    echo "[wait] $urn status=$status (target=running|stopped, ${elapsed}s elapsed)" >&2
    case "$status" in
      running) return 0 ;;
      stopped) return 1 ;;
      missing) return 1 ;;
    esac
    sleep "$delay"
    elapsed=$((elapsed + delay))
    delay=$((delay * 2))
    [ "$delay" -gt 30 ] && delay=30
  done
  # Bounded drain window: don't start the next install while this one still occupies a queue worker.
  echo "[wait] $urn still '${status}' after ${timeout}s, draining up to ${terminal_drain}s for a terminal state..." >&2
  elapsed=0
  delay=1
  while [ "$elapsed" -lt "$terminal_drain" ]; do
    status=$(runtipi GET /api/apps/$urn 2>/dev/null | jq -r '.app.status // "missing"' 2>/dev/null)
    echo "[wait] $urn status=$status (drain, ${elapsed}s elapsed)" >&2
    case "$status" in
      running) return 0 ;;
      stopped|missing) return 1 ;;
    esac
    sleep "$delay"
    elapsed=$((elapsed + delay))
    delay=$((delay * 2))
    [ "$delay" -gt 30 ] && delay=30
  done
  echo "[wait] $urn never reached a terminal state after ${timeout}s + ${terminal_drain}s drain" >&2
  return 2
}

installed_urns() {
  runtipi GET /api/apps/installed 2>/dev/null | jq -r '.installed[].info.urn // empty' 2>/dev/null
}

dump_app_logs() {
  local urn="$1" max_lines="${2:-200}"
  echo "===== container logs for $urn ====="
  curl -sN --max-time 15 \
    -b /tmp/jar -c /tmp/jar \
    -H "CF-Access-Client-Id: $CF_CLIENT_ID" \
    -H "CF-Access-Client-Secret: $CF_CLIENT_SECRET" \
    "$RUNTIPI_URL/api/sse/app-logs?appUrn=${urn}&maxLines=${max_lines}" \
    | sed -n 's/^data: //p' \
    | jq -r 'select(.event == "newLogs") | .lines[]?' \
    | sed 's/<[^>]*>//g' \
    || true
}

# Docker status "running" does not mean the app serves HTTP, so verify the
# public preview returns 2xx (adapting through any 3xx redirect) before success.
wait_for_http_2xx() {
  local url="$1" timeout="${2:-300}" elapsed=0 delay=1 code
  while [ "$elapsed" -lt "$timeout" ]; do
    code=$(curl -s -o /dev/null -L --max-time 10 -w '%{http_code}' "$url" 2>/dev/null || echo 000)
    echo "[http] $url -> HTTP $code (${elapsed}s elapsed)" >&2
    case "$code" in
      2*) return 0 ;;
    esac
    sleep "$delay"
    elapsed=$((elapsed + delay))
    delay=$((delay * 2))
    [ "$delay" -gt 30 ] && delay=30
  done
  echo "[http] $url never returned 2xx after ${timeout}s, last=$code" >&2
  return 1
}
