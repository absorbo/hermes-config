# Adding a Provider to the Hermes Fallback Chain

## Preconditions

- For recurring custom endpoints, create or update a model-provider plugin under `~/.hermes/plugins/model-providers/<slug>/`.
- If specialist profiles use the provider, make the plugin discoverable from each profile `HERMES_HOME` as well.
- Credentials must resolve through provider-plugin `env_vars` or the provider's normal credential mechanism, not inline secret-bearing `custom_providers` blocks.
- The service is reachable (`/models`, provider-specific health endpoint, or a Hermes smoke test).

## Step-by-step

### 1. Verify provider discovery

```bash
for home in "$HOME/.hermes" "$HOME/.hermes/profiles/grcexpert"; do
  HERMES_HOME="$home" "$HOME/.hermes/hermes-agent/venv/bin/python" - <<'PY'
from providers import list_providers
print(sorted(list_providers()))
PY
done
```

### 2. Read the current config

Inspect default and specialist configs before editing. **These files are the source of truth — do not duplicate their contents in documentation.**

```bash
python3 - <<'PY'
import yaml
from pathlib import Path
for f in [Path.home()/'.hermes/config.yaml', *sorted((Path.home()/'.hermes/profiles').glob('*/config.yaml'))]:
    data = yaml.safe_load(f.read_text()) or {}
    print(f, data.get('model'), data.get('fallback_providers'), data.get('custom_providers'))
PY
```

### 3. Edit configs

Use the parsed output from step 2 to understand current shape. Insert the new plugin slug into `fallback_providers` in the intended position in each config that needs it. Use `python3` via terminal to edit — the `patch` tool is blocked on config.yaml.

### 4. Validate

```bash
hermes config check
hermes doctor | sed -n '/API Connectivity/,/Tool Availability/p'
```

### 5. Update documentation (thin references only)

Do NOT embed config blocks. Update these files to point to the live configs:

- `05 - AI/08 - Model Notes/Model Configuration.md` — table pointing to config files
- `05 - AI/03 - Personas/Hermes Agent Profiles.md` — profile list
- `05 - AI/Dev/gateway-fallback-fix.md` — if fallback behavior changed
- `05 - AI/00 - AI-MOC/AI-MOC.md` — if provider landscape changed
- This skill's `SKILL.md` — if domain mappings changed

### 6. Commit both repos in the required order

1. Rsync `~/.hermes/` to `05 - AI/99 - Hermes/` with runtime exclusions.
2. Commit/push `clawbot-vault` first.
3. Commit/push `hermes-config` second.

## Pitfalls

- `profiles/`, `plugins/`, and `skills/` may be ignored; explicitly `git add -f` intended paths.
- Do not rely on `custom_providers` for recurring endpoints if the provider should appear in doctor/model picker/plugin discovery.
- Do not treat the OpenRouter doctor warning as an active-route indicator; the probe is hard-coded.
