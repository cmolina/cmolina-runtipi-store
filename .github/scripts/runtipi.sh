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
  local urn="$1" target="$2" timeout="${3:-120}"
  local elapsed=0
  local status
  while [ "$elapsed" -lt "$timeout" ]; do
    status=$(runtipi GET /api/apps/$urn 2>/dev/null | jq -r '.app.status // "missing"' 2>/dev/null)
    echo "[wait] $urn status=$status (target=$target, ${elapsed}s elapsed)" >&2
    [ "$status" = "$target" ] && return 0
    sleep 5
    elapsed=$((elapsed + 5))
  done
  echo "[wait] $urn timed out after ${elapsed}s, last status=$status" >&2
  return 1
}
