#!/bin/bash
# ~/.hermes/gates/pre-execution/git-commit-gate.sh
# Gate Type: pre_tool_call
# Matches: terminal commands containing git commit/push/init/add
# Action: BLOCK if vault mirror hasn't been synced this session
#
# Wire protocol (stdin JSON):
#   {"hook_event_name":"pre_tool_call","tool_name":"terminal",
#    "tool_input":{"command":"..."},"session_id":"...","cwd":"..."}
#
# Block response (stdout JSON):
#   {"action":"block","message":"COMMIT GATE: ..."}
#   OR
#   {"action":"allow"}  (pass through)

set -euo pipefail

# --- Configuration -----------------------------------------------------------
SESSION_STAMP_DIR="/tmp/hermes-gate-sessions"
VAULT="/Users/absorbo/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian"
MIRROR="${VAULT}/05 - AI/99 - Hermes"

# --- Parse stdin JSON --------------------------------------------------------
INPUT=$(cat)

# Extract tool_input.command
TOOL_CMD=$(echo "$INPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
tool_input = data.get('tool_input', {})
# tool_input could be {'command': '...'} for terminal, or the args dict
cmd = tool_input.get('command', '') if isinstance(tool_input, dict) else ''
print(cmd)
" 2>/dev/null || true)

# --- Check if this is a git operation we care about ---------------------------
# Only gate: git commit, git push, git init, git add (when touching ~/.hermes/)
if ! echo "$TOOL_CMD" | grep -qE '(git\s+(commit|push|init)|git\s+add.*hermes)'; then
    # Not a gated git command — allow silently
    echo '{"action":"allow"}'
    exit 0
fi

# --- Determine session ID -----------------------------------------------------
SESSION_ID=$(echo "$INPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
# session_id is reliable; parent_session_id is fallback
sid = data.get('session_id', '') or data.get('extra', {}).get('parent_session_id', '')
print(sid)
" 2>/dev/null || true)

if [ -z "$SESSION_ID" ]; then
    # No session ID available — block conservatively
    echo '{"action":"block","message":"COMMIT GATE: Cannot verify session state (no session_id). Sync vault mirror first:\n  rsync -av --delete ~/.hermes/ \"'"$MIRROR"'/\"\n  rm -f \"'"$MIRROR"'/state.db\"*\nThen retry."}'
    exit 0
fi

# --- Check session stamp ------------------------------------------------------
STAMP_FILE="${SESSION_STAMP_DIR}/${SESSION_ID}.synced"
mkdir -p "$SESSION_STAMP_DIR" 2>/dev/null || true

if [ -f "$STAMP_FILE" ]; then
    # Session already synced — allow
    echo '{"action":"allow"}'
    exit 0
fi

# Check if the rsync was actually done (stamp doesn't exist, but maybe user
# did it manually outside the agent? Check mirror freshness)
HERMES_SOUL_TS=$(stat -f "%m" ~/.hermes/SOUL.md 2>/dev/null || stat -c "%Y" ~/.hermes/SOUL.md 2>/dev/null || echo "0")
MIRROR_SOUL_TS=$(stat -f "%m" "$MIRROR/SOUL.md" 2>/dev/null || stat -c "%Y" "$MIRROR/SOUL.md" 2>/dev/null || echo "0")

if [ "$HERMES_SOUL_TS" -le "$MIRROR_SOUL_TS" ] 2>/dev/null; then
    # Mirror is at least as recent as live — consider it synced, create stamp
    touch "$STAMP_FILE" 2>/dev/null || true
    echo '{"action":"allow"}'
    exit 0
fi

# --- BLOCK -------------------------------------------------------------------
echo "{\"action\":\"block\",\"message\":\"⛔ COMMIT GATE: Vault mirror not synced this session.\n\nBefore any git operation touching ~/.hermes/, run:\n  rsync -av --delete ~/.hermes/ \\\"${MIRROR}/\\\"\n  rm -f \\\"${MIRROR}/state.db\\\"*\n  rm -rf \\\"${MIRROR}/state-snapshots/\\\"\n\nThis syncs the Hermes mirror in the Clawbot vault. The vault pre-commit hook will also block stale mirrors.\n\nAfter syncing, this gate will pass for the rest of this session.\"}"
exit 0
