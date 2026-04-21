#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SCRIPT="$SCRIPT_DIR/../scripts/ws-config.sh"
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
SYNC_DIR="$TMP/home/synced-workspaces"

mkdir -p "$FAKE_BIN" "$SKILL_DIR" "$SYNC_DIR"
mkdir -p "$TMP/home/.codex"

cat > "$SKILL_DIR/config.json" <<'EOF'
{
  "backend": "gitlab",
  "gitlab": {
    "host": "gitlab.example.com",
    "token": "old-token",
    "project_path": "team/workspaces",
    "branch": "main"
  },
  "scan_roots": [
    "D:/work",
    "D:/src"
  ]
}
EOF

cat > "$FAKE_BIN/curl" <<'EOF'
#!/usr/bin/env bash
printf '200'
EOF
chmod +x "$FAKE_BIN/curl"

export PATH="$FAKE_BIN:$PATH"
export WS_SKILL_DIR_OVERRIDE="$SKILL_DIR"
echo "=== test-ws-config.sh ==="

bash "$CONFIG_SCRIPT" local --path "$SYNC_DIR" >/dev/null

local_backend="$(python3 -c "import json,sys; d=json.load(open(sys.argv[1], encoding='utf-8')); print(d['backend'])" "$SKILL_DIR/config.json")"
local_path="$(python3 -c "import json,sys; d=json.load(open(sys.argv[1], encoding='utf-8')); print((d.get('local') or {}).get('path',''))" "$SKILL_DIR/config.json")"
scan_roots="$(python3 -c "import json,sys; d=json.load(open(sys.argv[1], encoding='utf-8')); print(','.join(d.get('scan_roots') or []))" "$SKILL_DIR/config.json")"
gitlab_host="$(python3 -c "import json,sys; d=json.load(open(sys.argv[1], encoding='utf-8')); print((d.get('gitlab') or {}).get('host',''))" "$SKILL_DIR/config.json")"

assert_eq "local config switches backend" "local" "$local_backend"
assert_eq "local config stores the selected path" "$SYNC_DIR" "$local_path"
assert_eq "local config preserves unrelated fields" "D:/work,D:/src" "$scan_roots"
assert_eq "local config preserves previous backend section for later reuse" "gitlab.example.com" "$gitlab_host"

bash "$CONFIG_SCRIPT" github --token "ghp-new-token" --repo "demo/workspaces" --branch "dev" >/dev/null

github_backend="$(python3 -c "import json,sys; d=json.load(open(sys.argv[1], encoding='utf-8')); print(d['backend'])" "$SKILL_DIR/config.json")"
github_repo="$(python3 -c "import json,sys; d=json.load(open(sys.argv[1], encoding='utf-8')); print((d.get('github') or {}).get('repo',''))" "$SKILL_DIR/config.json")"
github_branch="$(python3 -c "import json,sys; d=json.load(open(sys.argv[1], encoding='utf-8')); print((d.get('github') or {}).get('branch',''))" "$SKILL_DIR/config.json")"
still_has_local="$(python3 -c "import json,sys; d=json.load(open(sys.argv[1], encoding='utf-8')); print((d.get('local') or {}).get('path',''))" "$SKILL_DIR/config.json")"

assert_eq "github config switches backend" "github" "$github_backend"
assert_eq "github config stores repo" "demo/workspaces" "$github_repo"
assert_eq "github config stores branch" "dev" "$github_branch"
assert_eq "github config preserves local section" "$SYNC_DIR" "$still_has_local"

echo ""
echo "=== 结果: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
