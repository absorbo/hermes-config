#!/bin/bash
# Wrapper for vault-hosted graphify_weekly_cluster.sh.
# The cron sandbox only allows scripts in ~/.hermes/scripts/, so the real
# script lives here as a static wrapper. The editable source is the vault
# copy at:
#   <vault>/scripts/graphify_weekly_cluster.sh
# If the vault copy is updated, the cron behavior updates on the next run
# (this wrapper always exec's the latest vault copy).
#
# Cron job: af4f4b4299d5 (Graphify Weekly Full Rebuild, Sun 05:05,
# no_agent). Replaces the previous graphify_weekly_rebuild.sh (combined
# AST+cluster) which timed out at the 120s cron-tick cap on 2026-06-07.
# Cron-pipeline skill pitfall 12 (2026-06-06) — verified pattern.
exec "/Users/absorbo/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian/scripts/graphify_weekly_cluster.sh" "$@"
