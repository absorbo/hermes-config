#!/usr/bin/env bash
set -euo pipefail
PYTHON="/Users/absorbo/.hermes/hermes-agent/venv/bin/python3"
SCRIPT="/Users/absorbo/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian/scripts/workflow_backlink_curator.py"

if [ ! -f "$SCRIPT" ]; then
  echo "ERROR: Backlink curator script not found: $SCRIPT"
  exit 1
fi

APPLY_OUTPUT="$($PYTHON "$SCRIPT" --apply --days 1)"
DRY_OUTPUT="$($PYTHON "$SCRIPT" --dry-run --days 1)"

printf '%s\n' "Backlink Curator apply output:" "$APPLY_OUTPUT"
printf '%s\n' "" "Backlink Curator post-apply dry-run output:" "$DRY_OUTPUT"
