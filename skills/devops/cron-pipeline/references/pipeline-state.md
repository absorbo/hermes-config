# Cron Pipeline State

> Last refreshed: 2026-06-04 from `cronjob(action='list')`.

## Full Pipeline (Execution Order)

| Time | Job ID | Name | Skills | Deliver | Toolsets | Last Status |
|---|---|---|---|---|---|---|
| 02:00 daily | `ee8485f40c09` | Providers Patch Drift Check | (none) | local | (no_agent script) | ok |
| 03:00 daily | `b264e586aa4d` | GraphWeaver — MOC Integrity Audit | obsidian, obsidian-markdown | local | terminal, file, skills | ok |
| 04:00 daily | `7cfde4ccf71b` | Morning Briefing — Email + Daily Note | obsidian, obsidian-markdown, google-workspace, m365-graph | local | terminal, file, skills, web | ok |
| 05:00 daily | `0367b795f472` | Eisenhower Task Prioritizer | obsidian, obsidian-markdown | local | file, skills | ok |
| 06:00 daily | `2ebe21e75e8a` | Meeting Brief Generator | obsidian, obsidian-markdown, m365-graph, google-workspace | local | not pinned | ok |
| 06:20 daily | `4d1be69dd3f7` | Backlink Curator | script-only | local | terminal | ok |
| 07:00 Mondays | `7eef85853197` | Invoice & Payment Tracker | obsidian, obsidian-markdown, m365-graph, google-workspace, ocr-and-documents | local | not pinned | ok |
| 08:00 Mondays | `061e346ad4a6` | Content Pipeline — Monday Horizon Review | obsidian, obsidian-markdown, profile-routing | local | file, terminal, skills | ok |
| 08:00 Tuesdays | `5bdd3c84e4f9` | Content Pipeline — Tuesday Draft | obsidian, obsidian-markdown, profile-routing | local | file, terminal, skills, web | ok |
| 08:00 Wednesdays | `9cd866abf255` | Content Pipeline — Wednesday Draft | obsidian, obsidian-markdown, profile-routing | local | file, terminal, skills, web | ok |
| 08:00 Thursdays | `5ee7408260d8` | Content Pipeline — Thursday Schedule | obsidian, obsidian-markdown | local | file, terminal, skills | ok |
| 08:00 Fridays | `3d249b60776a` | Content Pipeline — Friday Review | obsidian, obsidian-markdown, profile-routing | local | file, terminal, skills, browser | ok |
| 09:00 daily | `7a4e2eab7e53` | Monthly Invoice Preparation | obsidian, obsidian-markdown | local | terminal, file, skills | ok |
| 09:00 daily | `10baf3e4afff` | Content Pipeline — Daily Health Check | obsidian, obsidian-markdown | local | file, terminal, skills | ok |
| 14:00 Thursdays | `47d68aef719e` | Content Pipeline — Thursday Replenishment | obsidian, obsidian-markdown, profile-routing | local | file, terminal, skills, web | ok |
| 15:00 Fridays | `e4010278f409` | Weekly Rollup | obsidian, obsidian-markdown, m365-graph, google-workspace | local | terminal, file, skills | ok |
| 17:00 daily | `924256021e15` | Evening Timesheet Pre-Fill | obsidian, obsidian-markdown | local | terminal, file, skills | ok |
| 17:15 daily | `298f69225172` | JIRA Update Pre-Fill | obsidian, obsidian-markdown | local | terminal, file, skills | ok |

## No-agent watchdogs

| Time | Job ID | Name | Script | Purpose |
|---|---|---|---|---|
| 02:00 daily | `ee8485f40c09` | Providers Patch Drift Check | `~/.hermes/scripts/check-providers-patch.sh` | Detects if the `get_provider()` plugin fallthrough patch in `hermes_cli/providers.py` was reverted (e.g., by `git pull` from upstream NousResearch). On drift: auto-reapplies via `git apply`, runs a Python smoke test (`get_provider('minimax-direct')` must return a ProviderDef), delivers an alert. See `fork-upstream-patching` skill for the pattern. |

## Provider/config note

No listed cron job pins a provider/model/base_url. All agent-backed jobs inherit the active profile/runtime provider chain. Current first-class provider-plugin fallbacks are documented in `05 - AI/08 - Model Notes/Model Configuration.md`; do not hard-code retired config-only provider slugs in cron prompts or cron documentation.

## Maintenance Rules

- Always run `cronjob(action='list')` before updating, removing, or creating jobs.
- After any cron change, refresh this file from the live list.
- Mirror `~/.hermes/cron/jobs.json` and this reference to the vault before commit.
- Existing jobs use `deliver: local`; do not switch to `origin` unless explicitly requested.
- For drift watchdogs on fork patches, schedule 1–2 hours before the user's first daily use. For this user, that's 02:00 — well before the 04:00 morning briefing. See `fork-upstream-patching` skill §4.
