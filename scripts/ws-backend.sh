#!/usr/bin/env bash
# 公共 backend 工具函数，供 ws-*.sh 脚本 source 使用
# 使用方式:
#   source "$(dirname "${BASH_SOURCE[0]}")/ws-backend.sh"
#   ws_backend_init          # 设置 WS_BACKEND WS_CACHE_DIR WS_CONFIG WS_SKILL_DIR
#   ws_ensure_github         # 设置 WS_GITHUB_* 变量，确保本地 repo 存在
#   ws_ensure_gitlab         # 设置 WS_GITLAB_* 变量，确保本地 repo 存在

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./workspace-sync-lib.sh
source "$SCRIPT_DIR/workspace-sync-lib.sh"

ws_backend_init() {
  WS_SKILL_DIR="$(ws_home_dir)/.claude/skills/workspace-sync"
  WS_CONFIG="$WS_SKILL_DIR/config.json"
  [[ -f "$WS_CONFIG" ]] || { echo '{"error":"config not found"}'; exit 1; }

  WS_BACKEND="$(ws_get_json_string "$WS_CONFIG" "backend")"
  [[ -n "$WS_BACKEND" ]] || { echo '{"error":"backend not configured, run /workspace-sync connect first"}'; exit 1; }

  WS_CACHE_DIR="$(ws_get_json_string "$WS_CONFIG" "cache_dir")"
  [[ -n "$WS_CACHE_DIR" ]] || WS_CACHE_DIR="~/.claude/workspace-cache"
  WS_CACHE_DIR="$(ws_expand_home "$WS_CACHE_DIR")"
  mkdir -p "$WS_CACHE_DIR"
}

# clone（不存在时）或 pull（已存在时）一个 git 缓存 repo
# 用法: _ws_ensure_repo <local_repo> <clone_url> [no_proxy_host]
_ws_ensure_repo() {
  local local_repo="$1" clone_url="$2" no_proxy_host="${3:-}"
  if [[ ! -d "$local_repo/.git" ]]; then
    mkdir -p "$(dirname "$local_repo")"
    if [[ -n "$no_proxy_host" ]]; then
      no_proxy="$no_proxy_host" git clone "$clone_url" "$local_repo" 2>/dev/null \
        || { echo '{"error":"git clone failed"}'; exit 1; }
    else
      git clone "$clone_url" "$local_repo" 2>/dev/null \
        || { echo '{"error":"git clone failed"}'; exit 1; }
    fi
  else
    if [[ -n "$no_proxy_host" ]]; then
      (cd "$local_repo" && no_proxy="$no_proxy_host" git pull --ff-only 2>/dev/null) || true
    else
      (cd "$local_repo" && git pull --ff-only 2>/dev/null) || true
    fi
  fi
}

# 初始化 GitHub 后端，设置 WS_GITHUB_* 变量，确保本地 repo 存在并切换到目标分支
ws_ensure_github() {
  WS_GITHUB_TOKEN="$(ws_get_json_string "$WS_CONFIG" "github.token")"
  WS_GITHUB_REPO="$(ws_get_json_string "$WS_CONFIG" "github.repo")"
  WS_GITHUB_BRANCH="$(ws_get_json_string "$WS_CONFIG" "github.branch")"
  [[ -n "$WS_GITHUB_BRANCH" ]] || WS_GITHUB_BRANCH="main"
  [[ -n "$WS_GITHUB_TOKEN" && -n "$WS_GITHUB_REPO" ]] \
    || { echo '{"error":"github token/repo not configured"}'; exit 1; }

  WS_GITHUB_LOCAL_REPO="$WS_CACHE_DIR/github/$(echo "$WS_GITHUB_REPO" | sed 's|/|_|g')"
  _ws_ensure_repo "$WS_GITHUB_LOCAL_REPO" "https://${WS_GITHUB_TOKEN}@github.com/${WS_GITHUB_REPO}.git"
  (cd "$WS_GITHUB_LOCAL_REPO" && git checkout "$WS_GITHUB_BRANCH" 2>/dev/null || true)
}

