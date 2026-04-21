#!/usr/bin/env bash
# 列出 workspace，输出 name|version|updated_at（每行一条）
# 默认：只读本地缓存，无网络
# --remote：只查远端轻量列表
# --discover：本地优先，并补充远端缺失项
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ws-backend.sh
source "$SCRIPT_DIR/ws-backend.sh"

REMOTE_MODE=0
DISCOVER_MODE=0
LOCAL_ONLY_MODE=0

usage() {
  cat <<'EOF'
Usage: ws-list.sh [--remote | --discover | --local-only]

Options:
  --remote      Only fetch lightweight remote metadata.
  --discover    Start with local cache, then append remote-only workspaces.
  --local-only  Only read local cache.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote)
      REMOTE_MODE=1
      shift
      ;;
    --discover)
      DISCOVER_MODE=1
      shift
      ;;
    --local-only)
      LOCAL_ONLY_MODE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if (( REMOTE_MODE + DISCOVER_MODE + LOCAL_ONLY_MODE > 1 )); then
  echo "only one of --remote, --discover, --local-only can be used" >&2
  exit 1
fi

ws_backend_init

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

record_from_manifest_json() {
  local ws_name="$1"
  local manifest_json="${2:-}"
  python3 - "$ws_name" "$manifest_json" <<'PYEOF'
import json
import sys

name = sys.argv[1]
raw = sys.argv[2].strip()
version = "-"
updated_at = "-"
if raw:
    try:
        manifest = json.loads(raw)
        value = manifest.get("version")
        if value not in (None, ""):
            version = str(value)
        updated = manifest.get("updated_at")
        if updated:
            updated_at = str(updated)
    except Exception:
        pass
print(f"{name}|{version}|{updated_at}")
PYEOF
}

list_remote_records() {
  case "$WS_BACKEND" in
    github)
      ws_compute_github_path
      while IFS= read -r ws; do
        [[ -n "$ws" ]] || continue
        record_from_manifest_json "$ws" "$(ws_github_fetch_manifest "$ws")"
      done < <(ws_github_list_remote)
      ;;
    gitlab)
      ws_compute_gitlab_path
      while IFS= read -r ws; do
        [[ -n "$ws" ]] || continue
        record_from_manifest_json "$ws" "$(ws_gitlab_fetch_manifest "$ws")"
      done < <(ws_gitlab_list_remote)
      ;;
    minio)
      ws_init_minio
      mc ls "$WS_MC_BASE" 2>/dev/null | awk '{print $NF}' | sed 's|/$||' | while IFS= read -r ws; do
        [[ -n "$ws" ]] || continue
        local manifest_json=""
        manifest_json="$(mc cat "${WS_MC_BASE}${ws}/manifest.json" 2>/dev/null || true)"
        record_from_manifest_json "$ws" "$manifest_json"
      done
      ;;
    local)
      ws_init_local
      list_local_dir "$WS_LOCAL_PATH"
      ;;
    *)
      echo "unknown backend: $WS_BACKEND" >&2
      exit 1
      ;;
  esac
}

merge_records() {
  local local_file="$1"
  local remote_file="$2"
  python3 - "$local_file" "$remote_file" <<'PYEOF'
import sys

local_file, remote_file = sys.argv[1], sys.argv[2]
records = {}
order = []

def parse(line):
    parts = line.rstrip("\n").split("|", 2)
    if len(parts) != 3:
        return None
    name, version, updated_at = parts
    if not name:
        return None
    return name, version, updated_at

def should_replace(current, incoming):
    if current is None:
        return True
    _, current_version, current_updated = current
    _, incoming_version, incoming_updated = incoming
    if incoming_version != "-" and current_version == "-":
        return True
    if incoming_updated != "-" and current_updated == "-":
        return True
    if incoming_version != "-" or incoming_updated != "-":
        return True
    return False

for path in (local_file, remote_file):
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            parsed = parse(line)
            if parsed is None:
                continue
            name = parsed[0]
            if name not in records:
                order.append(name)
            if should_replace(records.get(name), parsed):
                records[name] = parsed

for name in order:
    print("|".join(records[name]))
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
      list_remote_records
    elif [[ $DISCOVER_MODE -eq 1 ]]; then
      local_tmp="$(mktemp)"
      remote_tmp="$(mktemp)"
      trap 'rm -f "$local_tmp" "$remote_tmp"' EXIT
      if [[ -d "$WS_GITHUB_LOCAL_REPO" ]]; then
        list_local_dir "$WS_GITHUB_LOCAL_REPO" > "$local_tmp"
      else
        : > "$local_tmp"
      fi
      list_remote_records > "$remote_tmp"
      merge_records "$local_tmp" "$remote_tmp"
    elif [[ -d "$WS_GITHUB_LOCAL_REPO" ]]; then
      list_local_dir "$WS_GITHUB_LOCAL_REPO"
    else
      printf '__NO_LOCAL_CACHE__\n'
    fi
    ;;

  gitlab)
    ws_compute_gitlab_path
    if [[ $REMOTE_MODE -eq 1 ]]; then
      list_remote_records
    elif [[ $DISCOVER_MODE -eq 1 ]]; then
      local_tmp="$(mktemp)"
      remote_tmp="$(mktemp)"
      trap 'rm -f "$local_tmp" "$remote_tmp"' EXIT
      if [[ -d "$WS_GITLAB_LOCAL_REPO" ]]; then
        list_local_dir "$WS_GITLAB_LOCAL_REPO" > "$local_tmp"
      else
        : > "$local_tmp"
      fi
      list_remote_records > "$remote_tmp"
      merge_records "$local_tmp" "$remote_tmp"
    elif [[ -d "$WS_GITLAB_LOCAL_REPO" ]]; then
      list_local_dir "$WS_GITLAB_LOCAL_REPO"
    else
      printf '__NO_LOCAL_CACHE__\n'
    fi
    ;;

  minio)
    list_remote_records
    ;;

  *)
    echo "unknown backend: $WS_BACKEND" >&2
    exit 1
    ;;
esac
