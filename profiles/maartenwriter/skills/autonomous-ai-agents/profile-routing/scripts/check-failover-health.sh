#!/bin/bash
# check-failover-health.sh — Verify active Hermes profiles have current provider-plugin failover config
# Usage: bash scripts/check-failover-health.sh

set -euo pipefail

python3 - <<'PY'
import subprocess
import sys
import yaml
from pathlib import Path

home = Path.home()
configs = {
    'default': home/'.hermes/config.yaml',
    'grcexpert': home/'.hermes/profiles/grcexpert/config.yaml',
    'maartenwriter': home/'.hermes/profiles/maartenwriter/config.yaml',
}
expected = {
    'default': {
        'provider': 'openai-codex',
        'default': 'gpt-5.5',
        'fallbacks': ['minimax-direct', 'novita', 'freellmapi', 'fatman-ollama'],
    },
    'grcexpert': {
        'provider': 'minimax-direct',
        'default': 'MiniMax-M3',
        'fallbacks': ['novita', 'freellmapi', 'fatman-ollama'],
    },
    'maartenwriter': {
        'provider': 'minimax-direct',
        'default': 'MiniMax-M3',
        'fallbacks': ['novita', 'freellmapi', 'fatman-ollama'],
    },
}
fail = False
print('=== Profile Model/Failover Health Check ===')
for name, path in configs.items():
    if not path.exists():
        print(f'{name}: MISSING {path}')
        fail = True
        continue
    data = yaml.safe_load(path.read_text()) or {}
    model = data.get('model') or {}
    fallbacks = [x.get('provider') for x in (data.get('fallback_providers') or [])]
    custom = data.get('custom_providers')
    exp = expected[name]
    ok = model.get('provider') == exp['provider'] and model.get('default') == exp['default'] and fallbacks == exp['fallbacks'] and custom == []
    print(f"{name}: primary={model.get('provider')}/{model.get('default')} fallbacks={fallbacks} custom_providers={custom} {'OK' if ok else 'FAIL'}")
    fail = fail or not ok

print('\n=== Provider plugin discovery ===')
py = str(home/'.hermes/hermes-agent/venv/bin/python')
code = "from providers import list_providers\nwanted={'minimax-direct','novita','freellmapi','fatman-ollama'}\nnames={getattr(p, 'name', p) for p in list_providers()}\nprint(sorted(wanted & names))"
for name in configs:
    hermes_home = str(home/'.hermes') if name == 'default' else str(home/'.hermes/profiles'/name)
    out = subprocess.check_output([py, '-c', code], env={**dict(__import__('os').environ), 'HERMES_HOME': hermes_home}, text=True).strip()
    print(f'{name}: {out}')
    if not all(x in out for x in ['minimax-direct', 'novita', 'freellmapi', 'fatman-ollama']):
        fail = True

print('\n=== Gateway Status ===')
subprocess.run(['hermes', 'gateway', 'status'], check=False)

sys.exit(1 if fail else 0)
PY
