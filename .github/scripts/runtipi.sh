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