# 初始化 GitLab 后端，设置 WS_GITLAB_* 变量，确保本地 repo 存在并切换到目标分支
ws_ensure_gitlab() {
  WS_GITLAB_HOST="$(ws_get_json_string "$WS_CONFIG" "gitlab.host")"
  WS_GITLAB_TOKEN="$(ws_get_json_string "$WS_CONFIG" "gitlab.token")"
  WS_GITLAB_PROJECT="$(ws_get_json_string "$WS_CONFIG" "gitlab.project_path")"
  WS_GITLAB_BRANCH="$(ws_get_json_string "$WS_CONFIG" "gitlab.branch")"
  [[ -n "$WS_GITLAB_BRANCH" ]] || WS_GITLAB_BRANCH="main"
  [[ -n "$WS_GITLAB_HOST" && -n "$WS_GITLAB_TOKEN" && -n "$WS_GITLAB_PROJECT" ]] \
    || { echo '{"error":"gitlab host/token/project_path not configured"}'; exit 1; }

  WS_GITLAB_LOCAL_REPO="$WS_CACHE_DIR/gitlab/$(echo "$WS_GITLAB_PROJECT" | sed 's|/|_|g')"
  _ws_ensure_repo "$WS_GITLAB_LOCAL_REPO" \
    "https://oauth2:${WS_GITLAB_TOKEN}@${WS_GITLAB_HOST}/${WS_GITLAB_PROJECT}.git" \
    "$WS_GITLAB_HOST"
  (cd "$WS_GITLAB_LOCAL_REPO" && git checkout "$WS_GITLAB_BRANCH" 2>/dev/null || true)
}

# 计算 GitLab 本地缓存路径，不执行 clone/pull（用于 list / version-check）
ws_compute_gitlab_path() {
  WS_GITLAB_HOST="$(ws_get_json_string "$WS_CONFIG" "gitlab.host")"
  WS_GITLAB_TOKEN="$(ws_get_json_string "$WS_CONFIG" "gitlab.token")"
  WS_GITLAB_PROJECT="$(ws_get_json_string "$WS_CONFIG" "gitlab.project_path")"
  WS_GITLAB_BRANCH="$(ws_get_json_string "$WS_CONFIG" "gitlab.branch")"
  WS_GITLAB_PROTOCOL="$(ws_get_json_string "$WS_CONFIG" "gitlab.protocol")"
  [[ -n "$WS_GITLAB_BRANCH" ]] || WS_GITLAB_BRANCH="main"
  [[ -n "$WS_GITLAB_PROTOCOL" ]] || WS_GITLAB_PROTOCOL="https"
  WS_GITLAB_LOCAL_REPO="$WS_CACHE_DIR/gitlab/$(echo "$WS_GITLAB_PROJECT" | sed 's|/|_|g')"
}

# 计算 GitHub 本地缓存路径，不执行 clone/pull（用于 list / version-check）
ws_compute_github_path() {
  WS_GITHUB_TOKEN="$(ws_get_json_string "$WS_CONFIG" "github.token")"
  WS_GITHUB_REPO="$(ws_get_json_string "$WS_CONFIG" "github.repo")"
  WS_GITHUB_BRANCH="$(ws_get_json_string "$WS_CONFIG" "github.branch")"
  [[ -n "$WS_GITHUB_BRANCH" ]] || WS_GITHUB_BRANCH="main"
  WS_GITHUB_LOCAL_REPO="$WS_CACHE_DIR/github/$(echo "$WS_GITHUB_REPO" | sed 's|/|_|g')"
}

# 通过 GitLab API 获取单个 workspace 的 manifest.json 内容（轻量，无 git pull）
# 调用前需已执行 ws_compute_gitlab_path
ws_gitlab_fetch_manifest() {
  local ws_name="$1"
  local encoded_project encoded_file
  encoded_project="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$WS_GITLAB_PROJECT")"
  encoded_file="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]+'/manifest.json', safe=''))" "$ws_name")"
  no_proxy="$WS_GITLAB_HOST" curl -sf \
    -H "PRIVATE-TOKEN: $WS_GITLAB_TOKEN" \
    "${WS_GITLAB_PROTOCOL}://${WS_GITLAB_HOST}/api/v4/projects/${encoded_project}/repository/files/${encoded_file}/raw?ref=${WS_GITLAB_BRANCH}" \
    2>/dev/null || true
}

