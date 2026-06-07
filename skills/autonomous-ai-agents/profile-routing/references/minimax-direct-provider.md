# MiniMax Direct API Provider — Setup & Pitfalls

## Current provider posture

`minimax-direct` is a first-class user model-provider plugin, not an inline `custom_providers` entry.

Plugin files:

- `~/.hermes/plugins/model-providers/minimax-direct/__init__.py`
- `~/.hermes/plugins/model-providers/minimax-direct/plugin.yaml`
- For specialist profiles, the same plugin directory must exist under each profile `HERMES_HOME` that needs discovery.

## Provider definition

The plugin declares its own metadata (name, aliases, env_vars, base_url, auth_type, fallback_models). **Read the plugin source for exact values** — do not duplicate here.

```bash
cat ~/.hermes/plugins/model-providers/minimax-direct/__init__.py
```

Runtime configs should use the plugin slug. Read the live configs for exact current values:

```bash
python3 - <<'PY'
import yaml
from pathlib import Path
for f in [Path.home()/'.hermes/config.yaml', *sorted((Path.home()/'.hermes/profiles').glob('*/config.yaml'))]:
    data = yaml.safe_load(f.read_text()) or {}
    model = data.get('model', {})
    fallbacks = [x for x in (data.get('fallback_providers') or []) if x.get('provider') == 'minimax-direct']
    print(f.parent.name if 'profiles' in str(f) else 'default', 'model.provider=', model.get('provider'), 'minimax-direct in fallbacks=', bool(fallbacks))
PY
```

## Key requirement

The MiniMax direct API (`api.minimax.io/v1`) requires a real MiniMax API key in `MINIMAX_API_KEY`. Do not use keys from retired third-party gateways.

## Verification

```bash
# Provider discovery from default and profile homes
for home in "$HOME/.hermes" "$HOME/.hermes/profiles/grcexpert"; do
  HERMES_HOME="$home" "$HOME/.hermes/hermes-agent/venv/bin/python" - <<'PY'
from providers import get_provider_profile
p = get_provider_profile('minimax-direct')
print(p.name, p.base_url, p.env_vars)
PY
done

# Smoke test through Hermes
hermes chat -q "Say OK" --model MiniMax-M3 --provider minimax-direct --quiet
```

## Current chain position

Read the live configs to determine current position:

```bash
python3 - <<'PY'
import yaml
from pathlib import Path
for f in [Path.home()/'.hermes/config.yaml', *sorted((Path.home()/'.hermes/profiles').glob('*/config.yaml'))]:
    data = yaml.safe_load(f.read_text()) or {}
    model = data.get('model', {})
    fallbacks = [x.get('provider') for x in (data.get('fallback_providers') or [])]
    print(f.parent.name if 'profiles' in str(f) else 'default', 'primary=', model.get('provider'), 'fallbacks=', fallbacks)
PY
```
