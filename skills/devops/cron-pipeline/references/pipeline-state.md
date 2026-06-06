# Cron Pipeline State

> Last refreshed: 2026-06-06 19:30 from `cron list` (post-gateway-restart audit).

## Full Pipeline (Execution Order)

| Time | Job ID | Name | Type | Last Status |
|---|---|---|---|---|
| 02:00 daily | `ee8485f40c09` | Providers Patch Drift Check | no-agent script | ok (drift auto-repaired 2026-06-06) |
| 03:00 daily | `b264e586aa4d` | GraphWeaver — MOC Integrity Audit | agent | ok |
| 04:00 daily | `7cfde4ccf71b` | Morning Briefing — Email + Daily Note | agent | error: RuntimeError: Request timed out. (2026-06-04, last attempt) |
| 04:00 daily | `ed19aa143e47` | Cron Output Rotation | no-agent script | ok (2026-06-06 11:56) |
| 05:00 daily | `30df09d5ffd9` | Graphify Incremental Update | no-agent script | first run 2026-06-07 05:00 (newly wired) |
| 05:00 Sundays | `af4f4b4299d5` | Graphify Weekly Full Rebuild | no-agent script | first run 2026-06-07 05:00 (newly wired; weekly on Sun) |
| 06:00 daily | `2ebe21e75e8a` | Meeting Brief Generator | agent | error: RuntimeError: Request timed out. (2026-06-04, last attempt) |
| 06:20 daily | `4d1be69dd3f7` | Backlink Curator | no-agent script | ok |
| 07:00 Mondays | `7eef85853197` | Invoice & Payment Tracker | agent | ok |
| 08:00 Mondays | `061e346ad4a6` | Content Pipeline — Monday Horizon Review | agent | ok |
| 08:00 Tuesdays | `5bdd3c84e4f9` | Content Pipeline — Tuesday Draft | agent | ok |
| 08:00 Wednesdays | `9cd866abf255` | Content Pipeline — Wednesday Draft | agent | ok |
| 08:00 Thursdays | `5ee7408260d8` | Content Pipeline — Thursday Schedule | agent | error: RuntimeError: Request timed out. (2026-06-04, last attempt) |
| 08:00 Fridays | `3d249b60776d` | Content Pipeline — Friday Review | agent | ok |
| 09:00 daily | `7a4e2eab7e53` | Monthly Invoice Preparation | agent | ok |
| 09:00 daily | `10baf3e4afff` | Content Pipeline — Daily Health Check | agent | error: RuntimeError: Request timed out. (2026-06-04, last attempt) |
| 14:00 Thursdays | `47d68aef719e` | Content Pipeline — Thursday Replenishment | agent | ok |
| 15:00 Fridays | `e4010278f409` | Weekly Rollup | agent | ok |
| 17:00 daily | `924256021e15` | Evening Timesheet Pre-Fill | agent | ok (no fires 2026-06-05/06; gateway was down) |
| 17:15 daily | `298f69225172` | JIRA Update Pre-Fill | agent | ok (no fires 2026-06-05/06; gateway was down) |

## 2026-06-06 audit findings

**Gateway was down** (`/Library/LaunchAgents/ai.hermes.gateway.plist` not loaded) from approximately 2026-06-04 17:21 through 2026-06-06 18:49 (about 49 hours). No cron jobs fired during that window. Started gateway via `hermes gateway start` (PID 39390, currently running). Home Assistant platform unreachable but non-blocking; cron ticker started at 60s interval. Telegram connected.

**4 stale-error jobs (need re-test on next tick):** Morning Briefing, Meeting Brief, Content Pipeline Thursday Schedule, Content Pipeline Daily Health Check. All ran fine on 2026-06-03 and earlier; the 2026-06-04 errors are `RuntimeError: Request timed out.` (likely transient — possibly gateway degradation). These will re-fire tonight/tomorrow now that the gateway is up; if they time out again the cause is not the gateway.

**3 never-run jobs (newly wired):** Providers Patch Drift Check, Graphify Incremental, Graphify Weekly Full Rebuild. All three are no-agent script jobs that depend on the gateway ticking. First scheduled fires:
- Providers Patch Drift: 2026-06-07 02:00
- Graphify Incremental: 2026-06-07 05:00
- Graphify Weekly: 2026-06-07 05:00 (Sun) — note: 2026-06-07 is a Sunday

