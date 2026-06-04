#!/bin/bash
# post-update-reapply-fallback.sh
# Re-applies the tui_gateway/server.py fallback_model patch after `hermes update`.
# Without this hook, every `hermes update` overwrites the patch and the gateway
# silently loses the fallback chain wiring.
#
# Registered in: ~/.hermes/gates/hermes-update-hooks/post-update-reapply-fallback.sh
# Triggered by:  `hermes update` post-update hook (hermes config: update.hooks)
# Idempotent:    yes — checks if patch is present before re-applying
#
# Author: Maarten Loose / Claude (2026-06-04, Phase 2 G6)
# Reference:     05 - AI/99 - Hermes/skills/devops/hermes-config-management/references/gateway-fallback-fix.md

set -euo pipefail

SERVER_FILE="$HOME/.hermes/hermes-agent/tui_gateway/server.py"

if [ ! -f "$SERVER_FILE" ]; then
    echo "post-update-reapply-fallback: $SERVER_FILE not found, nothing to do"
    exit 0
fi

# Idempotency check: if the patch is already present, do nothing
if grep -q "fallback_model=get_fallback_chain(cfg)" "$SERVER_FILE"; then
    echo "post-update-reapply-fallback: patch already present in $SERVER_FILE, nothing to do"
    exit 0
fi

# Find the line that creates _make_agent and inject the fallback_model arg
# The patch is: insert "fallback_model=get_fallback_chain(cfg)," after "credential_pool=runtime.get("credential_pool"),"
# Use python for the insertion so we can match precisely without sed escape hell
python3 - "$SERVER_FILE" <<'PYEOF'
import sys, re
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()

# Match the line: credential_pool=runtime.get("credential_pool"),
pattern = r'(credential_pool=runtime\.get\("credential_pool"\),)'
replacement = r'\1\n        fallback_model=get_fallback_chain(cfg),'

if 'fallback_model=get_fallback_chain(cfg)' in text:
    print("ALREADY_PATCHED")
    sys.exit(0)

new_text, n = re.subn(pattern, replacement, text, count=1)
if n == 0:
    print(f"ERROR: could not find insertion point in {path}")
    sys.exit(1)

path.write_text(new_text)
print(f"OK: applied fallback_model patch to {path}")
PYEOF
