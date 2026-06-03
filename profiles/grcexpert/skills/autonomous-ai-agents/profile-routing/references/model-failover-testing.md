# Model Failover Testing & Diagnostics

## Current configuration

Active profiles are `default`, `grcexpert`, and `maartenwriter`. **Read the live configs for exact current values — do not duplicate here.**

```bash
python3 - <<'PY'
import yaml
from pathlib import Path
for f in [Path.home()/'.hermes/config.yaml', *sorted((Path.home()/'.hermes/profiles').glob('*/config.yaml'))]:
    data = yaml.safe_load(f.read_text()) or {}
    print(f.parent.name if 'profiles' in str(f) else 'default', data.get('model'), data.get('fallback_providers'))
PY
```

## Testing each tier individually

```bash
# Read current primary from config, then test:
hermes chat -q "Say ok" --model <primary_model> --provider <primary_provider> --quiet

# Test each fallback tier:
hermes chat -q "Say ok" --model <fallback_model> --provider <fallback_provider> --quiet
```

## Provider-plugin discovery check

```bash
for home in "$HOME/.hermes" "$HOME/.hermes/profiles/grcexpert" "$HOME/.hermes/profiles/maartenwriter"; do
  HERMES_HOME="$home" "$HOME/.hermes/hermes-agent/venv/bin/python" - <<'PY'
from providers import list_providers
names = {getattr(p, 'name', p) for p in list_providers()}
print(sorted(names))
PY
done
```

## Checking fallback activity in logs

```bash
grep -i "fallback\|switching to\|429\|RateLimitedError\|errno" ~/.hermes/logs/gateway.log | tail -20
```

## Common pitfalls

### Gateway using stale config

Restart the gateway after any provider/fallback config or plugin change.

```bash
hermes gateway restart
```

### Profile homes do not automatically inherit user-local plugins

If a profile uses a user-local provider plugin, verify discovery from that profile's `HERMES_HOME` and copy the plugin into the profile plugin directory if necessary.

### OpenRouter doctor warning

`hermes doctor` may still print `⚠ OpenRouter API (not configured)` because the doctor probe is hard-coded. That warning is not evidence that OpenRouter is active in the route.

### Fatman provider slug

Use `fatman-ollama` as the provider slug. The endpoint behind it is `http://fatman:11434/v1`; `fatman:11434` is only a historical/config-only alias.

## Quick diagnostic script

Use `scripts/check-failover-health.sh` in this skill directory.
