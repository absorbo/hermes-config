#!/bin/bash
# Wrapper for vault-hosted cron_output_rotate.sh.
# The cron sandbox only allows scripts in ~/.hermes/scripts/, so the real
# script lives here as a static wrapper. The editable source is the vault
# copy at:
#   <vault>/scripts/cron_output_rotate.sh
# If the vault copy is updated, the cron behavior updates on the next run
# (this wrapper always exec's the latest vault copy).
exec "/Users/absorbo/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian/scripts/cron_output_rotate.sh" "$@"
