#!/usr/bin/env bash
# 测试 workspace-sync-lib.sh 的核心函数

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/../scripts/workspace-sync-lib.sh"
source "$LIB"

PASS=0
FAIL=0

assert_eq() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  ✓ $label"
    ((PASS++))
  else
    echo "  ✗ $label"
    echo "    expected: [$expected]"
    echo "    actual:   [$actual]"
    ((FAIL++))
  fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "=== test-lib.sh ==="

# --- ws_normalize_remote ---
echo ""
echo "ws_normalize_remote"

assert_eq "ssh with git@ and .git" \
  "gitlab.yc.com/ukon/shanks-manage" \
  "$(ws_normalize_remote 'git@gitlab.yc.com:ukon/shanks-manage.git')"

assert_eq "https with .git" \
  "gitlab.yc.com/ukon/shanks-manage" \
  "$(ws_normalize_remote 'https://gitlab.yc.com/ukon/shanks-manage.git')"

assert_eq "ssh:// scheme" \
  "gitlab.yc.com/ukon/shanks-manage" \
  "$(ws_normalize_remote 'ssh://git@gitlab.yc.com/ukon/shanks-manage.git')"

assert_eq "host uppercase normalized" \
  "github.com/user/repo" \
  "$(ws_normalize_remote 'https://GITHUB.COM/user/repo.git')"

assert_eq "no .git suffix" \
  "github.com/user/repo" \
  "$(ws_normalize_remote 'https://github.com/user/repo')"

assert_eq "empty input returns empty" \
  "" \
  "$(ws_normalize_remote '')"

# --- ws_get_config_string ---
echo ""
echo "ws_get_config_string"

CONFIG_FILE="$TMP/config.json"
cat > "$CONFIG_FILE" <<'EOF'
{
  "backend": "gitlab",
  "cache_dir": "~/.claude/workspace-cache"
}
EOF

assert_eq "read backend field" \
  "gitlab" \
  "$(ws_get_config_string "$CONFIG_FILE" "backend")"

assert_eq "read cache_dir field" \
  "~/.claude/workspace-cache" \
  "$(ws_get_config_string "$CONFIG_FILE" "cache_dir")"

assert_eq "missing key returns empty" \
  "" \
  "$(ws_get_config_string "$CONFIG_FILE" "nonexistent")"

assert_eq "nonexistent file returns empty" \
  "" \
  "$(ws_get_config_string "/nonexistent/config.json" "backend")"

# --- ws_json_escape ---
echo ""
echo "ws_json_escape"

assert_eq "backslash escaped" \
  'path\\to\\file' \
  "$(ws_json_escape 'path\to\file')"

assert_eq "double quote escaped" \
  'say \"hello\"' \
  "$(ws_json_escape 'say "hello"')"

assert_eq "normal string unchanged" \
  "hello-world_123" \
  "$(ws_json_escape 'hello-world_123')"

# --- ws_write_local_mapping / ws_get_local_mapping_path ---
echo ""
echo "ws_write_local_mapping / ws_get_local_mapping_path"

MAPPING_FILE="$TMP/local-paths.json"

ws_write_local_mapping "$MAPPING_FILE" "github.com/user/repo" "/local/path/repo" "repo"
assert_eq "write and read back mapping" \
  "/local/path/repo" \
  "$(ws_get_local_mapping_path "$MAPPING_FILE" "github.com/user/repo")"

assert_eq "unknown key returns empty" \
  "" \
  "$(ws_get_local_mapping_path "$MAPPING_FILE" "github.com/other/repo")"

ws_write_local_mapping "$MAPPING_FILE" "github.com/user/another" "/local/another" "another"
assert_eq "second mapping doesn't overwrite first" \
  "/local/path/repo" \
  "$(ws_get_local_mapping_path "$MAPPING_FILE" "github.com/user/repo")"

ws_remove_local_mapping "$MAPPING_FILE" "github.com/user/repo"
assert_eq "remove mapping works" \
  "" \
  "$(ws_get_local_mapping_path "$MAPPING_FILE" "github.com/user/repo")"

assert_eq "other mapping survives remove" \
  "/local/another" \
  "$(ws_get_local_mapping_path "$MAPPING_FILE" "github.com/user/another")"

# --- 结果汇总 ---
echo ""
echo "=== 结果: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
