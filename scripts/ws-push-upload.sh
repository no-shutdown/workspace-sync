#!/usr/bin/env bash
# ws-push-upload.sh <ws_name> [--force]
# push 的上传阶段：写 git 指针、导出 skill states、并发校验、上传
# 退出码: 0=成功 1=失败 2=并发冲突(需用户确认后加 --force 重试)
set -euo pipefail

WS_NAME="${1:-}"
FORCE="${2:-}"
[[ -n "$WS_NAME" ]] || { echo '{"error":"ws_name is required"}'; exit 1; }

SKILL_DIR="$HOME/.claude/skills/workspace-sync"
CONFIG="$SKILL_DIR/config.json"
[[ -f "$CONFIG" ]] || { echo '{"error":"config not found"}'; exit 1; }

_py() { python3 -c "$1" 2>/dev/null || echo ""; }

BACKEND=$(_py "import json; d=json.load(open('$CONFIG')); print(d.get('backend') or '')")
CACHE_DIR=$(_py "import json; d=json.load(open('$CONFIG')); print(d.get('cache_dir') or '~/.claude/workspace-cache')")
CACHE_DIR="${CACHE_DIR/#\~/$HOME}"

STAGE_ROOT="$CACHE_DIR/staging"
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
PROJECTS_JSON=$(_py "import json; prep=json.load(open('$PREPARE_RESULT')); print(json.dumps(prep.get('projects', [])))")
SKILL_EXPORT_STATUS="skipped"
if bash "$SKILL_DIR/scripts/export-skill-states.sh" \
     --workspace-name "$WS_NAME" \
     --stage-dir "$STAGE_DIR" \
     --projects-json "$PROJECTS_JSON" 2>/dev/null; then
  SKILL_EXPORT_STATUS="exported"
fi

# ── Step 11: 并发校验 ────────────────────────────────────────────────────────
CURRENT_REMOTE_VERSION=$(_py "import json; prep=json.load(open('$PREPARE_RESULT')); print(prep.get('remote_version', 0))")
MANIFEST_VERSION=$(_py "import json; d=json.load(open('$STAGE_DIR/manifest.json')); print(d.get('previous_version', 0))")