# 通过 GitLab API 列出所有 workspace 目录名（每行一个，无 git pull）
# 调用前需已执行 ws_compute_gitlab_path
ws_gitlab_list_remote() {
  local encoded_project
  encoded_project="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$WS_GITLAB_PROJECT")"
  no_proxy="$WS_GITLAB_HOST" curl -sf \
    -H "PRIVATE-TOKEN: $WS_GITLAB_TOKEN" \
    "${WS_GITLAB_PROTOCOL}://${WS_GITLAB_HOST}/api/v4/projects/${encoded_project}/repository/tree?ref=${WS_GITLAB_BRANCH}&per_page=100" \
    2>/dev/null \
  | python3 -c "
import json, sys
try:
    items = json.load(sys.stdin)
    for item in items:
        if isinstance(item, dict) and item.get('type') == 'tree' and not item.get('name','').startswith('.'):
            print(item['name'])
except Exception:
    pass
" || true
}

# 通过 GitHub API 获取单个 workspace 的 manifest.json 内容（接受 raw 格式）
# 调用前需已执行 ws_compute_github_path
ws_github_fetch_manifest() {
  local ws_name="$1"
  curl -sf \
    -H "Authorization: Bearer $WS_GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.raw" \
    "https://api.github.com/repos/${WS_GITHUB_REPO}/contents/${ws_name}/manifest.json?ref=${WS_GITHUB_BRANCH}" \
    2>/dev/null || true
}

# 通过 GitHub API 列出所有 workspace 目录名（每行一个）
# 调用前需已执行 ws_compute_github_path
ws_github_list_remote() {
  curl -sf \
    -H "Authorization: Bearer $WS_GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${WS_GITHUB_REPO}/contents/?ref=${WS_GITHUB_BRANCH}" \
    2>/dev/null \
  | python3 -c "
import json, sys
try:
    items = json.load(sys.stdin)
    for item in items:
        if isinstance(item, dict) and item.get('type') == 'dir' and not item.get('name','').startswith('.'):
            print(item['name'])
except Exception:
    pass
" || true
}

# 初始化 MinIO 后端，设置 WS_MC_* 变量，检查 mc 命令存在
ws_init_minio() {
  WS_MC_ALIAS="$(ws_get_json_string "$WS_CONFIG" "minio.mc_alias")"
  [[ -n "$WS_MC_ALIAS" ]] || WS_MC_ALIAS="workspace-sync"
  WS_MC_BUCKET="$(ws_get_json_string "$WS_CONFIG" "minio.bucket")"
  WS_MC_PREFIX="$(ws_get_json_string "$WS_CONFIG" "minio.prefix")"
  [[ -n "$WS_MC_PREFIX" ]] || WS_MC_PREFIX="workspaces/"
  [[ -n "$WS_MC_BUCKET" ]] || { echo '{"error":"minio bucket not configured"}'; exit 1; }
  command -v mc &>/dev/null || { echo '{"error":"mc not installed"}'; exit 1; }
  WS_MC_BASE="${WS_MC_ALIAS}/${WS_MC_BUCKET}/${WS_MC_PREFIX}"
}

# 读取本地目录路径，设置 WS_LOCAL_PATH
ws_init_local() {
  WS_LOCAL_PATH="$(ws_get_json_string "$WS_CONFIG" "local.path")"
  WS_LOCAL_PATH="$(ws_expand_home "$WS_LOCAL_PATH")"
  [[ -d "$WS_LOCAL_PATH" ]] || { echo "{\"error\": \"local.path not found: $WS_LOCAL_PATH\"}"; exit 1; }
}
