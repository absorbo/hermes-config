#!/bin/bash
# Graphify weekly full rebuild — Sun 05:00.
# Re-runs the full pipeline on the watched folder. On Sun, the daily
# incremental also fires at 05:00; the weekly full supersedes it.
#
# Heavy by design. 2h wall clock cap to keep the cron tick from hanging.
# Cluster pass is expensive on large corpora — we accept the cap and rely
# on the next weekly cycle to pick up anything that didn't finish.
#
# Degraded-cron guard: same 48h heuristic as incremental.
# This script does NOT touch the vault.

set -euo pipefail

WATCH_DIR="$HOME/Documents"
LOG_DIR="$HOME/.hermes/logs"
LOG_FILE="$LOG_DIR/graphify-weekly-rebuild.log"
LOCK_FILE="$LOG_DIR/graphify-weekly-rebuild.lock"
STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p "$LOG_DIR"

JOBS_JSON="$HOME/.hermes/cron/jobs.json"
if [ -f "$JOBS_JSON" ]; then
  LAST_OK_EPOCH=$(python3 -c "
import json, datetime
d = json.load(open('$JOBS_JSON'))
epochs = [datetime.datetime.fromisoformat(j['last_run_at'].replace('Z','+00:00')).timestamp()
          for j in d.get('jobs', [])
          if j.get('last_run_at') and j.get('last_status') == 'ok']
print(max(epochs) if epochs else 0)
")
  if [ -n "$LAST_OK_EPOCH" ] && [ "$LAST_OK_EPOCH" != "0" ]; then
    NOW_EPOCH=$(date +%s)
    AGE_HOURS=$(( (NOW_EPOCH - ${LAST_OK_EPOCH%.*}) / 3600 ))
    if [ "$AGE_HOURS" -gt 48 ]; then
      echo "$STAMP SKIP degraded-cron: last successful run was ${AGE_HOURS}h ago" >> "$LOG_FILE"
      exit 0
    fi
  fi
fi

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "$STAMP SKIP another weekly run is in progress" >> "$LOG_FILE"
  exit 0
fi

cd "$WATCH_DIR" || { echo "$STAMP ERROR cannot cd to $WATCH_DIR" >> "$LOG_FILE"; exit 1; }

echo "$STAMP START weekly full rebuild on $WATCH_DIR" >> "$LOG_FILE"

timeout 7200 /Users/absorbo/.local/bin/graphify . --no-viz >> "$LOG_FILE" 2>&1
RC=$?

echo "$STAMP DONE weekly rc=$RC" >> "$LOG_FILE"
exit $RC
