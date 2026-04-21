#!/usr/bin/env bash
# 列出所有 workspace，输出 name|version|updated_at（每行一条）
# 默认：从本地缓存读取，无需网络
# --remote：通过 API 从远端获取列表（本地无缓存时由 Claude 主动调用）
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ws-backend.sh
source "$SCRIPT_DIR/ws-backend.sh"

REMOTE_MODE=0
[[ "${1:-}" == "--remote" ]] && REMOTE_MODE=1

ws_backend_init

# 用 Python 遍历本地缓存目录，规避 Windows bash 非 ASCII 路径问题
list_local_dir() {
  local dir="$1"
  PYTHONIOENCODING=utf-8 python3 - "$dir" <<'PYEOF'
import json, os, sys

dir_path = sys.argv[1]
if not os.path.isdir(dir_path):
    sys.exit(0)

for entry in sorted(os.listdir(dir_path)):
    if entry == '.git':
        continue
    ws_dir = os.path.join(dir_path, entry)
    if not os.path.isdir(ws_dir):
        continue
    manifest_path = os.path.join(ws_dir, 'manifest.json')
    if not os.path.isfile(manifest_path):
        continue
    try:
        with open(manifest_path, encoding='utf-8') as fh:
            manifest = json.load(fh)
        version = str(manifest.get('version', '-'))
        updated_at = manifest.get('updated_at') or '-'
    except Exception:
        version = '-'
        updated_at = '-'
    print(f"{entry}|{version}|{updated_at}")
PYEOF
}

case "$WS_BACKEND" in
  local)
    ws_init_local
    list_local_dir "$WS_LOCAL_PATH"
    ;;

  github)
    ws_compute_github_path
    if [[ $REMOTE_MODE -eq 1 ]]; then
      ws_github_list_remote | while IFS= read -r ws; do
        [[ -n "$ws" ]] && printf '%s|-|-\n' "$ws"
      done
    elif [[ -d "$WS_GITHUB_LOCAL_REPO" ]]; then
      list_local_dir "$WS_GITHUB_LOCAL_REPO"
    else
      printf '__NO_LOCAL_CACHE__\n'
    fi
    ;;

  gitlab)
    ws_compute_gitlab_path
    if [[ $REMOTE_MODE -eq 1 ]]; then
      ws_gitlab_list_remote | while IFS= read -r ws; do
        [[ -n "$ws" ]] && printf '%s|-|-\n' "$ws"
      done
    elif [[ -d "$WS_GITLAB_LOCAL_REPO" ]]; then
      list_local_dir "$WS_GITLAB_LOCAL_REPO"
    else
      printf '__NO_LOCAL_CACHE__\n'
    fi
    ;;

  minio)
    # MinIO 无本地缓存，始终查询远端（但只取 manifest，不下完整内容）
    ws_init_minio
    mc ls "$WS_MC_BASE" 2>/dev/null | awk '{print $NF}' | sed 's|/$||' | while IFS= read -r ws; do
      [[ -n "$ws" ]] || continue
      local_manifest="$(mktemp)"
      mc cp "${WS_MC_BASE}${ws}/manifest.json" "$local_manifest" &>/dev/null || {
        rm -f "$local_manifest"
        continue
      }
      version="$(ws_get_json_string "$local_manifest" "version")"
      updated_at="$(ws_get_json_string "$local_manifest" "updated_at")"
      rm -f "$local_manifest"
      [[ -n "$version" ]] || version="-"
      [[ -n "$updated_at" ]] || updated_at="-"
      printf '%s|%s|%s\n' "$ws" "$version" "$updated_at"
    done
    ;;

  *)
    echo "unknown backend: $WS_BACKEND" >&2
    exit 1
    ;;
esac
