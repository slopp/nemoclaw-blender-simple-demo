#!/usr/bin/env bash
set -euo pipefail

SANDBOX="${1:-${NEMOCLAW_SANDBOX_NAME:-ov-blender-hermes}}"
OV_REPO="${2:-${OV_REPO:-$HOME/work/ov-blender-example-internal}}"
OV_SKILLS_REF="${OV_SKILLS_REF:-pr8-public-skills}"

usage() {
  cat <<'USAGE'
Install public ov-blender-example skills into a running NemoHermes sandbox.

Usage:
  install_public_skills.sh [sandbox-name] [ov-blender-example-checkout]

Environment:
  OV_SKILLS_REF=current          Use the checkout as-is instead of PR 8
  NEMOCLAW_SANDBOX_NAME         Default sandbox name
  OV_REPO                       Default ov-blender-example checkout
USAGE
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if ! command -v nemohermes >/dev/null 2>&1; then
  echo "nemohermes is not on PATH. Source your shell profile or add ~/.local/bin to PATH." >&2
  exit 1
fi

if [ ! -d "$OV_REPO/.git" ]; then
  echo "ov-blender-example checkout not found: $OV_REPO" >&2
  exit 1
fi

cd "$OV_REPO"
if [ "$OV_SKILLS_REF" != "current" ] && ! git cat-file -e "refs/heads/$OV_SKILLS_REF^{commit}" 2>/dev/null; then
  git fetch origin pull/8/head:pr8-public-skills
fi

if [ "$OV_SKILLS_REF" != "current" ]; then
  git checkout "$OV_SKILLS_REF" -- public/skills public/AGENTS.md
elif [ ! -f public/skills/manifest.json ]; then
  echo "public/skills/manifest.json not found and OV_SKILLS_REF=current was set." >&2
  exit 1
fi

count=0
for skill_dir in public/skills/*; do
  if [ -f "$skill_dir/SKILL.md" ]; then
    nemohermes "$SANDBOX" skill install "$skill_dir"
    count=$((count + 1))
  fi
done

echo "installed $count skills into sandbox $SANDBOX"
