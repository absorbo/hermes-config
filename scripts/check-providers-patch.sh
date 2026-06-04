#!/bin/bash
# check-providers-patch.sh
# ---------------------------------------------------------------------------
# Daily drift detector for the `hermes_cli/providers.py` `get_provider()`
# fall-through patch.
#
# Why this exists:
#   The user's `minimax-direct` provider is registered as a plugin at
#   `~/.hermes/plugins/model-providers/minimax-direct/__init__.py`, but the
#   upstream `hermes_cli/providers.py::get_provider()` did not consult the
#   providers plugin registry. The fix adds a fall-through to `get_provider()`
#   that calls `providers.get_provider_profile(name)`.
#
#   The fix lives in the local fork at
#   `~/.hermes/hermes-agent/hermes_cli/providers.py`. ANY of the following
#   will silently revert the fix:
#     - `git pull` from `origin` (NousResearch/hermes-agent) — would reset
#       the working file to upstream's HEAD
#     - `hermes update` — pip-installs upstream over the local checkout
#     - manual `git checkout -- hermes_cli/providers.py`
#     - a new clone of the fork onto a fresh machine
#
#   Without this script, drift is detected only when the user gets the
#   "Unknown provider 'minimax-direct'" error — i.e. after the bug is live
#   and a session has already failed.
#
# Behaviour:
#   - exit 0, no output       → fix is in place
#   - exit 1, prints alert    → fix was missing; reapplied automatically
#   - exit 2, prints alert    → fix was missing; reapplied automatically
#                               but the post-apply smoke test FAILED
#   - exit 3, prints alert    → patch could not be applied (conflict with
#                               upstream changes); manual intervention needed
#
# Cron wiring: runs daily via a no_agent cron job. The cron pipeline
# auto-delivers script stdout to the user, so alerts arrive as messages.
# Silence = healthy. Any non-zero exit = message delivered.
# ---------------------------------------------------------------------------

set -u
set -o pipefail

HERMES_AGENT_DIR="${HERMES_AGENT_DIR:-$HOME/.hermes/hermes-agent}"
PATCH_FILE="${PATCH_FILE:-$HOME/.hermes/patches/hermes-providers-get_provider-fallthrough.patch}"
TARGET_FILE="hermes_cli/providers.py"
MARKER="providers-plugin fall-through"   # the comment header on the new fall-through block

cd "$HERMES_AGENT_DIR" || {
  echo "[check-providers-patch] FATAL: cannot cd to $HERMES_AGENT_DIR"
  exit 3
}

# 1. Patch file must exist (idempotent re-deploy after a fresh clone).
if [ ! -f "$PATCH_FILE" ]; then
  echo "[check-providers-patch] FATAL: canonical patch missing at $PATCH_FILE"
  echo "  Re-stage it from the vault mirror (05 - AI/99 - Hermes/patches/) and re-run."
  exit 3
fi

# 2. Cheap fast-path: marker present in the working file? Done.
if grep -q "$MARKER" "$TARGET_FILE" 2>/dev/null; then
  exit 0
fi

# 3. Marker missing — the file has been reverted to upstream. Try to reapply.
echo "[check-providers-patch] DRIFT DETECTED: $TARGET_FILE in $HERMES_AGENT_DIR"
echo "  → '$MARKER' marker absent. The get_provider() plugin fall-through patch is missing."

if ! git apply --check "$PATCH_FILE" 2>/dev/null; then
  echo "  → FATAL: cannot reapply patch — upstream has diverged."
  echo "  → Manual action: cd $HERMES_AGENT_DIR && git diff upstream/main -- hermes_cli/providers.py"
  echo "  → Then re-derive the patch from your last known-good local commit and update $PATCH_FILE."
  exit 3
fi

git apply "$PATCH_FILE" 2>/dev/null
echo "  → Patch re-applied. Post-apply smoke test running..."

# 4. Post-apply smoke test: the marker must now be present, and the
#    import + lookup must succeed under the project's venv.
if ! grep -q "$MARKER" "$TARGET_FILE" 2>/dev/null; then
  echo "  → FATAL: reapply succeeded but marker still missing (file format changed upstream?)."
  exit 2
fi

if [ -x "$HERMES_AGENT_DIR/venv/bin/python" ]; then
  _PY="$HERMES_AGENT_DIR/venv/bin/python"
elif [ -x "$HERMES_AGENT_DIR/venv/bin/python3" ]; then
  _PY="$HERMES_AGENT_DIR/venv/bin/python3"
else
  _PY="python3"
fi

if ! _PROBE_OUT=$("$_PY" -c "from hermes_cli.providers import get_provider; p=get_provider('minimax-direct'); raise SystemExit(0 if p and p.source=='plugin' else 1)" 2>&1); then
  echo "  → FATAL: post-apply smoke test FAILED: $_PROBE_OUT"
  echo "  → The patch is applied but does not behave as expected. Investigate manually."
  exit 2
fi

echo "  → Smoke test OK (get_provider('minimax-direct') resolves via plugin)."
echo "  → Fix is live again. Next: commit the restored file in $HERMES_AGENT_DIR and push."
exit 1