**Providers Patch Drift — actual drift detected 2026-06-06.** While auditing, ran `~/.hermes/scripts/check-providers-patch.sh` manually: drift detected (the `get_provider()` plugin fall-through patch in `~/.hermes/hermes-agent/hermes_cli/providers.py` was missing — likely reverted by an earlier `hermes update` or `git pull`). Watchdog auto-reapplied the patch (48 lines added) and the smoke test passed (`get_provider('minimax-direct')` resolves via plugin). Second run exits 0 (healthy). File is modified in the hermes-agent working tree but NOT committed by the user (per "you do know I am no developer of hermes" — drift-detect-and-repair is the design; the next `hermes update` will revert it again, the watchdog will catch it again).

## No-agent watchdogs

| Time | Job ID | Name | Script | Purpose |
|---|---|---|---|---|
| 02:00 daily | `ee8485f40c09` | Providers Patch Drift Check | `~/.hermes/scripts/check-providers-patch.sh` | Detects if the `get_provider()` plugin fallthrough patch in `hermes_cli/providers.py` was reverted (e.g., by `git pull` from upstream NousResearch). On drift: auto-reapplies via `git apply`, runs a Python smoke test (`get_provider('minimax-direct')` must return a ProviderDef), delivers an alert. See `fork-upstream-patching` skill for the pattern. |
| 04:00 daily | `ed19aa143e47` | Cron Output Rotation | `~/.hermes/scripts/cron_output_rotate.sh` | Deletes cron output `.md` files older than 7 days. Vault source at `<vault>/scripts/cron_output_rotate.sh`. |
| 05:00 daily | `30df09d5ffd9` | Graphify Incremental Update | `~/.hermes/scripts/graphify_incremental.sh` | Re-runs `graphify update` on `/Volumes/LLM/Git` (AST only, no LLM). Vault sources: `<vault>/scripts/graphify_incremental.sh` (bash orchestrator) + `<vault>/scripts/graphify_kimi_runner.py` (Python runner that sets `ANTHROPIC_BASE_URL=https://api.kimi.com/coding`, patches `BACKENDS["claude"]["default_model"]="kimi-k2.6"` in-process, then invokes `graphify update` via subprocess). Degraded-cron guard (48h stall → skip). Single-instance lock via `mkdir` (POSIX-atomic). See `05 - AI/02 - Workflows/Graphify Setup.md`. |
| 05:00 Sundays | `af4f4b4299d5` | Graphify Weekly Full Rebuild | `~/.hermes/scripts/graphify_weekly_rebuild.sh` | Full re-pipeline: `graphify update` (AST) + `graphify cluster-only . --no-viz --backend=claude` (clustering + LLM community naming). Same runner path. The cluster-only step runs in-process (subprocess boundary loses the BACKENDS patch). |

## Pipeline-state staleness — honest answer

**No, this reference will not stay current without a script.** It is hand-written from the live `cron list` output. Every cron change (create/update/remove), every gateway incident, every drift detection should be reflected here. Without an automated hook, it will be stale the moment the next change happens. A mechanical fix: add a small no-agent cron job that runs `hermes cron list --json | jq ... > ~/.hermes/skills/devops/cron-pipeline/references/pipeline-state.md` after every cron state mutation. **Not implemented yet** — pending user approval. Until then, treat the table above as "accurate as of 2026-06-06 19:30" and run `hermes cron list` to confirm before any pipeline change.

## Provider/config note

No listed cron job pins a provider/model/base_url. All agent-backed jobs inherit the active profile/runtime provider chain. Current first-class provider-plugin fallbacks are documented in `05 - AI/08 - Model Notes/Model Configuration.md`; do not hard-code retired config-only provider slugs in cron prompts or cron documentation.

## Maintenance Rules

- Always run `cron list` before updating, removing, or creating jobs.
- After any cron change, refresh this file from the live list.
- Existing jobs use `deliver: local`; do not switch to `origin` unless explicitly requested.
- For drift watchdogs on fork patches, schedule 1–2 hours before the user's first daily use. For this user, that's 02:00 — well before the 04:00 morning briefing. See `fork-upstream-patching` skill §4.
- **Vault/hermes-config direction for cron/jobs.json:** edits happen in hermes-config (live scheduler reads from `~/.hermes/cron/jobs.json`); commit there. Then rsync to vault mirror at `<vault>/05 - AI/99 - Hermes/cron/jobs.json` **without `--delete`** for the `output/` subdirectory — those are runtime log files that should be left alone (using `--delete` on 2026-06-06 destroyed 3 live `.md` log files).
