---
plan_id: 2026-06-03_remove-deepseek-config
created: 2026-06-03
status: approved
approved_by: user (response: "A, B, C, G")
scope: remove all deepseek model configuration from categories A, B, C, G
keep: D (session history), E (upstream Hermes Agent code), F (research skills — but B now subsumes F)
---

# Remove DeepSeek Configuration — A, B, C, G

## Scope (user-confirmed)

| Cat | What | Action | Files |
|-----|------|--------|-------|
| A | Live `~/.hermes/` config (config.yaml, profiles, .env, auth.json, prefill, SOUL, memory, cron jobs) | REMOVE | 7 |
| B | All skills (`~/.hermes/skills/` + vault mirror) | REMOVE all mentions | 10 |
| C | Vault docs (`05 - AI/`, non-skills, non-sessions) | REMOVE all mentions | 73 |
| G | Auto-regenerated cache | DELETE file | 1 |
| D | Session history JSONs | KEEP | 83 |
| E | Upstream `~/.hermes/hermes-agent/` | KEEP | 188 |
| F | Research skills | SUBSUMED by B (remove) | 6 |

Total modifications: 91 files (A: 7 + B: 10 + C: 73 + G: 1)

## Execution order

1. **Read** critical A files (config.yaml, profile configs, auth.json, .env, cron jobs) to understand YAML/JSON structure
2. **Patch A** surgically — remove provider blocks, fallback chain entries, env vars, auth entries
3. **Patch B** — edit `~/.hermes/skills/*` and vault mirror; remove deepseek mentions
4. **Patch C** — edit vault docs in `05 - AI/` excluding skills/ and sessions/
5. **Delete G** — remove `~/.hermes/cache/model_catalog.json` (regenerates)
6. **Verify** — re-scan A/B/C/G for zero hits
7. **Commit gate** — rsync `~/.hermes/` → vault → push vault → push hermes-config

## Safety

- No deletion of source files; only targeted line/block removal
- YAML/JSON modifications validated before commit
- `~/.hermes/hermes-agent/` (upstream) NOT touched
- Vault session JSONs NOT touched
- Each step verified before next step

## Out of scope

- D (session history) — historical record, keep
- E (upstream Hermes Agent code) — third-party, would break install
