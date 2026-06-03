# Hermes Model/Provider Chain Reconfiguration — Surgical Recipe

Use this for: switching primary model/provider, adding/removing/reordering fallback providers, converting config-only providers to first-class plugins, or removing provider references from active Hermes/vault docs.

## Current baseline — 2026-06-03

- Active profiles: `default`, `grcexpert`, `maartenwriter`.
- Removed profiles: `codereviewer`, `expertcoder`.
- Default primary: `openai-codex` / `gpt-5.5`.
- Specialist primary: `minimax-direct` / `MiniMax-M3`.
- Current recurring provider plugins: `minimax-direct`, `novita`, `freellmapi`, `fatman-ollama`.
- Current policy: recurring custom endpoints use provider plugins and env-var credential resolution; do not reintroduce inline secret-bearing `custom_providers` blocks.

## Phase 0 — Plan-first gate

Before editing, write the plan to:

```text
/Users/absorbo/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian/05 - AI/Plans/<timestamp>-<operation>.md
```

The plan must name:

1. Exact provider/model changes.
2. Every live config/profile affected.
3. Provider plugin files affected.
4. Cron jobs/prompts/docs affected, or explicit verification that none pin provider/model/base_url.
5. Vault docs affected.
6. Skills/references affected.
7. Historical artifacts/backups/plans that will be reported but not altered unless explicitly requested.

## Phase 1 — Discovery and classification

Run a broad search before edits and classify hits:

| Category | Examples | Default action |
|---|---|---|
| Live config | `~/.hermes/config.yaml`, `~/.hermes/profiles/*/config.yaml` | Update |
| Live plugins | `~/.hermes/plugins/model-providers/*`, profile plugin copies | Update |
| Live cron control | `~/.hermes/cron/jobs.json`, cron scripts, cron skill docs | Update if provider/model referenced |
| Live skills | `~/.hermes/skills/**`, profile overlay skills | Update active procedural guidance |
| Active vault docs | `05 - AI/**` outside historical plans/backups/logs | Update |
| Vault mirror | `05 - AI/99 - Hermes/**` | Refresh by rsync after live edits |
| Historical artifacts | old plans, backups, cron output, session logs, upstream vendor docs | Report; do not silently mutate |

## Phase 2 — Edit live configs and plugins

Inspect parsed YAML instead of relying on fixed line/block counts:

```bash
python3 - <<'PY'
import yaml
from pathlib import Path
for f in [Path.home()/'.hermes/config.yaml', *sorted((Path.home()/'.hermes/profiles').glob('*/config.yaml'))]:
    data = yaml.safe_load(f.read_text()) or {}
    print(f, data.get('model'), data.get('fallback_providers'), data.get('custom_providers'))
PY
```

Provider plugin discovery check:

```bash
for home in "$HOME/.hermes" "$HOME/.hermes/profiles/grcexpert" "$HOME/.hermes/profiles/maartenwriter"; do
  HERMES_HOME="$home" "$HOME/.hermes/hermes-agent/venv/bin/python" - <<'PY'
from providers import list_providers
names = {getattr(p, 'name', p) for p in list_providers()}
print(sorted(names))
PY
done
```

Current fallback chain shape:

```yaml
# default
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

# grcexpert / maartenwriter
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

## Phase 3 — Update all active documentation surfaces

Minimum surface for provider/model changes:

- `05 - AI/08 - Model Notes/Model Configuration.md`
- `05 - AI/08 - Model Notes/Model Configuration 2.md` if it exists as a redirect note
- `05 - AI/03 - Personas/Hermes Agent Profiles.md`
- `05 - AI/00 - AI-MOC/AI-MOC.md`
- `05 - AI/Dev/gateway-fallback-fix.md` if fallback behavior is discussed
- `05 - AI/05 - Skills/Skills Inventory.md` and `Skill Taps.md` when profile set changes
- `~/.hermes/skills/autonomous-ai-agents/profile-routing/**`
- `~/.hermes/skills/devops/hermes-config-management/**`
- `~/.hermes/skills/devops/cron-pipeline/references/pipeline-state.md`
- Any cron prompt in `~/.hermes/cron/jobs.json` that pins provider/model/base_url

## Phase 4 — Verify

```bash
hermes config check
hermes doctor | sed -n '/API Connectivity/,/Tool Availability/p'
~/.hermes/skills/autonomous-ai-agents/profile-routing/scripts/check-failover-health.sh
```

Expected doctor note: `⚠ OpenRouter API (not configured)` may remain because the doctor probe is hard-coded; it is not evidence of active OpenRouter routing.

## Phase 5 — Mirror and commit

Commit gate order is mandatory:

1. Rsync live Hermes to vault mirror with runtime exclusions.
2. Remove runtime artifacts from mirror.
3. Commit/push `clawbot-vault` first.
4. Commit/push `hermes-config` second.

Recommended rsync:

```bash
rsync -av --delete \
  --exclude 'state.db' --exclude 'state.db-*' --exclude 'state-snapshots/' \
  --exclude 'pastes/' --exclude 'node_modules/' --exclude '__pycache__/' --exclude '*.pyc' \
  ~/.hermes/ "$VAULT/05 - AI/99 - Hermes/"
```

Remember: `profiles/`, `plugins/`, and `skills/` may be ignored. Use explicit `git add -f` for intended files.

## Phase 6 — Report artifacts separately

If searches find stale references only in historical plans, backups, cron outputs, session JSON, upstream Hermes Agent docs/tests, or auth/cache artifacts, list them separately as artifacts for user review. Do not silently rewrite historical/user-authored artifacts unless explicitly requested.