_read_latest_version() {
  case "$BACKEND" in
    local)
      LP=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('local') or {}).get('path') or '')")
      LP="${LP/#\~/$HOME}"
      _py "import json; d=json.load(open('$LP/$WS_NAME/manifest.json')); print(d.get('version') or 0)" 2>/dev/null || echo "0"
      ;;
    github)
      REPO=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('github') or {}).get('repo') or '')")
      LOCAL_REPO="$CACHE_DIR/github/$(echo "$REPO" | sed 's|/|_|g')"
      (cd "$LOCAL_REPO" && git pull --ff-only &>/dev/null || true)
      _py "import json; d=json.load(open('$LOCAL_REPO/$WS_NAME/manifest.json')); print(d.get('version') or 0)" 2>/dev/null || echo "0"
      ;;
    gitlab)
      PROJ=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('gitlab') or {}).get('project_path') or '')")
      HOST=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('gitlab') or {}).get('host') or '')")
      LOCAL_REPO="$CACHE_DIR/gitlab/$(echo "$PROJ" | sed 's|/|_|g')"
      (cd "$LOCAL_REPO" && no_proxy="$HOST" git pull --ff-only &>/dev/null || true)
      _py "import json; d=json.load(open('$LOCAL_REPO/$WS_NAME/manifest.json')); print(d.get('version') or 0)" 2>/dev/null || echo "0"
      ;;
    minio)
      MC_ALIAS=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('minio') or {}).get('mc_alias') or 'workspace-sync')")
      BUCKET=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('minio') or {}).get('bucket') or '')")
      PREFIX=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('minio') or {}).get('prefix') or 'workspaces/')")
      TMP=$(mktemp)
      mc cp "${MC_ALIAS}/${BUCKET}/${PREFIX}${WS_NAME}/manifest.json" "$TMP" &>/dev/null \
        && (_py "import json; d=json.load(open('$TMP')); print(d.get('version') or 0)" || echo "0") \
        || echo "0"
      rm -f "$TMP"
      ;;
  esac
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
case "$BACKEND" in

  local)
    LP=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('local') or {}).get('path') or '')")
    LP="${LP/#\~/$HOME}"
    WS_DIR="$LP/$WS_NAME"
    [[ "$WS_DIR" == "$LP/"* ]] || { echo '{"error":"illegal workspace path"}'; exit 1; }
    rm -rf -- "$WS_DIR"
    mkdir -p "$WS_DIR"
    cp -r "$STAGE_DIR"/* "$WS_DIR/"
    ;;

  github)
    TOKEN=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('github') or {}).get('token') or '')")
    REPO=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('github') or {}).get('repo') or '')")
    BRANCH=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('github') or {}).get('branch') or 'main')")
    LOCAL_REPO="$CACHE_DIR/github/$(echo "$REPO" | sed 's|/|_|g')"
    WS_DIR="$LOCAL_REPO/$WS_NAME"
    [[ "$WS_DIR" == "$LOCAL_REPO/"* ]] || { echo '{"error":"illegal workspace path"}'; exit 1; }
    rm -rf -- "$WS_DIR"; mkdir -p "$WS_DIR"
    cp -r "$STAGE_DIR"/* "$WS_DIR/"
    (cd "$LOCAL_REPO"
     git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH"
     git add "$WS_NAME"
     git -c user.email="workspace-sync@local" -c user.name="workspace-sync" \
         commit -m "workspace: update $WS_NAME v${NEXT_VERSION} from $(hostname)" \
       || echo "nothing to commit"
     git push origin "$BRANCH")
    ;;

  gitlab)
    HOST=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('gitlab') or {}).get('host') or '')")
    TOKEN=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('gitlab') or {}).get('token') or '')")
    PROJ=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('gitlab') or {}).get('project_path') or '')")
    BRANCH=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('gitlab') or {}).get('branch') or 'main')")
    LOCAL_REPO="$CACHE_DIR/gitlab/$(echo "$PROJ" | sed 's|/|_|g')"
    WS_DIR="$LOCAL_REPO/$WS_NAME"
    [[ "$WS_DIR" == "$LOCAL_REPO/"* ]] || { echo '{"error":"illegal workspace path"}'; exit 1; }
    rm -rf -- "$WS_DIR"; mkdir -p "$WS_DIR"
    cp -r "$STAGE_DIR"/* "$WS_DIR/"
    (cd "$LOCAL_REPO"
     git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH"
     git add "$WS_NAME"
     git -c user.email="workspace-sync@local" -c user.name="workspace-sync" \
         commit -m "workspace: update $WS_NAME v${NEXT_VERSION} from $(hostname)" \
       || echo "nothing to commit"
     no_proxy="$HOST" git push origin "$BRANCH")
    ;;

  minio)
    MC_ALIAS=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('minio') or {}).get('mc_alias') or 'workspace-sync')")
    BUCKET=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('minio') or {}).get('bucket') or '')")
    PREFIX=$(_py "import json; d=json.load(open('$CONFIG')); print((d.get('minio') or {}).get('prefix') or 'workspaces/')")
    mc rm --recursive --force "${MC_ALIAS}/${BUCKET}/${PREFIX}${WS_NAME}/" &>/dev/null || true
    mc cp --recursive "$STAGE_DIR/" "${MC_ALIAS}/${BUCKET}/${PREFIX}${WS_NAME}/"
    ;;

  *)
    echo "{\"error\": \"unknown backend: $BACKEND\"}"; exit 1 ;;
esac

# ── 输出成功结果 ─────────────────────────────────────────────────────────────
DIRTY_PROJECTS=$(python3 -c "
import json
prep = json.load(open('$PREPARE_RESULT'))
dirty = [p['name'] for p in prep.get('projects', []) if p.get('code_status') != 'clean']
print(json.dumps(dirty))
" 2>/dev/null || echo "[]")

echo "{\"success\": true, \"version\": $NEXT_VERSION, \"previous_version\": $((NEXT_VERSION - 1)), \"skill_states\": \"$SKILL_EXPORT_STATUS\", \"dirty_projects\": $DIRTY_PROJECTS}"
