#!/usr/bin/env bash
# 验证并写入 workspace-sync config.json
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./workspace-sync-lib.sh
source "$SCRIPT_DIR/workspace-sync-lib.sh"

WS_SKILL_DIR="$(ws_workspace_sync_dir "$SCRIPT_DIR")"
CONFIG_PATH="$(ws_workspace_sync_config_path "$SCRIPT_DIR")"

usage() {
  cat <<'EOF'
Usage:
  ws-config.sh local  --path <dir> [--config <path>]
  ws-config.sh github --token <token> --repo <owner/name> [--branch <name>] [--config <path>]
  ws-config.sh gitlab --host <host> --token <token> --project-path <namespace/name> [--branch <name>] [--protocol <https|http>] [--config <path>]
  ws-config.sh minio  --endpoint <url> --access-key <key> --secret-key <key> --bucket <name> [--prefix <prefix>] [--mc-alias <alias>] [--config <path>]
EOF
}

write_config() {
  local backend="$1"
  shift

  if ws_command_exists python3; then
    python3 - "$CONFIG_PATH" "$backend" "$@" <<'PYEOF'
import json
import sys
from pathlib import Path

config_path = Path(sys.argv[1]).expanduser()
backend = sys.argv[2]
args = sys.argv[3:]

config_path.parent.mkdir(parents=True, exist_ok=True)
if config_path.exists():
    with config_path.open(encoding="utf-8") as handle:
        data = json.load(handle)
else:
    data = {}

data["backend"] = backend

if backend == "local":
    data.setdefault("local", {})
    data["local"]["path"] = args[0]
elif backend == "github":
    data.setdefault("github", {})
    data["github"]["token"] = args[0]
    data["github"]["repo"] = args[1]
    data["github"]["branch"] = args[2]
elif backend == "gitlab":
    data.setdefault("gitlab", {})
    data["gitlab"]["host"] = args[0]
    data["gitlab"]["token"] = args[1]
    data["gitlab"]["project_path"] = args[2]
    data["gitlab"]["branch"] = args[3]
    data["gitlab"]["protocol"] = args[4]
elif backend == "minio":
    data.setdefault("minio", {})
    data["minio"]["endpoint"] = args[0]
    data["minio"]["access_key"] = args[1]
    data["minio"]["secret_key"] = args[2]
    data["minio"]["bucket"] = args[3]
    data["minio"]["prefix"] = args[4]
    data["minio"]["mc_alias"] = args[5]
else:
    raise SystemExit(f"unsupported backend: {backend}")

with config_path.open("w", encoding="utf-8", newline="\n") as handle:
    json.dump(data, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
PYEOF
  elif ws_command_exists node; then
    node - "$CONFIG_PATH" "$backend" "$@" <<'NODE'
const fs = require("fs");
const path = require("path");

const configPath = process.argv[2].replace(/^~(?=$|[\\/])/, process.env.HOME || "");
const backend = process.argv[3];
const args = process.argv.slice(4);
const resolved = path.resolve(configPath);

fs.mkdirSync(path.dirname(resolved), { recursive: true });
let data = {};
if (fs.existsSync(resolved)) {
  data = JSON.parse(fs.readFileSync(resolved, "utf8"));
}

data.backend = backend;

if (backend === "local") {
  data.local = data.local || {};
  data.local.path = args[0];
} else if (backend === "github") {
  data.github = data.github || {};
  data.github.token = args[0];
  data.github.repo = args[1];
  data.github.branch = args[2];
} else if (backend === "gitlab") {
  data.gitlab = data.gitlab || {};
  data.gitlab.host = args[0];
  data.gitlab.token = args[1];
  data.gitlab.project_path = args[2];
  data.gitlab.branch = args[3];
  data.gitlab.protocol = args[4];
} else if (backend === "minio") {
  data.minio = data.minio || {};
  data.minio.endpoint = args[0];
  data.minio.access_key = args[1];
  data.minio.secret_key = args[2];
  data.minio.bucket = args[3];
  data.minio.prefix = args[4];
  data.minio.mc_alias = args[5];
} else {
  console.error(`unsupported backend: ${backend}`);
  process.exit(1);
}

fs.writeFileSync(resolved, JSON.stringify(data, null, 2) + "\n", "utf8");
NODE
  else
    ws_die "python3 or node is required to update config.json"
  fi
}

backend="${1:-}"
[[ -n "$backend" ]] || {
  usage >&2
  exit 1
}
shift

LOCAL_PATH=""
GITHUB_TOKEN=""
GITHUB_REPO=""
GITHUB_BRANCH="main"
GITLAB_HOST=""
GITLAB_TOKEN=""
GITLAB_PROJECT_PATH=""
GITLAB_BRANCH="main"
GITLAB_PROTOCOL="https"
MINIO_ENDPOINT=""
MINIO_ACCESS_KEY=""
MINIO_SECRET_KEY=""
MINIO_BUCKET=""
MINIO_PREFIX="workspaces/"
MINIO_MC_ALIAS="claude-workspace-sync"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      [[ $# -ge 2 ]] || ws_die "--config requires a value"
      CONFIG_PATH="$2"
      shift 2
      ;;
    --path)
      [[ $# -ge 2 ]] || ws_die "--path requires a value"
      LOCAL_PATH="$2"
      shift 2
      ;;
    --token)
      [[ $# -ge 2 ]] || ws_die "--token requires a value"
      if [[ "$backend" == "github" ]]; then
        GITHUB_TOKEN="$2"
      else
        GITLAB_TOKEN="$2"
      fi
      shift 2
      ;;
    --repo)
      [[ $# -ge 2 ]] || ws_die "--repo requires a value"
      GITHUB_REPO="$2"
      shift 2
      ;;
    --branch)
      [[ $# -ge 2 ]] || ws_die "--branch requires a value"
      if [[ "$backend" == "github" ]]; then
        GITHUB_BRANCH="$2"
      else
        GITLAB_BRANCH="$2"
      fi
      shift 2
      ;;
    --host)
      [[ $# -ge 2 ]] || ws_die "--host requires a value"
      GITLAB_HOST="$2"
      shift 2
      ;;
    --project-path)
      [[ $# -ge 2 ]] || ws_die "--project-path requires a value"
      GITLAB_PROJECT_PATH="$2"
      shift 2
      ;;
    --protocol)
      [[ $# -ge 2 ]] || ws_die "--protocol requires a value"
      GITLAB_PROTOCOL="$2"
      shift 2
      ;;
    --endpoint)
      [[ $# -ge 2 ]] || ws_die "--endpoint requires a value"
      MINIO_ENDPOINT="$2"
      shift 2
      ;;
    --access-key)
      [[ $# -ge 2 ]] || ws_die "--access-key requires a value"
      MINIO_ACCESS_KEY="$2"
      shift 2
      ;;
    --secret-key)
      [[ $# -ge 2 ]] || ws_die "--secret-key requires a value"
      MINIO_SECRET_KEY="$2"
      shift 2
      ;;
    --bucket)
      [[ $# -ge 2 ]] || ws_die "--bucket requires a value"
      MINIO_BUCKET="$2"
      shift 2
      ;;
    --prefix)
      [[ $# -ge 2 ]] || ws_die "--prefix requires a value"
      MINIO_PREFIX="$2"
      shift 2
      ;;
    --mc-alias)
      [[ $# -ge 2 ]] || ws_die "--mc-alias requires a value"
      MINIO_MC_ALIAS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      ws_die "unknown argument: $1"
      ;;
  esac
done

CONFIG_PATH="$(ws_expand_home "$CONFIG_PATH")"

case "$backend" in
  local)
    [[ -n "$LOCAL_PATH" ]] || ws_die "local backend requires --path"
    local_path_expanded="$(ws_expand_home "$LOCAL_PATH")"
    [[ -d "$local_path_expanded" ]] || ws_die "local path not found: $local_path_expanded"
    write_config "local" "$LOCAL_PATH"
    ;;

  github)
    [[ -n "$GITHUB_TOKEN" && -n "$GITHUB_REPO" ]] || ws_die "github backend requires --token and --repo"
    ws_command_exists curl || ws_die "curl is required to verify the GitHub repository"
    result="$(
      curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        "https://api.github.com/repos/${GITHUB_REPO}"
    )"
    [[ "$result" == "200" ]] || ws_die "GitHub repository verification failed (HTTP $result)"
    write_config "github" "$GITHUB_TOKEN" "$GITHUB_REPO" "$GITHUB_BRANCH"
    ;;

  gitlab)
    [[ -n "$GITLAB_HOST" && -n "$GITLAB_TOKEN" && -n "$GITLAB_PROJECT_PATH" ]] \
      || ws_die "gitlab backend requires --host, --token and --project-path"
    ws_command_exists curl || ws_die "curl is required to verify the GitLab repository"
    encoded_path="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$GITLAB_PROJECT_PATH")"
    result="$(
      no_proxy="$GITLAB_HOST" curl -s -o /dev/null -w "%{http_code}" \
        --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
        "${GITLAB_PROTOCOL}://${GITLAB_HOST}/api/v4/projects/${encoded_path}"
    )"
    [[ "$result" == "200" ]] || ws_die "GitLab repository verification failed (HTTP $result)"
    write_config "gitlab" "$GITLAB_HOST" "$GITLAB_TOKEN" "$GITLAB_PROJECT_PATH" "$GITLAB_BRANCH" "$GITLAB_PROTOCOL"
    ;;

  minio)
    [[ -n "$MINIO_ENDPOINT" && -n "$MINIO_ACCESS_KEY" && -n "$MINIO_SECRET_KEY" && -n "$MINIO_BUCKET" ]] \
      || ws_die "minio backend requires --endpoint, --access-key, --secret-key and --bucket"
    ws_command_exists mc || ws_die "mc is required to verify the MinIO bucket"
    mc alias set "$MINIO_MC_ALIAS" "$MINIO_ENDPOINT" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY" --api S3v4 >/dev/null 2>&1
    mc ls "$MINIO_MC_ALIAS/$MINIO_BUCKET" >/dev/null 2>&1 \
      || ws_die "MinIO bucket verification failed: $MINIO_BUCKET"
    write_config "minio" "$MINIO_ENDPOINT" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY" "$MINIO_BUCKET" "$MINIO_PREFIX" "$MINIO_MC_ALIAS"
    ;;

  *)
    usage >&2
    exit 1
    ;;
esac

printf '{"ok":true,"backend":"%s","config_path":"%s"}\n' \
  "$(ws_json_escape "$backend")" \
  "$(ws_json_escape "$CONFIG_PATH")"
