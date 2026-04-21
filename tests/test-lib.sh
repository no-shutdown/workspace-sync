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

ORIG_HOME="${HOME:-}"
ORIG_USERPROFILE="${USERPROFILE:-}"
ORIG_WS_HOME_OVERRIDE="${WS_HOME_OVERRIDE:-}"
ORIG_WS_SKILL_DIR_OVERRIDE="${WS_SKILL_DIR_OVERRIDE:-}"
ORIG_WS_STATE_DIR_NAME_OVERRIDE="${WS_STATE_DIR_NAME_OVERRIDE:-}"

restore_env() {
  export HOME="$ORIG_HOME"
  export USERPROFILE="$ORIG_USERPROFILE"
  export WS_HOME_OVERRIDE="$ORIG_WS_HOME_OVERRIDE"
  export WS_SKILL_DIR_OVERRIDE="$ORIG_WS_SKILL_DIR_OVERRIDE"
  export WS_STATE_DIR_NAME_OVERRIDE="$ORIG_WS_STATE_DIR_NAME_OVERRIDE"
}

trap 'restore_env; rm -rf "$TMP"' EXIT

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
  "cache_dir": "~/.claude/workspace-cache",
  "gitlab": {
    "host": "gitlab.example.com"
  }
}
EOF

assert_eq "read backend field" \
  "gitlab" \
  "$(ws_get_config_string "$CONFIG_FILE" "backend")"

assert_eq "read cache_dir field" \
  "~/.claude/workspace-cache" \
  "$(ws_get_config_string "$CONFIG_FILE" "cache_dir")"

assert_eq "read nested field via dotted path" \
  "gitlab.example.com" \
  "$(ws_get_json_string "$CONFIG_FILE" "gitlab.host")"

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

# --- ws_home_dir / ws_workspace_sync_config_path / ws_projects_dir ---
echo ""
echo "ws_home_dir / ws_workspace_sync_config_path / ws_projects_dir"

WIN_HOME="$TMP/win-home"
LINUX_HOME="$TMP/linux-home"
mkdir -p "$WIN_HOME/.claude/skills/workspace-sync" "$WIN_HOME/.claude/projects"
mkdir -p "$WIN_HOME/.codex/skills/workspace-sync" "$WIN_HOME/.codex/projects"
mkdir -p "$LINUX_HOME/.claude"
touch "$WIN_HOME/.claude/skills/workspace-sync/config.json"
touch "$WIN_HOME/.codex/skills/workspace-sync/config.json"

export USERPROFILE="$WIN_HOME"
export HOME="$LINUX_HOME"
unset WS_HOME_OVERRIDE
unset WS_SKILL_DIR_OVERRIDE
export WS_STATE_DIR_NAME_OVERRIDE=".codex"

assert_eq "prefer USERPROFILE-backed .claude over HOME" \
  "$WIN_HOME" \
  "$(ws_home_dir)"

assert_eq "default state root follows current CLI when detectable" \
  "$WIN_HOME/.codex" \
  "$(ws_default_state_root)"

assert_eq "resolve workspace-sync config from discovered home" \
  "$WIN_HOME/.codex/skills/workspace-sync/config.json" \
  "$(ws_workspace_sync_config_path)"

assert_eq "resolve projects dir from discovered state home" \
  "$WIN_HOME/.codex/projects" \
  "$(ws_projects_dir)"

SOURCE_SKILL="$TMP/source-skill"
mkdir -p "$SOURCE_SKILL/scripts"
touch "$SOURCE_SKILL/SKILL.md"

assert_eq "prefer script-adjacent skill dir for code lookup" \
  "$SOURCE_SKILL" \
  "$(ws_workspace_sync_dir "$SOURCE_SKILL/scripts")"

assert_eq "fall back to installed config when source tree has no config" \
  "$WIN_HOME/.codex/skills/workspace-sync/config.json" \
  "$(ws_workspace_sync_config_path "$SOURCE_SKILL/scripts")"

assert_eq "derive default local-paths next to config root" \
  "$WIN_HOME/.claude/skills/workspace-sync/local-paths.json" \
  "$(ws_default_workspace_sync_local_paths "$WIN_HOME/.claude/skills/workspace-sync/config.json")"

assert_eq "derive default cache dir next to config root" \
  "$WIN_HOME/.claude/workspace-cache" \
  "$(ws_default_workspace_cache_dir "$WIN_HOME/.claude/skills/workspace-sync/config.json")"

restore_env

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
