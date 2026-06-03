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

This section is self-maintaining. When profiles are added, removed, or reconfigured, update this table and the domain mappings below.

**Verified 2026-06-03:** only two specialist profile directories remain under `~/.hermes/profiles/`: `grcexpert` and `maartenwriter`. The `codereviewer` and `expertcoder` profiles were removed via the Hermes dashboard. Code review and coding tasks currently fall back to the default orchestrator unless a new specialist profile is created.

| Profile | Model | Provider | Alias | Skills | Specialization |
|---------|-------|----------|-------|--------|---------------|
| `grcexpert` | MiniMax-M3 | minimax-direct | `grcexpert` | 939 (incl. 754 cybersecurity) | GRC, cybersecurity, CyFUN, NIS2, risk management, compliance, audit, policy authoring |
| `maartenwriter` | MiniMax-M3 | minimax-direct | `maartenwriter` | 185 (incl. 42 wondelai, 15 maestro, avoid-ai-writing) | Creative writing, novel chapters, continuity, editing, humanizing, narrative |
| `default` | gpt-5.5 | openai-codex | — | 188 (incl. 42 wondelai, avoid-ai-writing) | General tasks, orchestration, routing, system administration, code tasks when no specialist exists |

**Current failover system:**
- `default`: openai-codex / gpt-5.5 → minimax-direct / MiniMax-M3 → novita / moonshotai/kimi-k2.6 → freellmapi / auto → fatman-ollama / qwen3.6:35b-a3b-mlx-bf16
- `grcexpert`, `maartenwriter`: minimax-direct / MiniMax-M3 → novita / moonshotai/kimi-k2.6 → freellmapi / auto → fatman-ollama / qwen3.6:35b-a3b-mlx-bf16

All profiles use `api_max_retries: 1` for fast failover. Each fallback tier gets a single retry before the chain moves to the next tier.

See `references/model-failover-testing.md` for diagnostic procedures, `references/adding-fallback-providers.md` for the workflow to add or reorder providers in the chain, and `references/minimax-direct-provider.md` for the MiniMax direct API setup and key requirements.

**To smoke-test the entire chain:** run `scripts/test-fallback-chain.sh` — it reads config.yaml, extracts all keys, and tests every tier with curl.

**⚠️ Pitfall — profile configs and provider plugins MUST be verified per profile:**
Profile configs are independent. When adding or renaming a provider in `fallback_providers`, update EVERY profile config (`~/.hermes/profiles/*/config.yaml`) and verify the provider is resolvable from that profile's `HERMES_HOME`. If the provider is represented by a first-class model-provider plugin, make sure the profile can discover that plugin and use the plugin slug consistently (for example `fatman-ollama`, not the old config-only slug `fatman:11434`). Do not reintroduce inline secret-bearing `custom_providers` blocks for recurring endpoints unless the user explicitly requests that older pattern. After any fallback chain change, run a consistency check across all profiles.

**To verify which model/provider is currently active** (when the user asks "what model are we on?"):
```bash
hermes config get model.default && hermes config get model.provider
```

**To check the CURRENT SESSION's actual model** (what the gateway handed the agent): look at the "Conversation started" metadata in the system prompt (`Model:` and `Provider:` fields). This is the ground truth of what the current turn is running on.

## Domain → Profile Mapping

When the user's request falls into ANY of these domains, DELEGATE to the matching profile. Do NOT handle directly.

### → grcexpert (MiniMax-M3 / minimax-direct)

**ALWAYS delegate when the task involves:**

- GRC (Governance, Risk, Compliance) frameworks — CyFUN, NIS2, ISO 27001, NIST CSF
- Cybersecurity policy authoring, review, or gap analysis
- Risk assessment, risk treatment, risk management
- Security audit preparation, evidence collection, audit readiness
- Vulnerability management policy and process
- Incident response planning and playbooks
- Information classification, data protection impact assessments
- Supplier/vendor security assessment
- Belgian or EU cybersecurity regulation (NIS2, EU AI Act, GDPR/AVG)
- CyFUN OD/DR code mapping and compliance
- Security awareness and training program design
- Business continuity and disaster recovery planning (security context)
- Any task involving the `04 - Knowledge/DigitaalVlaanderen/` or `04 - Knowledge/CyFUN/` vault sections
- Any task involving the 754 cybersecurity skills
- Verlinfo/Verla/CyFUN/GRC/NIS2 questions (read CONTEXT.md chain first per prefill rule)

**Delegation method:**
```
delegate_task(
    goal="<specific GRC/cybersecurity task>",
    context="<all relevant file paths, vault sections, and constraints>",
    model="MiniMax-M3",
    provider="minimax-direct",
    toolsets=["terminal", "file", "web", "search", "skills", "session_search", "obsidian", "note-taking"]
)
```

For complex multi-step GRC tasks, use terminal spawn:
```
terminal(command="hermes --profile grcexpert chat -q '<self-contained prompt>'", timeout=300)
```

### → maartenwriter (MiniMax-M3 / minimax-direct)

**ALWAYS delegate when the task involves:**

- Creative writing: novel chapters, scenes, dialogue, narrative prose
- Continuity tracking, character development, plot structuring
- Editing for voice, tone, and style (not technical editing)
- Humanizing AI-generated text into natural prose — **always load the `avoid-ai-writing` skill** for AI-ism detection and removal
- Writing in specific literary styles or authorial voices
- Any task in the `70-Writing/` vault workspace
- Story outlining, worldbuilding, character bios
- Translation with stylistic intent (not just literal)

**Delegation method:**
```
delegate_task(
    goal="<specific writing task>",
    context="<vault paths, style guides, continuity notes, character references>",
    model="MiniMax-M3",
    provider="minimax-direct",
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
3. **NEVER write creative prose/chapters directly** — delegate to maartenwriter
4. **NEVER do GRC gap analysis directly** — delegate to grcexpert
6. **NEVER edit creative writing for style/voice directly** — delegate to maartenwriter
7. **NEVER say "I can handle this" when a specialist profile exists** — DELEGATE

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

## Verlinfo Special Case

The grcexpert prefill.txt enforces reading `10 - Customers/Verlinfo/00-Overview.md` before any Verlinfo/Verla/CyFUN/GRC/NIS2 question. When delegating Verlinfo-related tasks to grcexpert, include the 00-Overview.md path in the context and note the chain: 00-Overview.md → MOC → specific files.

## Shared Skill Library (all profiles)

These skills from `wondelai/skills` (creative/ category) are available to ALL agents and profiles. No specialist profile exists for design/product/strategy — the default agent handles these natively, loading the appropriate wondelai skill:

**UX/Design:** refactoring-ui, ios-hig-design, ux-heuristics, hooked-ux, improve-retention, web-typography, top-design, design-everyday-things, lean-ux, microinteractions

**Product/Strategy:** jobs-to-be-done, lean-startup, design-sprint, inspired-product, continuous-discovery, 37signals-way, mom-test, negotiation, crossing-the-chasm, blue-ocean-strategy, traction-eos, obviously-awesome

**Marketing/Sales:** cro-methodology, storybrand-messaging, scorecard-marketing, contagious, one-page-marketing, influence-psychology, predictable-revenue, made-to-stick, hundred-million-offers

**Code Quality/Architecture** (no dedicated code-review specialist profile currently exists): clean-code, refactoring-patterns, software-design-philosophy, pragmatic-programmer, domain-driven-design, ddia-systems, system-design, clean-architecture, release-it, high-perf-browser

**Other:** drive-motivation, avoid-ai-writing (creative/ category, v3.4.0, AI-ism removal)
