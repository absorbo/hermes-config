---
type: plan
status: pending-approval
created: 2026-06-01
task: reconfigure-primary-model-remove-canopywave
---

# Plan — Switch primary model to minimax-direct / MiniMax-M3, remove canopywave

## User intent (verbatim, summarised)

- Remove `canopywave` from all configuration and documentation (user has discontinued it).
- Set primary model for ALL profiles (default + 4 specialists) to `minimax-direct` / `MiniMax-M3`.
- Fallback chain (in order): `freellmapi/auto` → `deepseek-direct/deepseek-v4-pro` → `fatman:11434/qwen3.6:27b-mxfp8`.
- "Instead of MiniMax-M2.7" — user clarified (Q1): the default profile's primary should be `minimax-direct`/M3 AND `minimax-direct` is removed from fallbacks (since M3 is now primary on direct).

## User decisions captured (Q1, Q2, Q3)

- **Q1:** Switch default primary to `minimax-direct`/M3 AND remove `minimax-direct` from fallbacks.
- **Q2:** All 4 specialist profiles: primary = `minimax-direct`/M3. Identical fallback chain to default.
- **Q3:** Full doc refresh — vault config mirror, Model Configuration.md, Hermes Agent Profiles.md, SOUL.md (vault copy), Model Configuration 2.md, gateway-fallback-fix.md, use-case-7/implementation-plan.md, and clear canopywave entries from cache files.

## Current state (verified from disk, not from system prompt)

| Profile    | Current primary                              | Current 1st fallback          | Notes                                        |
|------------|----------------------------------------------|-------------------------------|----------------------------------------------|
| default    | `MiniMax-M3` @ `minimax` (anthropic endpoint) | `minimax-direct`/M2.7         | Will become `minimax-direct`/M3, drop 1st FB |
| grcexpert  | `moonshotai/kimi-k2.6` @ `canopywave`        | `minimax-direct`/M2.7         | Will become `minimax-direct`/M3, no canopywave |
| codereviewer| `moonshotai/kimi-k2.6` @ `canopywave`       | `minimax-direct`/M2.7         | Will become `minimax-direct`/M3, no canopywave |
| expertcoder| `moonshotai/kimi-k2.6` @ `canopywave`        | `minimax-direct`/M2.7         | Will become `minimax-direct`/M3, no canopywave |
| maartenwriter| `moonshotai/kimi-k2.6` @ `canopywave`      | `minimax-direct`/M2.7         | Will become `minimax-direct`/M3, no canopywave |

## Target state

```yaml
model:
  default: MiniMax-M3
  provider: minimax-direct
  base_url: https://api.minimax.io/v1
  api_key: sk-cp-3iBw0l1aigoVMjZKGxyxNHlwwO-ItyBi5Hv5nmNHX6vJEEveqQ5oT-E_9UEdet6Aga4wal2jiZwrIoSKr7o9wU7PJpT0hUn9A2BsVqBFVJpPSsst327CcCY
  context_length: 256000

custom_providers:
- name: minimax-direct
  base_url: https://api.minimax.io/v1
  api_key: sk-cp-3iBw0l1aigoVMjZKGxyxNHlwwO-ItyBi5Hv5nmNHX6vJEEveqQ5oT-E_9UEdet6Aga4wal2jiZwrIoSKr7o9wU7PJpT0hUn9A2BsVqBFVJpPSsst327CcCY
  model: MiniMax-M3
- name: deepseek-direct
  base_url: https://api.deepseek.com/v1
  api_key: sk-f02e65d5be14486383e84194241aee47
- name: fatman:11434
  base_url: http://fatman:11434/v1
  api_key: ollama
  model: qwen3.6:27b-mxfp8
- name: freellmapi
  base_url: http://localhost:3001/v1
  api_key: freellmapi-26ecac0ac1285650d9860c9727614d11c4d8550b8317b22c
  model: auto

fallback_providers:
- provider: freellmapi
  model: auto
  base_url: http://localhost:3001/v1
  api_key: freellmapi-26ecac0ac1285650d9860c9727614d11c4d8550b8317b22c
- provider: deepseek-direct
  model: deepseek-v4-pro
  base_url: https://api.deepseek.com/v1
  api_key: sk-f02e65d5be14486383e84194241aee47
- provider: fatman:11434
  model: qwen3.6:27b-mxfp8
  base_url: http://fatman:11434/v1
  api_key: ollama
  timeout: 300
```

**All 5 profile configs become identical** in the model/fallback/custom_providers sections. Only `agent.max_turns`, `agent.reasoning_effort`, and personalities may differ.

## Execution phases

### Phase 1 — Backup (no side effects beyond disk)

