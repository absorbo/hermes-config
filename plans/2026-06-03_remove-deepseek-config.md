---
plan_id: 2026-06-03_remove-deepseek-config
created: 2026-06-03
status: executed
approved_by: user (response: "A, B, C, G")
---

# Plan: Remove deepseek model configuration

## Scope (user-approved)
- A: live `~/.hermes/` config
- B: ALL skills (chain docs AND research/red-team)
- C: active vault docs in `05 - AI/` (non-skill, non-session)
- G: auto-regenerated cache

## KEEP (per user direction)
- D: session history JSONs
- E: upstream Hermes Agent source + release notes
- F: research skills about DeepSeek as model family (overlaps with B — user override said remove all of B)

## Execution Summary
- A: 7 live config files (5 config.yaml + .env + auth.json)
- A (profile skills): 5,651 files in `~/.hermes/profiles/*/skills/` + 10 in `~/.hermes/skills/`
- B: 10 skill files (incl. 2 .py scripts in godmode) — line-level removal of "deepseek" mentions
- C: 5 vault docs in `05 - AI/` outside the mirror
- G: 16 cache files deleted (auto-regenerate)
- Memory files updated: `~/.hermes/memories/MEMORY.md` and `profiles/expertcoder/memories/MEMORY.md`

## Verification
- All 5 config.yaml files: 0 deepseek mentions, YAML valid
- All custom_providers lists: 3 entries (minimax-direct, freellmapi, fatman:11434) — no deepseek-direct
- All fallback_providers lists: 2 entries (freellmapi, fatman:11434) — no deepseek-direct
- Skills (both ~/.hermes and vault mirror): 0 deepseek mentions
- Vault docs (05 - AI/): 0 deepseek mentions in scope

## Commits
- clawbot-vault: `99b98e70` — 55 files, +14 / -412
- hermes-config: `bc990e2` — 3 files (auth.json, .skills_prompt_snapshot.json, ollama_cloud_models_cache.json)

## Unrelated changes detected (NOT my doing)
- `~/.hermes/config.yaml` (default profile) model.default changed from `MiniMax-M3`/`minimax-direct` to `moonshotai/kimi-k2.6`/`novita`
- `~/.hermes/config.yaml` auxiliary.curator block re-appeared with `provider: auto, model: ''`
- These changes appeared during this session, presumably from another process
- Not committed; left for user to review

## Notes for future agent
- `~/.hermes/skills/...` and `~/.hermes/profiles/*/skills/...` are SEPARATE copies — must patch BOTH
- Profile skills in `~/.hermes/profiles/<name>/skills/` are NOT mirrored to vault directly; they go through `~/.hermes/skills/...` after rsync
- Python scripts in skills need line-level removal (not just .md)
- Cache files auto-regenerate; deletion is safe but commit may be transient
- In-session memory file `~/.hermes/memories/MEMORY.md` is the persistent source — `memory` tool uses a different storage format
