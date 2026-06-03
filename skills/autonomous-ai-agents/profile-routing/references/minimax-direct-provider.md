# MiniMax Direct API Provider — Setup & Pitfalls

## Current provider posture

`minimax-direct` is a first-class user model-provider plugin, not an inline `custom_providers` entry.

Plugin files:

- `~/.hermes/plugins/model-providers/minimax-direct/__init__.py`
- `~/.hermes/plugins/model-providers/minimax-direct/plugin.yaml`
- For specialist profiles, the same plugin directory must exist under each profile `HERMES_HOME` that needs discovery.

## Provider definition

The plugin declares:

```python
ProviderProfile(
    name="minimax-direct",
    aliases=("minimax-direct",),
    display_name="MiniMax Direct",
    env_vars=("MINIMAX_API_KEY", "MINIMAX_BASE_URL"),
    base_url="https://api.minimax.io/v1",
    auth_type="api_key",
    default_aux_model="MiniMax-M2.5",
    fallback_models=("MiniMax-M2.5", "MiniMax-M3"),
)
```

Runtime configs should use the plugin slug:

```yaml
model:
  provider: minimax-direct
  default: MiniMax-M3
```

or:

```yaml
fallback_providers:
  - provider: minimax-direct
    model: MiniMax-M3
```

## Key requirement

The MiniMax direct API (`api.minimax.io`) requires a real MiniMax API key in `MINIMAX_API_KEY`. Do not use keys from retired third-party gateways.

## Verification

```bash
# Provider discovery from default and profile homes
for home in "$HOME/.hermes" "$HOME/.hermes/profiles/grcexpert" "$HOME/.hermes/profiles/maartenwriter"; do
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

- Default profile: fallback 1 after `openai-codex` / `gpt-5.5`.
- `grcexpert` and `maartenwriter`: primary provider.
