---
name: profile-routing
description: Route tasks to the correct specialist Hermes profile. The default agent MUST delegate domain-specific work to the appropriate profile rather than handling it directly. Self-maintaining — updates when profiles change.
version: 1.3.0
domain: hermes-operations
tags:
  - profiles
  - delegation
  - routing
  - multi-agent
  - self-maintaining
---

# Profile Routing — Mandatory Delegation Rules

## Prime Directive

**The default Hermes agent MUST delegate domain-specific tasks to the appropriate specialist profile. NEVER handle a specialist task directly when a profile exists for it. This is not optional.**

## Current Profile Landscape

**Verified 2026-06-03:** only two specialist profile directories remain under `~/.hermes/profiles/`: `grcexpert` and `maartenwriter`. The `codereviewer` and `expertcoder` profiles were removed via the Hermes dashboard. Code review and coding tasks currently fall back to the default orchestrator unless a new specialist profile is created.

**Current models and providers** — read from live configs, do NOT duplicate here:

```bash
python3 - <<'PY'
import yaml
from pathlib import Path
for f in [Path.home()/'.hermes/config.yaml', *sorted((Path.home()/'.hermes/profiles').glob('*/config.yaml'))]:
    data = yaml.safe_load(f.read_text()) or {}
    print(f.parent.name if 'profiles' in str(f) else 'default', data.get('model'))
PY
```

| Profile | Alias | Skills | Specialization |
|---------|-------|--------|---------------|
| `grcexpert` | `grcexpert` | run `~/.hermes/skills/autonomous-ai-agents/profile-routing/scripts/count-skills.sh grcexpert` | GRC, cybersecurity, NIS2, risk management, compliance, audit, policy authoring |
| `maartenwriter` | `maartenwriter` | run `~/.hermes/skills/autonomous-ai-agents/profile-routing/scripts/count-skills.sh maartenwriter` | Creative writing, novel chapters, continuity, editing, humanizing, narrative |
| `default` | — | run `~/.hermes/skills/autonomous-ai-agents/profile-routing/scripts/count-skills.sh default` | General tasks, orchestration, routing, system administration, code tasks when no specialist exists |

**Fallback chains** — read from the same configs above (`fallback_providers` field). Do not cache in documentation.

All profiles use `api_max_retries: 1` for fast failover. Each fallback tier gets a single retry before the chain moves to the next tier.

See `references/model-failover-testing.md` for diagnostic procedures, `references/adding-fallback-providers.md` for the workflow to add or reorder providers in the chain, `references/minimax-direct-provider.md` for the MiniMax direct API setup and key requirements, and `references/check-failover-health-script.md` for the **read-only, no-hardcoded-values** contract that the verification script must follow.

**To smoke-test the entire chain:** run `scripts/test-fallback-chain.sh` — it reads config.yaml, extracts all keys, and tests every tier with curl.

**⚠️ Pitfall — profile configs and provider plugins MUST be verified per profile:**
Profile configs are independent. When adding or renaming a provider in `fallback_providers`, update EVERY profile config (`~/.hermes/profiles/*/config.yaml`) and verify the provider is resolvable from that profile's `HERMES_HOME`. If the provider is represented by a first-class model-provider plugin, make sure the profile can discover that plugin and use the plugin slug consistently (for example `fatman-ollama`, not the old config-only slug `fatman:11434`). Do not reintroduce inline secret-bearing `custom_providers` blocks for recurring endpoints unless the user explicitly requests that older pattern. After any fallback chain change, run a consistency check across all profiles.

