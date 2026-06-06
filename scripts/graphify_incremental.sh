#!/bin/bash
# Graphify incremental update — daily 05:00.
# Runs on the watched folder, processes only new/changed files (SHA256 cached).
# Lightweight by design: --no-viz skips HTML; AST is fast; semantic LLM calls
# are bounded by the cache hit rate.
#
# Degraded-cron guard: if the last successful cron run on the system is older
# than 48h, skip this run entirely. Prevents stacking work onto a stalled
# scheduler (cf. 2026-06-04 26h stall).
#
# This script does NOT touch the vault. It writes graphify-out/ inside the
# watched folder only.

set -euo pipefail

WATCH_DIR="$HOME/Documents"
LOG_DIR="$HOME/.hermes/logs"
LOG_FILE="$LOG_DIR/graphify-incremental.log"
LOCK_FILE="$LOG_DIR/graphify-incremental.lock"
STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p "$LOG_DIR"

# Degraded-cron guard — read last-run timestamps from jobs.json.
JOBS_JSON="$HOME/.hermes/cron/jobs.json"
if [ -f "$JOBS_JSON" ]; then
  LAST_OK_EPOCH=$(python3 -c "
import json, datetime, sys
d = json.load(open('$JOBS_JSON'))
epochs = []
for j in d.get('jobs', []):
    la = j.get('last_run_at')
    st = j.get('last_status')
    if la and st == 'ok':
        try:
            epochs.append(datetime.datetime.fromisoformat(la.replace('Z','+00:00')).timestamp())
        except Exception:
            pass
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

# Single-instance lock — prevent overlap if a previous run is still going.
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "$STAMP SKIP another incremental run is in progress" >> "$LOG_FILE"
  exit 0
fi

cd "$WATCH_DIR" || { echo "$STAMP ERROR cannot cd to $WATCH_DIR" >> "$LOG_FILE"; exit 1; }

echo "$STAMP START incremental on $WATCH_DIR" >> "$LOG_FILE"

# 30-min wall clock cap. If exceeded, kill the LLM pass and let the
# incremental cache survive for next time.
timeout 1800 /Users/absorbo/.local/bin/graphify . --update --no-viz >> "$LOG_FILE" 2>&1
RC=$?

echo "$STAMP DONE incremental rc=$RC" >> "$LOG_FILE"
exit $RC
