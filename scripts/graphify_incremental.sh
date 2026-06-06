#!/bin/bash
# Wrapper for vault-hosted graphify_incremental.sh.
# The cron sandbox only allows scripts in ~/.hermes/scripts/, so the real
# script lives here as a static wrapper. The editable source is the vault
# copy at:
#   <vault>/scripts/graphify_incremental.sh
# If the vault copy is updated, the cron behavior updates on the next run
# (this wrapper always exec's the latest vault copy).
#
# Cron job: 30df09d5ffd9 (Graphify Incremental Update, daily 05:00).
# Cron-pipeline skill pitfall 12 (2026-06-06) — verified pattern.
exec "/Users/absorbo/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian/scripts/graphify_incremental.sh" "$@"
