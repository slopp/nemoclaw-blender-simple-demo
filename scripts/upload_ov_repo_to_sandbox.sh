#!/usr/bin/env bash
set -euo pipefail

SANDBOX="${1:-${NEMOCLAW_SANDBOX_NAME:-ov-blender-hermes}}"
OV_REPO="${2:-${OV_REPO:-$HOME/work/ov-blender-example-internal}}"
SANDBOX_DEST="${3:-${OV_REPO_SANDBOX:-/sandbox/ov-blender-example-internal}}"

usage() {
  cat <<'USAGE'
Upload the ov-blender-example checkout into a NemoHermes sandbox.

The public skill installer only installs SKILL.md directories. Use this script
when a prompt needs the repo's public tests, fixtures, helper scripts, or source
files inside the Hermes sandbox.

Usage:
  upload_ov_repo_to_sandbox.sh [sandbox-name] [ov-blender-example-checkout] [sandbox-dest]

Environment:
  NEMOCLAW_SANDBOX_NAME         Default sandbox name
  OV_REPO                       Default ov-blender-example checkout
  OV_REPO_SANDBOX               Default sandbox destination
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

if [ ! -d "$OV_REPO/public" ]; then
  echo "expected public/ in ov-blender-example checkout: $OV_REPO" >&2
  exit 1
fi

case "$SANDBOX_DEST" in
  /sandbox/*|/workspace/*|/tmp/*) ;;
  *)
    echo "sandbox destination must be under /sandbox, /workspace, or /tmp: $SANDBOX_DEST" >&2
    exit 1
    ;;
esac

if printf '%s' "$SANDBOX_DEST" | grep -q '[^A-Za-z0-9_./-]'; then
  echo "sandbox destination contains unsupported shell characters: $SANDBOX_DEST" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
repo_name="$(basename "$SANDBOX_DEST")"
stage_dir="$tmp_dir/$repo_name"
mkdir -p "$stage_dir"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete \
    --exclude='/.git/' \
    --exclude='/.venv/' \
    --exclude='/build/' \
    --exclude='/dist/' \
    --exclude='/out/' \
    --exclude='/node_modules/' \
    --exclude='/.pytest_cache/' \
    --exclude='__pycache__/' \
    --exclude='*.tar' \
    --exclude='*.tar.gz' \
    --exclude='*.tgz' \
    --exclude='*.whl' \
    --exclude='*.zip' \
    "$OV_REPO"/ "$stage_dir"/
else
  (
    cd "$OV_REPO"
    tar \
      --exclude='./.git' \
      --exclude='./.venv' \
      --exclude='./build' \
      --exclude='./dist' \
      --exclude='./out' \
      --exclude='./node_modules' \
      --exclude='./.pytest_cache' \
      --exclude='__pycache__' \
      --exclude='*.tar' \
      --exclude='*.tar.gz' \
      --exclude='*.tgz' \
      --exclude='*.whl' \
      --exclude='*.zip' \
      -cf - .
  ) | (
    cd "$stage_dir"
    tar -xf -
  )
fi

dest_parent="$(dirname "$SANDBOX_DEST")"

echo "clearing $SANDBOX_DEST in sandbox $SANDBOX"
nemohermes "$SANDBOX" exec --timeout 30 -- sh -lc "rm -rf $SANDBOX_DEST && mkdir -p $dest_parent"

echo "uploading $OV_REPO to $SANDBOX:$SANDBOX_DEST"
nemohermes "$SANDBOX" upload "$stage_dir" "$SANDBOX_DEST"

verify_cmd="set -eu; if [ -d $SANDBOX_DEST/public ]; then :; elif [ -d $SANDBOX_DEST/$repo_name/public ]; then nested_tmp=${SANDBOX_DEST}.nested.\$\$; mv $SANDBOX_DEST/$repo_name \"\$nested_tmp\"; rm -rf $SANDBOX_DEST; mv \"\$nested_tmp\" $SANDBOX_DEST; else echo 'public directory was not found after upload' >&2; find $SANDBOX_DEST -maxdepth 3 -type d 2>/dev/null | sed -n '1,40p' >&2; exit 1; fi; test -d $SANDBOX_DEST/public/skills; find $SANDBOX_DEST -maxdepth 2 -type d | sort | sed -n '1,40p'"
nemohermes "$SANDBOX" exec --timeout 60 -- sh -lc "$verify_cmd"

echo "uploaded ov-blender-example checkout to sandbox path $SANDBOX_DEST"