**⚠️ Pitfall — config-file change does NOT change the running session.**
Editing `~/.hermes/config.yaml` (or any profile's config.yaml) is a DISK change. The gateway process loaded the old config at startup and continues to use it until `hermes gateway restart` is run. The "Model:" and "Provider:" fields in the system prompt show the **gateway's runtime state**, not the file. After any primary model/provider change, ALWAYS run `hermes gateway restart` and confirm with `hermes doctor` and `hermes config get model.default`. The 2026-06-03 session left the user on the old model for one turn because this was missed — the next turn was the first on the new primary. The user explicitly noted: "why are you on kimi-k2? you should be on minimax-m3!!!!! WHAT THE FUCK DID YOU BREAK NOW!!!!!!!!"

**⚠️ Pitfall — `check-failover-health.sh` must READ configs, not assert fixed values.**
The verification script under `scripts/` must extract `model.provider` and `model.default` from `config.yaml` and print what the live config says. It must NEVER hardcode `openai-codex/gpt-5.5` (or any other expected primary) and emit FAIL on mismatch. Hardcoding creates a script that lies about state and forces a code change on every model switch. The right pattern: parse configs, print findings, exit non-zero only on discovery failure (missing plugin) or parse error (broken YAML), not on policy preference. See `references/check-failover-health-script.md` for the full contract.

**To verify which model/provider is currently active** (when the user asks "what model are we on?"):
```bash
hermes config get model.default && hermes config get model.provider
```

**To check the CURRENT SESSION's actual model** (what the gateway handed the agent): look at the "Conversation started" metadata in the system prompt (`Model:` and `Provider:` fields). This is the ground truth of what the current turn is running on.

## Domain → Profile Mapping

When the user's request falls into ANY of these domains, DELEGATE to the matching profile. Do NOT handle directly.

### → grcexpert (model/provider read from config — see command above)

**ALWAYS delegate when the task involves:**

- GRC (Governance, Risk, Compliance) frameworks — CyFUN, NIS2, ISO 27001, NIST CSF
- Cybersecurity policy authoring, review, or gap analysis
- Risk assessment, risk treatment, risk management
- Security audit preparation, evidence collection, audit readiness
- Vulnerability management policy and process
- Incident response planning and playbooks
- Information classification, data protection impact assessments
- Supplier/vendor security assessment
- Customer cybersecurity frameworks defined in vault under `10 - Customers/`
- CyFUN OD/DR code mapping and compliance
- Security awareness and training program design
- Business continuity and disaster recovery planning (security context)
- Any task involving cybersecurity skills in the profile
- Customer-specific GRC/cybersecurity/compliance/NIS2 questions

**Before delegating:** if a customer has a prefill chain, context MOC, or overview file, read it first and include the path in the delegation context.

**Delegation method:**
```
delegate_task(
    goal="<specific GRC/cybersecurity task>",
    context="<all relevant file paths, vault sections, and constraints>",
    model="<profile's model — read from config>",
    provider="<profile's provider — read from config>",
    toolsets=["terminal", "file", "web", "search", "skills", "session_search", "obsidian", "note-taking"]
)
```

For complex multi-step GRC tasks, use terminal spawn:
```
terminal(command="hermes --profile grcexpert chat -q '<self-contained prompt>'", timeout=300)
```

### → maartenwriter (model/provider read from config — see command above)

**ALWAYS delegate when the task involves:**

- Creative writing: novel chapters, scenes, dialogue, narrative prose
- Continuity tracking, character development, plot structuring
- Editing for voice, tone, and style (not technical editing)
- Humanizing AI-generated text into natural prose — **always load the `avoid-ai-writing` skill** for AI-ism detection and removal
- Writing in specific literary styles or authorial voices
- Any task in a creative writing vault workspace
- Story outlining, worldbuilding, character bios
- Translation with stylistic intent (not just literal)

**Delegation method:**
```
delegate_task(
    goal="<specific writing task>",
    context="<vault paths, style guides, continuity notes, character references>",
    model="<profile's model — read from config>",
    provider="<profile's provider — read from config>",
    toolsets=["terminal", "file", "web", "search", "skills", "obsidian", "note-taking"]
)
```

### → default (handle directly)

Only handle directly when the task is:
- General conversation, questions, explanations
- System administration, file operations, terminal commands
- Orchestration — delegating to other profiles (this is your primary role)
- Research that doesn't fall into a specialist domain
- Configuration changes to Hermes itself
- Tasks that span multiple domains (break into subtasks, delegate each)

## Anti-Patterns — NEVER Do These

1. **NEVER write cybersecurity policy directly** — delegate to grcexpert
2. **NEVER write creative prose/chapters directly** — delegate to maartenwriter
3. **NEVER do GRC gap analysis directly** — delegate to grcexpert
4. **NEVER edit creative writing for style/voice directly** — delegate to maartenwriter
5. **NEVER say "I can handle this" when a specialist profile exists** — DELEGATE

## Delegation Mechanism Reference

### delegate_task (preferred for most cases)

Lightweight, synchronous. Use when the task is well-scoped and can be completed in a single turn.

```
delegate_task(
    goal="One-sentence task description",
    context="File paths, constraints, relevant background",
    model="<profile's model>",
    provider="<profile's provider>",
    toolsets=["terminal", "file", "web", "search"]
)
```

- ✅ Best for: focused reviews, assessments, research, single-file analysis
- ✅ Subagent returns summary — context stays lean
- ⚠️ Subagent has NO access to profile's skills — specify relevant toolsets
- ⚠️ Not durable — if interrupted, work is lost

### terminal spawn (for complex multi-step tasks)

Full profile context with all skills, SOUL, config.

```
terminal(command="hermes --profile grcexpert chat -q '<self-contained prompt>'", timeout=600, background=true, notify_on_complete=true)
```

- ✅ Best for: complex policy authoring, multi-file analysis, audit preparation
- ✅ Full profile context — all skills, SOUL, memory
- ⚠️ Heavier — full Hermes instance startup
- ⚠️ Use `background=true, notify_on_complete=true` for long-running tasks

## Self-Maintenance Protocol

This skill MUST be kept current. After any of the following events, update this skill:

1. **New profile added** → Add to profile table + domain mapping + anti-patterns
2. **Profile removed** → Remove from table + mapping + anti-patterns
3. **Profile model/provider changed** → Update table + delegation method
4. **Profile specialization changed** → Update domain mapping + anti-patterns
5. **New specialist skills installed** → Update skill counts in the profile table + note in specialization description
6. **New skill collection deployed to all profiles** → Update ALL profile skill counts in the table

**Update command:**
```
skill_manage(action='patch', name='profile-routing', old_string='...', new_string='...')
```

After updating, also update the SOUL.md routing directive if the profile list changed. When profile directories are removed, verify the vault mirror is cleaned via rsync --delete.

**Skill deployment reference:** When installing skills from GitHub repos to all profiles, follow the verified pattern in `references/profile-skill-deployment.md`.

## Verification

Before any substantive action, the default agent must:

1. **Classify the task** — which domain(s) does it touch?
2. **Check the mapping** — does a specialist profile exist for this domain?
3. **If yes, DELEGATE** — choose delegate_task or terminal spawn based on complexity
4. **If no, handle directly** — but only after confirming no profile matches. As of 2026-06-03, this includes code review and coding tasks because `codereviewer` and `expertcoder` were removed.

## Customer Context Pre-fill Convention

When a specialist profile has a prefill that enforces reading a customer overview file (for example `<profile>/prefill.txt` enforces reading `10 - Customers/<Customer>/00-Overview.md` before any GRC/cybersecurity/compliance question), the delegation context MUST include that overview path and the chain `00-Overview.md → MOC → specific files`. This is profile- and customer-specific; check the destination profile's prefill before delegating.

## Shared Skill Library (all profiles)

These skills from `wondelai/skills` (creative/ category) are available to ALL agents and profiles. No specialist profile exists for design/product/strategy — the default agent handles these natively, loading the appropriate wondelai skill:

**UX/Design:** refactoring-ui, ios-hig-design, ux-heuristics, hooked-ux, improve-retention, web-typography, top-design, design-everyday-things, lean-ux, microinteractions

**Product/Strategy:** jobs-to-be-done, lean-startup, design-sprint, inspired-product, continuous-discovery, 37signals-way, mom-test, negotiation, crossing-the-chasm, blue-ocean-strategy, traction-eos, obviously-awesome

**Marketing/Sales:** cro-methodology, storybrand-messaging, scorecard-marketing, contagious, one-page-marketing, influence-psychology, predictable-revenue, made-to-stick, hundred-million-offers

**Code Quality/Architecture** (no dedicated code-review specialist profile currently exists): clean-code, refactoring-patterns, software-design-philosophy, pragmatic-programmer, domain-driven-design, ddia-systems, system-design, clean-architecture, release-it, high-perf-browser

**Other:** drive-motivation, avoid-ai-writing (creative/ category, v3.4.0, AI-ism removal)
