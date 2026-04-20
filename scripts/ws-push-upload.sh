#!/usr/bin/env bash
# ws-push-upload.sh <ws_name> [--force]
# push 的上传阶段：写 git 指针、导出 skill states、并发校验、上传
# 退出码: 0=成功 1=失败 2=并发冲突(需用户确认后加 --force 重试)
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ws-backend.sh
source "$SCRIPT_DIR/ws-backend.sh"

WS_NAME="${1:-}"
FORCE="${2:-}"
[[ -n "$WS_NAME" ]] || { echo '{"error":"ws_name is required"}'; exit 1; }

_py() { python3 -c "$1" 2>/dev/null || echo ""; }
ws_backend_init

STAGE_ROOT="$WS_CACHE_DIR/staging"
STAGE_DIR="$STAGE_ROOT/$WS_NAME"
PREPARE_RESULT="$STAGE_DIR/.prepare-result.json"

[[ -f "$PREPARE_RESULT" ]] || { echo '{"error":"prepare result not found, run ws-push-prepare.sh first"}'; exit 1; }
[[ -f "$STAGE_DIR/manifest.json" ]] || { echo '{"error":"manifest.json not found in stage_dir, Claude should write it first"}'; exit 1; }

# ── Step 9: 写 git 指针 (meta.json) ─────────────────────────────────────────
python3 - "$PREPARE_RESULT" "$STAGE_DIR" <<'PYEOF'
import json, os, sys

prep      = json.load(open(sys.argv[1]))
stage_dir = sys.argv[2]

for proj in prep.get("projects", []):
    proj_dir = os.path.join(stage_dir, "projects", proj["name"])
    os.makedirs(proj_dir, exist_ok=True)
    meta = {
        "name":        proj["name"],
        "remote":      proj.get("remote", ""),
        "upstream":    proj.get("upstream", ""),
        "branch":      proj.get("branch", ""),
        "head":        proj.get("head", ""),
        "code_status": proj.get("code_status", "clean"),
    }
    with open(os.path.join(proj_dir, "meta.json"), "w") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
PYEOF

# ── Step 10: 导出 skill states ───────────────────────────────────────────────
SKILL_EXPORT_STATUS="skipped"
SKILL_EXPORT_RESULT="$STAGE_DIR/.skill-export-result.json"
declare -a PROJECT_ARGS=()
while IFS= read -r spec; do
  [[ -n "$spec" ]] || continue
  PROJECT_ARGS+=(--project "$spec")
done < <(python3 - "$PREPARE_RESULT" <<'PYEOF'
import json, sys

prep = json.load(open(sys.argv[1], encoding="utf-8"))
for project in prep.get("projects", []):
    name = project.get("name") or ""
    path = project.get("path") or ""
    if name and path:
        print(f"{name}={path}")
PYEOF
)

if bash "$WS_SKILL_DIR/scripts/export-skill-states.sh" \
     --workspace-name "$WS_NAME" \
     --stage-dir "$STAGE_DIR" \
     "${PROJECT_ARGS[@]}" >"$SKILL_EXPORT_RESULT" 2>/dev/null; then
  python3 - "$STAGE_DIR/manifest.json" "$SKILL_EXPORT_RESULT" <<'PYEOF'
import json, sys

manifest_path = sys.argv[1]
result_path = sys.argv[2]

manifest = json.load(open(manifest_path, encoding="utf-8"))
export_result = json.load(open(result_path, encoding="utf-8"))
manifest["skill_states"] = export_result.get("results", [])

with open(manifest_path, "w", encoding="utf-8") as handle:
    json.dump(manifest, handle, ensure_ascii=False, indent=2)
PYEOF
  SKILL_EXPORT_STATUS="exported"
fi

# ── Step 11: 并发校验 ────────────────────────────────────────────────────────
CURRENT_REMOTE_VERSION=$(_py "import json; prep=json.load(open('$PREPARE_RESULT')); print(prep.get('remote_version', 0))")
MANIFEST_VERSION=$(_py "import json; d=json.load(open('$STAGE_DIR/manifest.json')); print(d.get('previous_version', 0))")

_read_latest_version() {
  local version=""
  case "$WS_BACKEND" in
    local)
      ws_init_local
      version="$(ws_get_json_string "$WS_LOCAL_PATH/$WS_NAME/manifest.json" "version")"
      ;;
    github)
      ws_ensure_github
      version="$(ws_get_json_string "$WS_GITHUB_LOCAL_REPO/$WS_NAME/manifest.json" "version")"
      ;;
    gitlab)
      ws_ensure_gitlab
      version="$(ws_get_json_string "$WS_GITLAB_LOCAL_REPO/$WS_NAME/manifest.json" "version")"
      ;;
    minio)
      ws_init_minio
      TMP=$(mktemp)
      mc cp "${WS_MC_BASE}${WS_NAME}/manifest.json" "$TMP" &>/dev/null && \
        version="$(ws_get_json_string "$TMP" "version")"
      rm -f "$TMP"
      ;;
  esac
  [[ -n "$version" ]] || version="0"
  printf '%s\n' "$version"
}

