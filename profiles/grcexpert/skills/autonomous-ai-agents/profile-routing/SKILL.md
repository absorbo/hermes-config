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

**Verified 2026-06-03:** only two specialist profile directories remain under `~/.hermes/profiles/`: `grcexpert` and `maartenwriter`. The `codereviewer` and `expertcoder` profiles were removed via the Hermes dashboard.

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

**Fallback chains** — read from the same configs above (`fallback_providers` field). Do not cache in documentation.

All profiles use `api_max_retries: 1` for fast failover.

See `references/model-failover-testing.md` for diagnostic procedures, `references/adding-fallback-providers.md` for the workflow to add or reorder providers.

**⚠️ Pitfall — profile configs and provider plugins MUST be verified per profile:**
Profile configs are independent. When adding or renaming a provider, update EVERY profile config and verify the provider is resolvable from that profile's `HERMES_HOME`. Use provider plugin slugs consistently (e.g. `fatman-ollama`, not the old alias `fatman:11434`). Do not reintroduce inline secret-bearing `custom_providers` blocks unless explicitly requested.

**To verify current model/provider:**
```bash
hermes config get model.default && hermes config get model.provider
```

## Domain → Profile Mapping

When the user's request falls into ANY of these domains, DELEGATE to the matching profile. Do NOT handle directly.

### → grcexpert

**ALWAYS delegate when the task involves:**

- GRC frameworks — CyFUN, NIS2, ISO 27001, NIST CSF
- Cybersecurity policy authoring, review, or gap analysis
- Risk assessment, risk treatment, risk management
- Security audit preparation, evidence collection
- Incident response planning and playbooks
- Information classification, DPIA
- Supplier/vendor security assessment
- Belgian or EU cybersecurity regulation
- Any task involving `04 - Knowledge/CyFUN/` or `04 - Knowledge/DigitaalVlaanderen/`
- Verlinfo/Verla/CyFUN/GRC/NIS2 questions

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

### → maartenwriter

**ALWAYS delegate when the task involves:**

- Creative writing: novel chapters, scenes, dialogue
- Continuity tracking, character development
- Editing for voice, tone, and style
- Humanizing AI-generated text — **always load `avoid-ai-writing` skill**
- Any task in `70-Writing/` vault workspace

**Delegation method:**
```
delegate_task(
    goal="<specific writing task>",
    context="<vault paths, style guides, continuity notes>",
    model="MiniMax-M3",
    provider="minimax-direct",
    toolsets=["terminal", "file", "web", "search", "skills", "obsidian", "note-taking"]
)
```

### → default (handle directly)

Only handle directly when the task is:
- General conversation, questions
- System administration, orchestration
- Configuration changes to Hermes itself
- Tasks that span multiple domains (break into subtasks, delegate each)

## Anti-Patterns — NEVER Do These

1. **NEVER write cybersecurity policy directly** — delegate to grcexpert
2. **NEVER write creative prose directly** — delegate to maartenwriter
3. **NEVER say "I can handle this" when a specialist profile exists** — DELEGATE

## Delegation Mechanism Reference

### delegate_task (preferred)

```
delegate_task(
    goal="One-sentence task description",
    context="File paths, constraints, relevant background",
    model="<profile's model>",
    provider="<profile's provider>",
    toolsets=["terminal", "file", "web", "search"]
)
```

### terminal spawn (complex multi-step)

```
terminal(command="hermes --profile grcexpert chat -q '<self-contained prompt>'", timeout=600, background=true, notify_on_complete=true)
```

## Self-Maintenance Protocol

After any profile change, update this skill:
1. **New profile added** → Add to domain mapping
2. **Profile removed** → Remove from mapping
3. **Profile model/provider changed** → Update delegation methods

After updating, also update the SOUL.md routing directive if the profile list changed.

## Verification

Before any substantive action:
1. **Classify the task** — which domain(s)?
2. **Check the mapping** — does a specialist profile exist?
3. **If yes, DELEGATE** — choose delegate_task or terminal spawn
4. **If no, handle directly** — after confirming no profile matches
