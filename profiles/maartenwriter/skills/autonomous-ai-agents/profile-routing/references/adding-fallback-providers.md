# Adding a Provider to the Hermes Fallback Chain

Complete workflow for inserting a provider into the Hermes fallback chain.

## Preconditions

- For recurring custom endpoints, create or update a model-provider plugin under `~/.hermes/plugins/model-providers/<slug>/`.
- If specialist profiles use the provider, make the plugin discoverable from each profile `HERMES_HOME` as well.
- Credentials must resolve through provider-plugin `env_vars` or the provider's normal credential mechanism, not inline secret-bearing `custom_providers` blocks.
- The service is reachable (`/models`, provider-specific health endpoint, or a Hermes smoke test).

## Step-by-step

### 1. Verify provider discovery

```bash
for home in "$HOME/.hermes" "$HOME/.hermes/profiles/grcexpert" "$HOME/.hermes/profiles/maartenwriter"; do
  HERMES_HOME="$home" "$HOME/.hermes/hermes-agent/venv/bin/python" - <<'PY'
from providers import list_providers
print(sorted(list_providers()))
PY
done
```

### 2. Read the current config

Inspect default and specialist configs before editing:

```bash
python3 - <<'PY'
import yaml
from pathlib import Path
for f in [Path.home()/'.hermes/config.yaml', *sorted((Path.home()/'.hermes/profiles').glob('*/config.yaml'))]:
    data = yaml.safe_load(f.read_text()) or {}
    print(f, data.get('model'), data.get('fallback_providers'), data.get('custom_providers'))
PY
```

### 3. Insert into `fallback_providers`

The `fallback_providers` array is ordered. Insert the plugin slug in the intended position.

Current default chain shape:

```yaml
fallback_providers:
  - provider: minimax-direct
    model: MiniMax-M3
  - provider: novita
    model: moonshotai/kimi-k2.6
  - provider: freellmapi
    model: auto
  - provider: fatman-ollama
    model: qwen3.6:35b-a3b-mlx-bf16
    timeout: 300

custom_providers: []
```

Current specialist chain shape:

```yaml
fallback_providers:
  - provider: novita
    model: moonshotai/kimi-k2.6
  - provider: freellmapi
    model: auto
  - provider: fatman-ollama
    model: qwen3.6:35b-a3b-mlx-bf16
    timeout: 300

custom_providers: []
```

### 4. Validate YAML and provider discovery

```bash
hermes config check
hermes doctor | sed -n '/API Connectivity/,/Tool Availability/p'
```

### 5. Update all active documentation

At minimum update:

| Doc | Path |
|---|---|
| Model configuration | `05 - AI/08 - Model Notes/Model Configuration.md` |
| Profile overview | `05 - AI/03 - Personas/Hermes Agent Profiles.md` |
| Gateway fallback note | `05 - AI/Dev/gateway-fallback-fix.md` |
| AI MOC | `05 - AI/00 - AI-MOC/AI-MOC.md` |
| Profile-routing skill refs | `~/.hermes/skills/autonomous-ai-agents/profile-routing/` |
| Hermes config-management skill refs | `~/.hermes/skills/devops/hermes-config-management/` |
| Cron pipeline docs if cron prompts/docs mention model/provider routing | `~/.hermes/skills/devops/cron-pipeline/references/pipeline-state.md` |

Then search the broader `05 - AI/` tree and classify remaining hits as active docs/configs vs historical plans/backups/logs.

### 6. Commit both repos in the required order

1. Rsync `~/.hermes/` to `05 - AI/99 - Hermes/` with runtime exclusions.
2. Commit/push `clawbot-vault` first.
3. Commit/push `hermes-config` second.

## Pitfalls

- `profiles/`, `plugins/`, and `skills/` may be ignored; explicitly `git add -f` intended paths.
- Do not rely on `custom_providers` for recurring endpoints if the provider should appear in doctor/model picker/plugin discovery.
- Do not treat the OpenRouter doctor warning as an active-route indicator; the probe is hard-coded.
