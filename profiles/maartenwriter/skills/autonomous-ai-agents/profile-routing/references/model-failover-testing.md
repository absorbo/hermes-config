# Model Failover Testing & Diagnostics

## Verified configuration posture — 2026-06-03

Active profiles are `default`, `grcexpert`, and `maartenwriter`. Removed profiles: `codereviewer`, `expertcoder`.

Recurring custom endpoints are first-class provider plugins. Do not reintroduce inline secret-bearing `custom_providers` entries for these endpoints.

### Default profile chain

```yaml
model:
  provider: openai-codex
  default: gpt-5.5

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

### Specialist profile chain — grcexpert, maartenwriter

```yaml
model:
  provider: minimax-direct
  default: MiniMax-M3
  context_length: 256000

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

## Testing each tier individually

```bash
# Default primary
hermes chat -q "Say ok" --model gpt-5.5 --provider openai-codex --quiet

# Specialist primary / default fallback 1
hermes chat -q "Say ok" --model MiniMax-M3 --provider minimax-direct --quiet

# Novita fallback
hermes chat -q "Say ok" --model moonshotai/kimi-k2.6 --provider novita --quiet

# FreeLLM API fallback
hermes chat -q "Say ok" --model auto --provider freellmapi --quiet

# Local Fatman Ollama fallback
hermes chat -q "Say ok" --model qwen3.6:35b-a3b-mlx-bf16 --provider fatman-ollama --quiet
```

## Provider-plugin discovery check

```bash
for home in "$HOME/.hermes" "$HOME/.hermes/profiles/grcexpert" "$HOME/.hermes/profiles/maartenwriter"; do
  HERMES_HOME="$home" "$HOME/.hermes/hermes-agent/venv/bin/python" - <<'PY'
from providers import list_providers
wanted = {'minimax-direct', 'novita', 'freellmapi', 'fatman-ollama'}
print(sorted(wanted & set(list_providers())))
PY
done
```

Expected: all four provider slugs present for each runtime home.

## Checking fallback activity in logs

```bash
grep -i "fallback\|switching to\|429\|RateLimitedError\|errno" ~/.hermes/logs/gateway.log | tail -20
```

Expected log pattern when fallback engages:

```text
⚠️ Rate limited — switching to fallback provider...
🔄 Primary model failed — switching to fallback: <model> via <provider>
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

Use `fatman-ollama` as the provider slug. The endpoint behind it is `http://fatman:11434/v1`; `fatman:11434` is only a historical/config-only alias and should not be used in active fallback chains.

### Profile tap registration gap

Taps are profile-local. Active specialist profiles are only:

```bash
for profile in grcexpert maartenwriter; do
  hermes --profile "$profile" skills tap add OWNER/REPO
done
```

## Quick diagnostic script

Use `scripts/check-failover-health.sh` in this skill directory.
