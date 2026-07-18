#!/usr/bin/env bash
set -euo pipefail

OV_REPO="${1:-${OV_REPO:-$HOME/work/ov-blender-example-internal}}"
GUIDE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_SKILLS_DIR="${CODEX_SKILLS_DIR:-$HOME/.agents/skills}"

usage() {
  cat <<'USAGE'
Install the project Codex coaching skills and link the upstream OV add-on skills.

Usage:
  install_codex_skills.sh [ov-blender-example-checkout]

Environment:
  OV_REPO             Default OV repository checkout
  CODEX_SKILLS_DIR    Codex user skill directory (default: ~/.agents/skills)
USAGE
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ ! -d "$OV_REPO/.git" ] || [ ! -d "$OV_REPO/public/skills" ]; then
  echo "OV add-on checkout with public skills not found: $OV_REPO" >&2
  exit 1
fi

mkdir -p "$CODEX_SKILLS_DIR"

# Remove only stale links previously created from this upstream skill tree.
# Project skills and unrelated user-installed skills are left untouched.
for target in "$CODEX_SKILLS_DIR"/*; do
  if [ -L "$target" ] && [ ! -e "$target" ]; then
    case "$(readlink "$target")" in
      "$OV_REPO"/public/skills/*) rm "$target" ;;
    esac
  fi
done

link_skill() {
  local source_dir="$1"
  local skill_name target
  skill_name="$(basename "$source_dir")"
  target="$CODEX_SKILLS_DIR/$skill_name"

  if [ ! -f "$source_dir/SKILL.md" ]; then
    return
  fi

  if [ -L "$target" ] && [ "$(readlink -f "$target")" = "$(readlink -f "$source_dir")" ]; then
    echo "already linked: $skill_name"
    return
  fi

  if [ -e "$target" ] || [ -L "$target" ]; then
    echo "refusing to replace existing Codex skill: $target" >&2
    exit 1
  fi

  ln -s "$(readlink -f "$source_dir")" "$target"
  echo "linked: $skill_name"
}

project_count=0
for skill_dir in "$GUIDE_ROOT"/codex-skills/*; do
  if [ -f "$skill_dir/SKILL.md" ]; then
    link_skill "$skill_dir"
    project_count=$((project_count + 1))
  fi
done

count=0
for skill_dir in "$OV_REPO"/public/skills/*; do
  if [ -f "$skill_dir/SKILL.md" ]; then
    link_skill "$skill_dir"
    count=$((count + 1))
  fi
done

echo "Linked $project_count project coaching skills and $count upstream OV skills from $OV_REPO"