- `cp ~/.hermes/config.yaml ~/.hermes/config.yaml.bak-pre-canopywave-removal-2026-06-01`
- For each of 4 profiles: `cp profiles/<name>/config.yaml profiles/<name>/config.yaml.bak-pre-canopywave-removal-2026-06-01`
- `cp ~/.hermes/auth.json ~/.hermes/auth.json.bak-pre-canopywave-removal-2026-06-01`
- `cp "vault/05 - AI/99 - Hermes/config.yaml" "vault/05 - AI/99 - Hermes/config.yaml.bak-pre-canopywave-removal-2026-06-01"`

### Phase 2 — Edit 5 profile configs (live, then mirror)

For `~/.hermes/config.yaml` and `~/.hermes/profiles/{grcexpert,codereviewer,expertcoder,maartenwriter}/config.yaml`:

- Replace `model:` block → target state above
- Replace `custom_providers:` block → target state (4 entries, no canopywave)
- Replace `fallback_providers:` block → target state (3 entries: freellmapi → deepseek → fatman)
- Update `model.default: MiniMax-M3` (was `moonshotai/kimi-k2.6` for 4 specialists, was `MiniMax-M3` for default but with wrong provider)
- Update `model.provider: minimax-direct` (was `canopywave` for 4, was `minimax` for default)

### Phase 3 — Mirror to vault (per COMMIT GATE)

```bash
rsync -av --delete ~/.hermes/ "<vault>/05 - AI/99 - Hermes/"
rm -f "<vault>/05 - AI/99 - Hermes/state.db"*
rm -rf "<vault>/05 - AI/99 - Hermes/state-snapshots/"
```

### Phase 4 — Documentation updates in vault

Files to edit (no creation, no deletion — patch in place):

1. `05 - AI/08 - Model Notes/Model Configuration.md`
   - Update callout: "ALL 5 profiles unified. Primary: minimax-direct / MiniMax-M3. 3-tier cascade..."
   - Update "Current Active Configuration" block
   - Update Primary Model table
   - Update Custom Providers list (remove canopywave, change minimax-direct model to M3)
   - Update Fallback Cascade (3-tier: freellmapi → deepseek → fatman)
   - Update Profiles table
   - Update Auxiliary Curator section (no change requested — leave deepseek-direct)
   - Update .env section (remove canopywave key reference)
   - Update "How to Change Model" examples
   - Update Reimplementation Checklist
   - Update updated: 2026-06-01 timestamp

2. `05 - AI/03 - Personas/Hermes Agent Profiles.md`
   - Update callout
   - Update Profile Overview table (model/provider column for all 5 rows)
   - Update 5-Tier Failover block (rename to 3-Tier, new chain)
   - Update updated: 2026-06-01 timestamp

3. `05 - AI/99 - Hermes/SOUL.md` (vault mirror copy)
   - Lines 23-26: change delegate_task examples from `model="moonshotai/kimi-k2.6", provider="canopywave"` to `model="MiniMax-M3", provider="minimax-direct"`

4. `05 - AI/08 - Model Notes/Model Configuration 2.md` (the older companion doc)
   - Search and replace primary provider and M2.7 references

5. `05 - AI/Dev/gateway-fallback-fix.md`
   - Update cascade description (3-tier, M3 primary)

6. `05 - AI/Dev/use-case-7/implementation-plan.md`
   - Update Profile Routing Matrix table
   - Update Prerequisite note

### Phase 5 — Cache files (best-effort cleanup)

- `05 - AI/99 - Hermes/provider_models_cache.json` — search and remove canopywave entries
- `05 - AI/99 - Hermes/ollama_cloud_models_cache.json` — same
- `05 - AI/99 - Hermes/models_dev_cache.json` — same
- `05 - AI/99 - Hermes/context_length_cache.yaml` — same

If any of these is a regenerable artifact, it's safer to delete and let Hermes rebuild on next use than to hand-edit. Decision: **delete them** (they regenerate). This is a soft operation; the worst case is a one-time slower first run.

### Phase 6 — Commit gate (MANDATORY order — do not deviate)

```bash
# 6a. vault first (authoritative)
cd "<vault>"
git add "05 - AI/99 - Hermes/" "05 - AI/08 - Model Notes/" "05 - AI/03 - Personas/" "05 - AI/Dev/"
git status  # verify only expected files
git commit -m "reconfig: primary = minimax-direct/MiniMax-M3, remove canopywave

- 5 profile configs now use minimax-direct/MiniMax-M3 primary
- Fallback chain: freellmapi/auto -> deepseek-v4-pro -> fatman/qwen3.6:27b
- Custom providers: removed canopywave
- Docs updated: Model Configuration, Profiles, SOUL, gateway-fallback-fix, use-case-7
- Cache files cleared (will rebuild on next model discovery)"
git push origin main

# 6b. hermes-config second (convenience backup)
cd ~/.hermes
git add config.yaml profiles/*/config.yaml
git status  # verify
git commit -m "reconfig: primary = minimax-direct/MiniMax-M3, remove canopywave"
git push origin main
```

### Phase 7 — Persistent memory update

Use `hindsight_retain` to update the cross-session memory line about the model chain:

