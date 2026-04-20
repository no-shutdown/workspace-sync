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