LATEST_REMOTE_VERSION=$(_read_latest_version)

if [[ "$FORCE" != "--force" && "$LATEST_REMOTE_VERSION" != "$MANIFEST_VERSION" ]]; then
  NEXT_IF_FORCE=$((LATEST_REMOTE_VERSION + 1))
  echo "{\"conflict\": true, \"base_version\": $MANIFEST_VERSION, \"latest_version\": $LATEST_REMOTE_VERSION, \"proposed_version\": $NEXT_IF_FORCE}"
  exit 2
fi

# Recalculate next_version based on latest
NEXT_VERSION=$((LATEST_REMOTE_VERSION + 1))

# Update manifest.json version fields
python3 - "$STAGE_DIR/manifest.json" "$NEXT_VERSION" "$LATEST_REMOTE_VERSION" <<'PYEOF'
import json, sys
path     = sys.argv[1]
nv       = int(sys.argv[2])
prev     = int(sys.argv[3])
d = json.load(open(path))
d["version"]          = nv
d["previous_version"] = prev
with open(path, "w") as f:
    json.dump(d, f, ensure_ascii=False, indent=2)
PYEOF

# ── Step 12: 上传 ────────────────────────────────────────────────────────────
case "$WS_BACKEND" in

  local)
    ws_init_local
    WS_DIR="$WS_LOCAL_PATH/$WS_NAME"
    [[ "$WS_DIR" == "$WS_LOCAL_PATH/"* ]] || { echo '{"error":"illegal workspace path"}'; exit 1; }
    rm -rf -- "$WS_DIR"
    mkdir -p "$WS_DIR"
    cp -r "$STAGE_DIR"/* "$WS_DIR/"
    ;;

  github)
    ws_ensure_github
    WS_DIR="$WS_GITHUB_LOCAL_REPO/$WS_NAME"
    [[ "$WS_DIR" == "$WS_GITHUB_LOCAL_REPO/"* ]] || { echo '{"error":"illegal workspace path"}'; exit 1; }
    rm -rf -- "$WS_DIR"; mkdir -p "$WS_DIR"
    cp -r "$STAGE_DIR"/* "$WS_DIR/"
    (cd "$WS_GITHUB_LOCAL_REPO"
     git checkout "$WS_GITHUB_BRANCH" 2>/dev/null || git checkout -b "$WS_GITHUB_BRANCH"
     git add "$WS_NAME"
     git -c user.email="workspace-sync@local" -c user.name="workspace-sync" \
          commit -m "workspace: update $WS_NAME v${NEXT_VERSION} from $(hostname)" \
        || echo "nothing to commit"
     git push origin "$WS_GITHUB_BRANCH")
    ;;

  gitlab)
    ws_ensure_gitlab
    WS_DIR="$WS_GITLAB_LOCAL_REPO/$WS_NAME"
    [[ "$WS_DIR" == "$WS_GITLAB_LOCAL_REPO/"* ]] || { echo '{"error":"illegal workspace path"}'; exit 1; }
    rm -rf -- "$WS_DIR"; mkdir -p "$WS_DIR"
    cp -r "$STAGE_DIR"/* "$WS_DIR/"
    (cd "$WS_GITLAB_LOCAL_REPO"
     git checkout "$WS_GITLAB_BRANCH" 2>/dev/null || git checkout -b "$WS_GITLAB_BRANCH"
     git add "$WS_NAME"
     git -c user.email="workspace-sync@local" -c user.name="workspace-sync" \
          commit -m "workspace: update $WS_NAME v${NEXT_VERSION} from $(hostname)" \
        || echo "nothing to commit"
     no_proxy="$WS_GITLAB_HOST" git push origin "$WS_GITLAB_BRANCH")
    ;;

  minio)
    ws_init_minio
    mc rm --recursive --force "${WS_MC_BASE}${WS_NAME}/" &>/dev/null || true
    mc cp --recursive "$STAGE_DIR/" "${WS_MC_BASE}${WS_NAME}/"
    ;;

  *)
    echo "{\"error\": \"unknown backend: $WS_BACKEND\"}"; exit 1 ;;
esac

# ── 输出成功结果 ─────────────────────────────────────────────────────────────
DIRTY_PROJECTS=$(python3 -c "
import json
prep = json.load(open('$PREPARE_RESULT'))
dirty = [p['name'] for p in prep.get('projects', []) if p.get('code_status') != 'clean']
print(json.dumps(dirty))
" 2>/dev/null || echo "[]")

echo "{\"success\": true, \"version\": $NEXT_VERSION, \"previous_version\": $((NEXT_VERSION - 1)), \"skill_states\": \"$SKILL_EXPORT_STATUS\", \"dirty_projects\": $DIRTY_PROJECTS}"
