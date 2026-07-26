#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INIT_CONFIG=1

default_state_root() {
  if [[ -n "${CODEX_HOME:-}" ]]; then
    printf '%s\n' "$CODEX_HOME"
    return
  fi

  if [[ -n "${CLAUDE_HOME:-}" ]]; then
    printf '%s\n' "$CLAUDE_HOME"
    return
  fi

  if [[ -d "$HOME/.codex" ]]; then
    printf '%s\n' "$HOME/.codex"
    return
  fi

  if [[ -d "$HOME/.claude" ]]; then
    printf '%s\n' "$HOME/.claude"
    return
  fi

  printf '%s\n' "$HOME/.codex"
}

TARGET_DIR="$(default_state_root)/skills/workspace-sync"

usage() {
  cat <<'EOF'
Usage: ./install.sh [--target <dir>] [--no-init-config]

Installs the workspace-sync skill into the current CLI skills directory by default.

Options:
  --target <dir>      Install into a custom target directory.
  --no-init-config    Do not create config.json from the example template.
  -h, --help          Show this help.
EOF
}

assert_safe_target() {
  local target="$1"

  [[ -n "$target" ]] || {
    echo "Refusing to install to an empty target path." >&2
    exit 1
  }

  case "$target" in
    /|.|"$HOME"|"$HOME/.claude"|"$HOME/.claude/skills"|"$HOME/.codex"|"$HOME/.codex/skills")
      echo "Refusing to install to unsafe target: $target" >&2
      exit 1
      ;;
  esac
}

normalize_target_path() {
  local path="$1"
  local drive
  local rest
  local lower_drive

  case "$path" in
    [A-Za-z]:*)
      drive="${path:0:1}"
      rest="${path:2}"
      rest="${rest//\\//}"
      [[ "$rest" == /* ]] || rest="/$rest"
      lower_drive="$(printf '%s' "$drive" | tr '[:upper:]' '[:lower:]')"
      printf '/mnt/%s%s\n' "$lower_drive" "$rest"
      ;;
    *)
      printf '%s\n' "$path"
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || {
        echo "--target requires a path." >&2
        exit 1
      }
      TARGET_DIR="$2"
      shift 2
      ;;
    --no-init-config)
      INIT_CONFIG=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

TARGET_DIR="$(normalize_target_path "$TARGET_DIR")"
assert_safe_target "$TARGET_DIR"

# Copy all source files (excluding .git), preserving directory structure.
# New files added to the repo are automatically picked up on next install.
while IFS= read -r f; do
  dest="$TARGET_DIR/$f"
  mkdir -p "$(dirname "$dest")"
  cp -- "$SCRIPT_DIR/$f" "$dest"
done < <(cd "$SCRIPT_DIR" && find . -not -path './.git/*' -not -name '.gitignore' -type f | sed 's|^\./||' | sort)

chmod +x "$TARGET_DIR/install.sh" "$TARGET_DIR/uninstall.sh"

if [[ "$INIT_CONFIG" == "1" && ! -f "$TARGET_DIR/config.json" ]]; then
  cp "$SCRIPT_DIR/templates/config.json.example" "$TARGET_DIR/config.json"
fi

cat <<EOF
Installed workspace-sync to:
  $TARGET_DIR

Files:
  $TARGET_DIR/SKILL.md
  $TARGET_DIR/README.md
  $TARGET_DIR/action/
  $TARGET_DIR/docs/
  $TARGET_DIR/references/
  $TARGET_DIR/templates/

Next steps:
  1. Configure one personal knowledge-base Git repository with /workspace-sync config
  2. Start your CLI and run /workspace-sync pull to select or create a workspace
EOF
