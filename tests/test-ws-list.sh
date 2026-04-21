#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST_SCRIPT="$SCRIPT_DIR/../scripts/ws-list.sh"
PASS=0
FAIL=0

assert_eq() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  ✓ $label"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $label"
    echo "    expected: [$expected]"
    echo "    actual:   [$actual]"
    FAIL=$((FAIL + 1))
  fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FAKE_BIN="$TMP/bin"
SKILL_DIR="$TMP/skill"
CACHE_DIR="$TMP/cache"
LOCAL_REPO="$CACHE_DIR/github/test-user_demo-repo"

mkdir -p "$FAKE_BIN" "$SKILL_DIR" "$LOCAL_REPO/local-only" "$LOCAL_REPO/shared"

cat > "$SKILL_DIR/config.json" <<EOF
{
  "backend": "github",
  "github": {
    "token": "ghp-test-token",
    "repo": "test-user/demo-repo",
    "branch": "main"
  },
  "cache_dir": "$CACHE_DIR"
}
EOF

cat > "$LOCAL_REPO/local-only/manifest.json" <<'EOF'
{
  "version": 1,
  "updated_at": "2026-04-01T10:00:00+08:00"
}
EOF

cat > "$LOCAL_REPO/shared/manifest.json" <<'EOF'
{
  "version": 2,
  "updated_at": "2026-04-02T10:00:00+08:00"
}
EOF

cat > "$FAKE_BIN/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

url="${@: -1}"

if [[ "$url" == *"/shared/manifest.json"* ]]; then
    cat <<'JSON'
{"version":5,"updated_at":"2026-04-21T09:30:00+08:00"}
JSON
elif [[ "$url" == *"/remote-only/manifest.json"* ]]; then
    cat <<'JSON'
{"version":3,"updated_at":"2026-04-20T11:45:00+08:00"}
JSON
elif [[ "$url" == *"/contents/"* && "$url" != *"/manifest.json"* ]]; then
    cat <<'JSON'
[
  {"type":"dir","name":"shared"},
  {"type":"dir","name":"remote-only"}
]
JSON
else
  exit 1
fi
EOF
chmod +x "$FAKE_BIN/curl"

export PATH="$FAKE_BIN:$PATH"
export WS_SKILL_DIR_OVERRIDE="$SKILL_DIR"

echo "=== test-ws-list.sh ==="

default_output="$(bash "$LIST_SCRIPT")"
assert_eq "default mode only reads local cache" \
  $'local-only|1|2026-04-01T10:00:00+08:00\nshared|2|2026-04-02T10:00:00+08:00' \
  "$default_output"

discover_output="$(bash "$LIST_SCRIPT" --discover)"
assert_eq "discover mode merges remote-only workspaces and refreshes shared metadata" \
  $'local-only|1|2026-04-01T10:00:00+08:00\nshared|5|2026-04-21T09:30:00+08:00\nremote-only|3|2026-04-20T11:45:00+08:00' \
  "$discover_output"

remote_output="$(bash "$LIST_SCRIPT" --remote)"
assert_eq "remote mode only returns lightweight remote data" \
  $'shared|5|2026-04-21T09:30:00+08:00\nremote-only|3|2026-04-20T11:45:00+08:00' \
  "$remote_output"

echo ""
echo "=== 结果: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
