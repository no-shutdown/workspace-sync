#!/usr/bin/env bash
# 公共 backend 工具函数，供 ws-*.sh 脚本 source 使用
# 使用方式:
#   source "$(dirname "${BASH_SOURCE[0]}")/ws-backend.sh"
#   ws_backend_init          # 设置 WS_BACKEND WS_CACHE_DIR WS_CONFIG WS_SKILL_DIR
#   ws_ensure_github         # 设置 WS_GITHUB_* 变量，确保本地 repo 存在
#   ws_ensure_gitlab         # 设置 WS_GITLAB_* 变量，确保本地 repo 存在

_ws_py() { python3 -c "$1" 2>/dev/null || echo ""; }

ws_backend_init() {
  WS_SKILL_DIR="$HOME/.claude/skills/workspace-sync"
  WS_CONFIG="$WS_SKILL_DIR/config.json"
  [[ -f "$WS_CONFIG" ]] || { echo '{"error":"config not found"}'; exit 1; }

  WS_BACKEND=$(_ws_py "import json; d=json.load(open('$WS_CONFIG')); print(d.get('backend') or '')")
  [[ -n "$WS_BACKEND" ]] || { echo '{"error":"backend not configured, run /workspace-sync connect first"}'; exit 1; }

  WS_CACHE_DIR=$(_ws_py "import json; d=json.load(open('$WS_CONFIG')); print(d.get('cache_dir') or '~/.claude/workspace-cache')")
  WS_CACHE_DIR="${WS_CACHE_DIR/#\~/$HOME}"
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
  WS_GITHUB_TOKEN=$(_ws_py "import json; d=json.load(open('$WS_CONFIG')); print((d.get('github') or {}).get('token') or '')")
  WS_GITHUB_REPO=$(_ws_py "import json; d=json.load(open('$WS_CONFIG')); print((d.get('github') or {}).get('repo') or '')")
  WS_GITHUB_BRANCH=$(_ws_py "import json; d=json.load(open('$WS_CONFIG')); print((d.get('github') or {}).get('branch') or 'main')")
  [[ -n "$WS_GITHUB_TOKEN" && -n "$WS_GITHUB_REPO" ]] \
    || { echo '{"error":"github token/repo not configured"}'; exit 1; }

  WS_GITHUB_LOCAL_REPO="$WS_CACHE_DIR/github/$(echo "$WS_GITHUB_REPO" | sed 's|/|_|g')"
  _ws_ensure_repo "$WS_GITHUB_LOCAL_REPO" "https://${WS_GITHUB_TOKEN}@github.com/${WS_GITHUB_REPO}.git"
  (cd "$WS_GITHUB_LOCAL_REPO" && git checkout "$WS_GITHUB_BRANCH" 2>/dev/null || true)
}

# 初始化 GitLab 后端，设置 WS_GITLAB_* 变量，确保本地 repo 存在并切换到目标分支
ws_ensure_gitlab() {
  WS_GITLAB_HOST=$(_ws_py "import json; d=json.load(open('$WS_CONFIG')); print((d.get('gitlab') or {}).get('host') or '')")
  WS_GITLAB_TOKEN=$(_ws_py "import json; d=json.load(open('$WS_CONFIG')); print((d.get('gitlab') or {}).get('token') or '')")
  WS_GITLAB_PROJECT=$(_ws_py "import json; d=json.load(open('$WS_CONFIG')); print((d.get('gitlab') or {}).get('project_path') or '')")
  WS_GITLAB_BRANCH=$(_ws_py "import json; d=json.load(open('$WS_CONFIG')); print((d.get('gitlab') or {}).get('branch') or 'main')")
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
  WS_MC_ALIAS=$(_ws_py "import json; d=json.load(open('$WS_CONFIG')); print((d.get('minio') or {}).get('mc_alias') or 'workspace-sync')")
  WS_MC_BUCKET=$(_ws_py "import json; d=json.load(open('$WS_CONFIG')); print((d.get('minio') or {}).get('bucket') or '')")
  WS_MC_PREFIX=$(_ws_py "import json; d=json.load(open('$WS_CONFIG')); print((d.get('minio') or {}).get('prefix') or 'workspaces/')")
  [[ -n "$WS_MC_BUCKET" ]] || { echo '{"error":"minio bucket not configured"}'; exit 1; }
  command -v mc &>/dev/null || { echo '{"error":"mc not installed"}'; exit 1; }
  WS_MC_BASE="${WS_MC_ALIAS}/${WS_MC_BUCKET}/${WS_MC_PREFIX}"
}

# 读取本地目录路径，设置 WS_LOCAL_PATH
ws_init_local() {
  WS_LOCAL_PATH=$(_ws_py "import json; d=json.load(open('$WS_CONFIG')); print((d.get('local') or {}).get('path') or '')")
  WS_LOCAL_PATH="${WS_LOCAL_PATH/#\~/$HOME}"
  [[ -d "$WS_LOCAL_PATH" ]] || { echo "{\"error\": \"local.path not found: $WS_LOCAL_PATH\"}"; exit 1; }
}