> "Hermes: 3-tier chain — minimax-direct/MiniMax-M3 → freellmapi/auto → deepseek-direct/deepseek-v4-pro → fatman:11434/qwen3.6:27b-mxfp8. canopywave DISCONTINUED 2026-06-01. ⛔COMMIT GATE: (1)rsync→vault FIRST (2)rm state.db* (3)push vault (4)push hermes-config. Gate in SOUL.md+prefill+skill+hook. Agent bypassed May23+May28 — NEVER AGAIN."

Also update the `memory` block in SOUL via the memory tool.

### Phase 8 — Smoke test (do NOT skip)

```bash
# Validate YAML
python3 -c "import yaml; yaml.safe_load(open('$HOME/.hermes/config.yaml'))" && echo "YAML OK"
for p in grcexpert codereviewer expertcoder maartenwriter; do
  python3 -c "import yaml; yaml.safe_load(open('$HOME/.hermes/profiles/$p/config.yaml'))" && echo "$p YAML OK"
done

# Connectivity smoke (just to the new primary, since other 3 endpoints already known)
curl -s -o /dev/null -w "minimax-direct: %{http_code}\n" \
  -H "Authorization: Bearer sk-cp-3iBw0l1aigoVMjZKGxyxNHlwwO-ItyBi5Hv5nmNHX6vJEEveqQ5oT-E_9UEdet6Aga4wal2jiZwrIoSKr7o9wU7PJpT0hUn9A2BsVqBFVJpPSsst327CcCY" \
  "https://api.minimax.io/v1/models"
```

## What this plan WILL NOT do

- ❌ Will NOT touch any customer vault content (`10 - Customers/*`).
- ❌ Will NOT touch cron `output/*` (historical logs).
- ❌ Will NOT touch `config.yaml.bak-*` (those are backups).
- ❌ Will NOT change `auxiliary.curator.provider` (currently `deepseek-direct` — outside scope).
- ❌ Will NOT touch the 17 cron jobs in `cron/jobs.json` (they inherit active profile config; no per-job provider pins found).
- ❌ Will NOT change `.env` (no canopywave references — already clean).
- ❌ Will NOT touch `~/.hermes/SOUL.md` (the agent's own SOUL — your own prior instructions take precedence over my docs about it; the doc-only `05 - AI/99 - Hermes/SOUL.md` is updated instead).
- ❌ Will NOT touch `prefill.txt` (no model references).
- ❌ Will NOT restart the gateway (Maarten does that manually when ready — `hermes gateway restart`).

## Risks identified

1. **Gateway is running with the current config in memory.** A live agent session will keep using the old config until restart. After this plan completes, the next agent session will pick up the new config. If the user wants the change to take effect immediately for the current session, that's not possible (would need gateway restart, which is explicitly out of scope).

2. **17 cron jobs run scheduled.** They will pick up the new config on their next tick (each job spawns a fresh agent process). This is the desired behavior.

3. **YAML structural changes** could break parsing if indentation is off. The patch tool uses fuzzy matching, which is forgiving. Each edit will be reviewed with `read_file` after to confirm.

4. **Cache file deletion is irreversible but self-healing.** On next model discovery, Hermes rebuilds. No data loss.

5. **Provider_models_cache.json etc. may be auto-regenerated on next use** — if so, deleting them is the right move.

6. **Memory block update via hindsight_retain** — the new chain entry must replace the old one. Will use `replace` action to update the existing entry.

## Verification checklist (run after Phase 6)

- [ ] `~/.hermes/config.yaml` parses, has minimax-direct/M3 primary, no canopywave, 3-tier fallback
- [ ] All 4 profile configs parse, same structure
- [ ] `05 - AI/99 - Hermes/config.yaml` matches live (via rsync)
- [ ] `05 - AI/99 - Hermes/state.db*` and `state-snapshots/` removed from mirror
- [ ] `05 - AI/99 - Hermes/SOUL.md` reflects new model in delegate_task examples
- [ ] `05 - AI/08 - Model Notes/Model Configuration.md` reflects new chain
- [ ] `05 - AI/03 - Personas/Hermes Agent Profiles.md` reflects new chain
- [ ] `05 - AI/Dev/gateway-fallback-fix.md` references 3-tier with M3
- [ ] `05 - AI/Dev/use-case-7/implementation-plan.md` references M3
- [ ] No `canopywave` or `kimi-k2.6` in vault (grep verification)
- [ ] No `MiniMax-M2.7` in vault (grep verification)
- [ ] No `canopywave` or `kimi-k2.6` in `~/.hermes/` configs (grep verification)
- [ ] No `MiniMax-M2.7` in `~/.hermes/` configs (grep verification)
- [ ] Vault committed and pushed
- [ ] hermes-config committed and pushed
- [ ] Persistent memory updated
- [ ] Minimax-direct /v1/models curl returns 200

## Approval

Awaiting user "approved" before execution.
