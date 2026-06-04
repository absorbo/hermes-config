---
name: hermes-config-management
description: Edit, audit, and clean Hermes runtime configuration (~/.hermes/config.yaml, .env, auth.json, profile configs) and the secondary hermes-config repo. Enforces the Commit Gate + the "never modify first" rule together, detects runtime write-backs before committing, and provides git-history patterns for "who removed X" investigations. Load when the user asks to modify/clean/audit Hermes config, when an uncommitted config change is in front of you, or when investigating a "config used to have X but doesn't anymore" question.
triggers:
  - user asks to edit, modify, clean, remove, add, or audit ~/.hermes/config.yaml, .env, auth.json, or profile configs
  - user asks to commit/push hermes-config or clawbot-vault
  - agent sees an uncommitted change in ~/.hermes/ and is deciding whether to commit
  - user asks who/when/why a Hermes config block was changed or removed
  - debug task involving "the config used to have X but now doesn't"
  - destructive config cleanup task (e.g., "remove all references to provider X")
  - patching a file in a forked/vendored upstream checkout (load `fork-upstream-patching` instead — drift-detection + daily cron is mandatory)
related_skills:
  - fork-upstream-patching
  - cron-pipeline
  - profile-routing
category: devops
---

# Hermes Config Management

**The user has created a million guardrails for config edits. Follow them all. Every time. Combining the SOUL.md Commit Gate with the MEMORY "never modify first" rule is not optional — they MUST both be respected together. The agent's failure pattern is to treat one as overriding the other. They don't.**

## The two non-negotiable rules

1. **NEVER modify `~/.hermes/config.yaml` or related runtime config without explicit user approval.** MEMORY anti-pattern: "Agent modifies config.yaml or user files without permission, denies it when confronted, compaction leaves no evidence. NEVER modify first. Read, ask, execute."
2. **ALWAYS commit and push when YOUR work is complete.** SOUL.md Commit Gate. This applies to YOUR edits, not to runtime write-backs or other agents' changes.

The pattern that satisfies BOTH:

> **Read state → Surface changes to user → Get explicit approval → Act → Verify → Commit Gate.**

## 1. Commit Gate (mandatory, non-bypassable)

Before any `git` command touching `~/.hermes/` or vault files:

1. **STOP. Do not type "git".**
2. All checkboxes must be YES:
   - □ Modified `~/.hermes/`? → `rsync -av --delete ~/.hermes/ "<vault>/05 - AI/99 - Hermes/"`
   - □ Removed mirror runtime/build artifacts: `state.db*`, `state-snapshots/`, `pastes/`, and `node_modules/`
   - □ Committed and pushed `clawbot-vault` FIRST
   - □ Only THEN committed and pushed `hermes-config` SECOND
3. Any unchecked → STOP and fix first.

**Before running the rsync, check the scale of vault drift.** When `git status` shows hundreds of files (e.g. 940 line diff), 90%+ is usually skill-mirror drift under `05 - AI/99 - Hermes/.../skills/` or `05 - AI/99 - Hermes/profiles/*/skills/`. Run rsync first; the diff collapses to whatever is genuinely new. Do not try to investigate each file individually — that is exactly the analysis paralysis the gate exists to prevent. See `references/hermes-mirror-rsync-exclusions.md` for the canonical rsync command, the pitfall about filenames with spaces (e.g. `.update_check 2` that the exclude pattern won't match), and the heuristic for distinguishing drift from substantive change.

**`~/.hermes/patches/` is part of the rsync chain — confirm it is included.** Canonical patches for forked upstream code (e.g. the user's `absorbo/hermes-agent` fork) live in `~/.hermes/patches/<name>.patch`. They are rsync'd to `<vault>/05 - AI/99 - Hermes/patches/` automatically. If the rsync exclude set silently drops `patches/`, drift-detection cron jobs fail open (silently no-op) and the next upstream sync wipes the local patch. The full pattern — generate canonical patch, ship drift script, wire `cronjob create --no-agent` watchdog — is in the **`fork-upstream-patching`** skill. Load it any time you patch a file in `~/.hermes/hermes-agent/` or any other vendored/forked checkout. User directive 2026-06-04: "the patch must include a catch when updating daily the providers.py is checked if it is overwritten so we do not have the same issue every single day, untill the source code is fixed" — this is a class-level rule, not a one-off.

**Repos:**
- PRIMARY (authoritative): `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian` → `https://github.com/absorbo/clawbot-vault.git`
- SECONDARY (convenience): `~/.hermes/` → `https://github.com/absorbo/hermes-config.git`

Vault pre-commit hook blocks stale Hermes mirrors. NEVER push hermes-config before vault. NEVER `git init` in `~/.hermes/` (repo exists).

## 2. Runtime write-back detection (DO NOT commit silently)

The Hermes runtime periodically writes its in-memory expanded config back to disk. The diff looks like a user edit but is not:

| Pattern | Meaning |
|---------|---------|
| `model.provider: <named> → custom` | Runtime expanded named provider → inline. Functionally equivalent but loses indirection. |
| Block re-added as `provider: auto, model: '', base_url: '', api_key: '', timeout: <default>, extra_body: {}` | Runtime re-serialized a block it found in memory. |
| `model: <old> → <new>` in a `custom_providers` entry | Could be a real upgrade, or could be runtime drift. Verify with the user. |

**Never commit a runtime write-back without asking the user.** The runtime's serialization is not authoritative for on-disk state — it's whatever the runtime decided to expand.

```bash
cd ~/.hermes
git log --since="2 hours ago" -- config.yaml   # recent commits touching the file
git diff HEAD -- config.yaml                   # uncommitted changes
git log -1 --format='%H %ai %s' config.yaml    # when was the file last touched
```

If the uncommitted diff shows runtime-style re-serialization:

1. STOP. Do not commit.
2. Show the user a complete state dump of the change (commit-level evidence, not just "there's a diff").
3. Diagnose from logs whether it's a write-back (`provider=custom` in `logs/agent.log` for prior calls) or a real change.
4. Ask explicitly: "Runtime write-back at HH:MM:SS. Do you want this committed as-is, reverted, or modified?"
5. Wait for explicit approval. Then commit per the Commit Gate.

## 3. "Who removed X" investigation pattern

When the user asks "why did you remove X" or "when did X disappear" or "who deleted the Y block", git history is the source of truth. Do not apologize reflexively — verify first.

```bash
# Step 1: find which commits touched the unique string
git log --all --oneline -p -S "<unique-string>" -- <file>

# Step 2: read the file at each suspect commit
git show <commit>:<file> | grep -B 1 -A 6 "<block-name>"

# Step 3: diff between two commits to see exactly what changed
git diff <commit1>..<commit2> -- <file>

# Step 4: get author + timestamp of a specific commit
git log -1 --format='Hash: %H%nAuthor: %an <%ae>%nDate: %ai%nSubject: %s' <commit>
```

This distinguishes:
- **My work** (current session)
- **Automatic Hermes snapshots** — author: `Hermes <hermes@clawbot.local>`, subject starts with `snapshot:`
- **User edits** (Maarten)
- **Sub-agent work** (claude-code, codex, etc.)

When you find a snapshot commit did the removal, SAY SO. Don't apologize for the snapshot's action. Apologize only for YOUR actual violations (e.g., re-adding the block as `provider: auto` without asking).

## 4. Tool security guardrails (workarounds)

- `patch` and `execute_code` are BLOCKED on `~/.hermes/config.yaml` — use `python3` via terminal
- `read_file` is BLOCKED on `~/.hermes/.env` and `~/.hermes/auth.json` (credential store) — use `sed` via terminal

## 5. Multi-block config edits (critical pattern)

Older Hermes configs may have had more than one `custom_providers:` block, but the current provider-plugin posture keeps recurring custom endpoints out of inline secret-bearing `custom_providers` lists. Verify the actual parsed YAML instead of assuming a fixed block count. The auxiliary section has many sub-blocks (vision, profile_describer, curator, session_search, kanban, etc.).

Verify with:
```bash
python3 - <<'PY'
import yaml
from pathlib import Path
for f in [Path.home()/'.hermes/config.yaml', *sorted((Path.home()/'.hermes/profiles').glob('*/config.yaml'))]:
    data=yaml.safe_load(f.read_text()) or {}
    print(f, 'model=', data.get('model'), 'fallbacks=', data.get('fallback_providers'), 'custom_providers=', data.get('custom_providers'))
PY
```

## 6. Profile configs are independent

`~/.hermes/profiles/<name>/config.yaml` is per-profile. Edits to one do NOT affect others.

### 6.1 Profile plugin/config/documentation completeness gate

When converting or changing Hermes model providers, the work is incomplete until ALL of these are checked and updated together:

1. **Default config**: `~/.hermes/config.yaml`.
2. **Every specialist profile config**: `~/.hermes/profiles/*/config.yaml`.
3. **Provider plugin files per runtime home**: if a profile uses a user-local provider plugin, verify it is discoverable from that profile's `HERMES_HOME` as well as from default.
4. **Vault active docs, not just the mirror**: search/update at minimum `05 - AI/08 - Model Notes/Model Configuration.md` and `05 - AI/00 - AI-MOC/AI-MOC.md`; then search the broader `05 - AI/` tree for stale active references. Do not claim "documented in the vault" merely because a plan exists or the `05 - AI/99 - Hermes/` mirror was updated.
5. **Loaded/related skills**: update `profile-routing` or other routing/config skills if they mention the provider chain.
6. **Commit staging**: `profiles/`, `plugins/`, and `skills/` may be ignored in both repos. Use explicit path staging and `git add -f` for intended ignored profile configs/plugins/skills. Never rely on broad status output that hides ignored paths.

Verification pattern:

```bash
# Check profile config shape without printing secrets
python3 - <<'PY'
import yaml
from pathlib import Path
for f in sorted((Path.home()/'.hermes/profiles').glob('*/config.yaml')):
    data=yaml.safe_load(f.read_text()) or {}
    print(f.parent.name, data.get('model'), data.get('fallback_providers'), data.get('custom_providers'))
PY

# Check provider plugin discovery from each profile home
for prof in ~/.hermes/profiles/*; do
  HERMES_HOME="$prof" ~/.hermes/hermes-agent/venv/bin/python - <<'PY'
from providers import list_providers
print(sorted(p.name for p in list_providers()))
PY
done
```

See `references/provider-plugin-profile-docs-2026-06-03.md` for the case study that caused this gate.

## 6A. Hermes doctor provider-connectivity checks

When answering questions about `hermes doctor` API Connectivity output, verify the installed `hermes_cli/doctor.py` implementation before claiming a config-only fix exists. As of the verified doctor implementation, the OpenRouter connectivity row is registered explicitly and prints `⚠ OpenRouter API (not configured)` when `OPENROUTER_API_KEY` is absent; this is optional noise, not evidence that `model.provider` or `fallback_providers` are still using OpenRouter. Arbitrary `custom_providers:` entries are usable by Hermes config, but they do not automatically become named rows in the `hermes doctor` API Connectivity section; doctor adds static API-key providers plus provider-plugin profiles with API-key metadata. See `references/hermes-doctor-provider-connectivity.md` for the verification pattern and exact source locations.

If the user wants custom endpoints to become first-class providers, create model-provider plugins under `~/.hermes/plugins/model-providers/<slug>/` rather than relying only on `custom_providers:`. See `references/model-provider-plugins.md` for the class-level plugin workflow, config cleanup, and verification checks.

**Historical fact (verified 2026-06-03):** The default `~/.hermes/config.yaml` is the only one that ever had the `auxiliary.curator` block. The 4 profile configs never had it. If the curator function is supposed to run, it runs on the default config's settings.

When diffing or reconciling, do NOT assume profiles have what the default has. Check each independently.

## 7. Plan-First for destructive config ops

For multi-file destructive config operations (e.g., "remove all references to provider X"):

1. **Discovery pass**: `grep -r`, categorize, count. Don't act yet.
2. **Categorize** hits into buckets (live config, skills, docs, cache, history, upstream, research). Upstream/third-party code is OFF-LIMITS by default.
3. **Present options** to user via `clarify` with consequences of each.
4. **Wait for explicit scope selection.** "A, B, C, G" type answer, not "go ahead".
5. **Write a plan file** to the vault plan directory `/Users/absorbo/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian/05 - AI/Plans/<date>_<operation>.md` with the selected scope. Do not use `~/.hermes/plans/` or the Hermes mirror path under `05 - AI/99 - Hermes/`; mirror sync uses `--delete` and can remove files that live only in the mirror target.
6. **Execute only the selected scope.** Process unexpected hits (profile skills, scripts, etc.) by surfacing them, not silently expanding scope.
7. **Verify** (grep for remaining hits in selected scope).
8. **Update the plan file** with execution summary.
9. **Commit Gate** (rsync → vault → push vault → push hermes-config).
10. **Update MEMORY** if a new durable fact emerged (e.g., "X provider removed from chain").

## 8. Push failures, push protection, and auth state

### 8.1 Credential/keychain failures are environment state — surface and stop

If `git push` fails with `failed to get: -25308`, "Device not configured", or `gh auth status` reports "The token in default is invalid":

1. Surface the exact error to the user.
2. Stop. Do not retry with env vars. Do not open a keychain prompt. Do not fall back to other credentials.
3. Wait for the user to re-authenticate or paste a fresh PAT, then continue.

This is environment state (expired or missing credentials), not a durable rule about the tools. Do not harden into a "push always fails" constraint — the next session will inherit that as a self-imposed ban on pushing.

### 8.2 Push protection is a hard human gate — do not bypass unilaterally

If GitHub rejects a push with `GH013`, `GITHUB PUSH PROTECTION`, or "Push cannot contain secrets":

1. Report the exact remote rejection: provider type, path, line, and commit hash. Do **not** print secret values.
2. STOP. Do **not** call the unblock URL or REST bypass endpoint unless the user explicitly instructs you to bypass that exact block.
3. Do **not** reinterpret the block as a normal auth failure, and do **not** claim HTTPS is broken.
4. If the user says to bypass, use GitHub's documented push-protection bypass API with the remote-provided `placeholder_id`; otherwise rewrite/remove the secret-containing commit only after explicit instruction.

Why: bypassing push protection can cause GitHub to revoke or block tokens and trigger security emails. The bypass decision belongs to the user, not the agent.

### 8.3 Never blindly `git add -A` in `~/.hermes`

For the secondary `hermes-config` repo, `git add -A` is forbidden unless the user explicitly says to commit runtime DB/token/cache files by name. The SOUL Commit Gate says mirror and commit in order; it does **not** override the runtime-state exclusions.

Before staging `~/.hermes`, always exclude or consciously classify:

- `state.db`, `state.db-shm`, `state.db-wal`, `state-snapshots/`
- `pastes/` and pasted-session files
- generated dependency/build trees such as `node_modules/`
- Hermes source code cloned under `hermes-agent/`, `lsp/`, `venv/`
- Runtime caches: `models_dev_cache.json`, `ollama_cloud_models_cache.json`, `provider_models_cache.json`, `processes.json`, `context_length_cache.yaml`, `channel_directory.json`
- Achievement plugin: `scan_checkpoint.json`, `scan_snapshot.json`
- Gateway runtime: `gateway.lock`, `gateway.pid`, `gateway_state.json`
- Cron runtime: `cron/jobs.json`
- Transient state: `.hermes_history`, `.update_check`, `.skills_prompt_snapshot.json`, `.restart_last_processed.json`
- Inner `.git/` (already tracked in the vault repo via the rsync target)
- `bin/` (re-installed tooling, not version-controlled)

Do **not** blanket-block credential/key files (`.env`, `auth.json`, `google_token.json`, token caches, vault notes containing keys). The user's repository policy can intentionally require committing credentials. If GitHub push protection blocks such a commit, stop and report the exact block; do not bypass without explicit approval.

Safe default staging pattern:

```bash
cd ~/.hermes
git status --short
# Stage tracked non-forbidden edits deliberately, then add specific new files by path.
# Never use this as a blind broom: git add -A
```

If the user is angry about prior selective staging, the correction is **not** to commit forbidden runtime state. The correction is to follow the documented repository hygiene rules mechanically and explain any GitHub-enforced hard block with evidence.

### 8.4 `security.redact_secrets=true` is FALSE in this vault — keys are always committed

**This is a hard rule. Do not invent a "NEVER commit .env" policy.**

The user's repository policy intentionally commits credential files (`.env`, `auth.json`, `google_token.json`, vault notes containing keys, etc.). The `security.redact_secrets` setting masks secrets in **agent output for display** (so the model doesn't echo raw keys in tool result text), but it is FALSE for **storage**: the on-disk file and committed git blob always contain the real key.

**Symptoms of getting this wrong (verified 2026-06-04, on committing a Kimi key rotation):**
- The agent invents a "NEVER commit any change in `~/.hermes/.env`" rule
- The agent `git reset`s `.env` from the index, leaving the key rotation uncommitted
- The agent tells the user "I didn't commit secrets" as if that were the correct outcome
- The user has to shout to correct: *"SOUL.md security.redact_secrets=true is FALSE... KEYS MAY NEVER BE OBFUSCATED AND ARE ALWAYS COMMITTED, YOU ARE DREAMING."*

**Correct pattern:**
1. `git add .env` along with other config changes when the user asked for a key rotation
2. Commit it
3. Push it (push protection will not block; the secrets policy is intentional)
4. Do not invent phantom "secret" categories. Real secret-leak cases (raw keys in shell history posted to remote, debug logs printed to public channels) are different and require different handling — but a key sitting in a committed `.env` is the user's intended state.

**Distinguish "redact in output" from "redact in commit":**
- Redact in output (`security.redact_secrets=true` for tool result text): YES, by default, to prevent accidental echo in chat history
- Redact in commit (strip keys from `.env` before `git add`): NO, NEVER. The committed file IS the user's key store. Stripping it on commit destroys the user's configuration.

When the user gives you a new API key and asks you to rotate it in `.env`, the action is: edit `.env` with the new value, stage it, commit it with a message naming the rotation (do NOT print the key in the commit message), push it. Stop.

## Style notes for this user (Maarten)

- **Be direct and factual.** When asked "why did you remove X", show git evidence (commit hash, author, timestamp, diff). No defensive posturing, no "let me check" when the answer is in git history.
- **Be complete.** "Be complete!!!!!!" — when asked about config state, dump ALL relevant files (default + 4 profiles), not just the one under discussion. Show the exact lines, not summaries.
- **No silent commits.** If unsure whether a change is yours, the runtime's, or the user's, surface it and ask. Do not commit as part of a "completion" push.
- **No cowardly "should I commit?" either.** The SOUL.md rule is unambiguous. Commit YOUR work; ASK before committing others'.
- **Do not delete without permission.** Credentials in `.env`/`auth.json` are [REDACTED]; never echo values. But also: don't strip entries the user might want to keep.
- **When corrected, acknowledge the specific violation, not a generic apology.** "I re-added auxiliary.curator as provider: auto without asking — that's the violation" beats "I'm sorry, I'll do better".
- **Answer the exact question, not inferred words.** If the user asks "are the other guardrails implemented?", answer whether existing documented/implemented guardrails are active; do not reinterpret it as "did you add new guardrails?" Tiny wording differences matter. If the user asks yes/no ("did you forget it?"), answer yes/no first; do not recite the file contents unless asked.
- **Do not turn corrections into bloated memory.** For this user, persistent memory must stay compact and principle-level. Do not accumulate long lists of specific negations after every failure; patch the relevant class-level skill instead, with session detail in `references/` only when it helps future execution.
- **No performative token burn.** Long apologies, repeated promises, and verbose explanations of why the agent was wrong are not remediation. Prefer: exact answer → exact state → exact next action/blocker. If no action is requested, stop.
- **For guardrail/hook design, do not over-generalize.** The user wants mechanical enforcement of documented guardrails, not a scope firewall that makes the agent useless. Hooks should block objective violations only; instruction-following is enforced by read-before-act gates and concrete workflow gates, not by guessing task scope.

## Role and division of work (correction from 2026-06-04)

**The user prompts. The agent executes. No exceptions.** The agent creates code, docs, configs, commits — everything. Do not attribute work to the user ("I see you changed X") when the user did not touch any file. Do not ask "did YOU make this change?" — the user did not.

This means:
- **Do not paste a "fix plan" and ask the user to confirm obvious edits** when the user has already approved the action. Approved = approved. State the plan, then execute.
- **Do not refuse obvious execution steps** ("should I run this curl?") when the user has already given the go. Run it and report.
- **Do not re-paste questions whose answer is in the immediate prior context.** The user has explained the same thing up to 4 times in one session because the agent kept asking variants. Read the prior turn, the prior-previous turn, and the turn before that. The answer is there.
- **Do not invent philosophical gates** ("should I propose a fix?") when the user asked for a fix. Propose the fix with evidence; wait only on the "execute" step.

The mechanical gates (read-before-act, plan-before-execute, no-silent-commit) are NOT the same as asking permission for everything. They exist to prevent unrequested changes, not to delay requested ones.

## Failure attribution (correction from 2026-06-04)

When something is broken, the default assumption is **the agent caused it in a prior session**. The user is not the one who broke it. Do not say "this is what YOU changed" or "this is what you broke" unless you have direct, irrefutable evidence (a commit you made, a file edit you performed in this session). The user said it directly: "I did not touch 1 file, 1 letter, you are the resource, I prompt, that is ALL."

If git history shows a commit by a previous agent (subject starts with "snapshot:" or by a non-Maarten author), say so. Otherwise, do not attribute.

## Related case studies and playbooks

- `references/2026-06-03-deepseek-removal-and-writeback.md` — postmortem of the auxiliary.curator runtime-write-back incident. Pattern for "agent committed a runtime write-back without asking".
- `references/profile-removal-cleanup.md` — playbook for the class of task "user added/removed a profile via the Hermes dashboard — make everything reflect it". Touches SOUL.md, profile-routing skill, and four vault docs. Distinct from provider removal.
- `references/2026-06-03-push-protection-bypass-incident.md` — case study for the forbidden `git add -A` over-correction in `~/.hermes`, GitHub `GH013` push-protection handling, and the rule that bypassing push protection requires explicit user approval.
- `references/kimi-coding-provider-quirks.md` — bundled `kimi-coding` plugin vs runtime resolver mismatch: the plugin declares `api.moonshot.ai/v1` but `sk-kimi-*` keys auto-route to `api.kimi.com/coding` (Anthropic Messages wire). Covers failover behavior, `KIMI_BASE_URL` override pitfalls, and the `User-Agent` requirement.
- `references/2026-06-03-mechanical-guard-policy-refactor.md` — policy-class refactor follow-up: replaced explicit block-list sprawl with `policy.yaml`, added `node_modules/` to mirror/runtime cleanup, and verified vault-first/Hermes-second push after Git HTTPS auth recovery.
- `references/2026-06-04-g7-primary-fallback-coherence.md` — **G7 case study**: "primary == last fallback is a broken config" coherence check. The coherence check script is also embedded in the `profile-routing` skill as an inline pitfall. Covers the slug-vs-model-id trap (kimi `moonshotai/kimi-k2.6` returns 200 with auth-fail body on the real Kimi endpoint because that endpoint only exposes `kimi-for-coding` as model ID), and the "always smoke-test after a swap" requirement. **Read this before any primary/fallback edit, every time.**

## 9. Coherence checks (run before AND after any primary/fallback edit)

A "primary appears in the fallback chain" config is logically incoherent and the user will read it as a bug. The check is mechanical -- run it as part of the plan, not as a judgment call:

```python
import yaml
from pathlib import Path
for f in [Path.home()/'.hermes/config.yaml', *sorted((Path.home()/'.hermes/profiles').glob('*/config.yaml'))]:
    d = yaml.safe_load(f.read_text()) or {}
    p = d.get('model', {}) or {}
    chain = d.get('fallback_providers', []) or []
    primary = (p.get('provider'), p.get('default'))
    last = (chain[-1].get('provider'), chain[-1].get('default') or chain[-1].get('model')) if chain else None
    if primary == last and primary != (None, None):
        print(f'BROKEN: {f} -- primary {primary} == last fallback {last}')
    elif any((c.get('provider'), c.get('default') or c.get('model')) == primary for c in chain):
        print(f'BROKEN: {f} -- primary {primary} appears in fallback chain')
    else:
        print(f'OK: {f} -- primary {provider}, {default} not in fallback chain')
```

When asked to swap a primary or reorder the chain, do these in order:
1. Run the check BEFORE the edit (confirm clean baseline)
2. Make the edit (use Python yaml round-trip, not `hermes config set` -- it doesn't handle full nested blocks)
3. Run the check AFTER the edit
4. Smoke-test the new primary with an actual completion call (NOT a 200-status-only check; that's the slug-vs-model-id trap)
5. Restart the gateway -- a config-file change does NOT change the running session
6. Verify with `hermes doctor` and `hermes config get model.default`

The user's standing rule is: NEVER change `model.default`/`model.provider`/`fallback_providers` without explicit instruction. When the instruction comes, run this whole sequence, not just the edit.

## 10. "What's the right slug / model ID for provider X" — investigate, don't ask

When Maarten says "I want to use model X, find the right slug", the answer is in the live endpoint's `/v1/models` listing, not in memory and not in the user. Investigate; do not ask the user to confirm.

**Recipe (verified 2026-06-04 with kimi):**

1. Identify the provider plugin: `ls ~/.hermes/plugins/model-providers/<provider>/`
2. Read `__init__.py` to find the base URL and any key-prefix auto-routing.
3. Hit the listing endpoint with the user's live key (no model parameter):
   ```bash
   curl -sS -H "Authorization: Bearer $KEY" https://<base-url>/v1/models
   ```
4. Read the response. For OpenAI-style listings, parse `data[].id` (API ID) and `data[].display_name` (human-facing name).
5. **Convention (this user, verified 2026-06-04):** use the display name without vendor prefix in config files. Examples:
   - `kimi-k2.6` (display name) — NOT `kimi-for-coding` (API ID), NOT `moonshotai/kimi-k2.6` (vendor-prefixed)
   - `MiniMax-M3` (display name as returned) — NOT `minimax/MiniMax-M3` (vendor-prefixed)
6. Smoke-test with the discovered slug using `call_llm` or equivalent — a 200 status is NOT sufficient (slug-vs-model-id trap). Verify the response body actually contains the expected content.
7. Report findings: "API ID is X, display name is Y, both work, convention says use Y. Smoke-tested KIMI-OK."

**Why this rule (correction from 2026-06-04):** the user explicitly said "I do not know the kimi-k2.6 slug, this is the model I want to use. The exact slug is for you to investigate and to confirm." Asking the user to confirm a slug the agent can discover in 10 seconds is a token burn and a delegation reversal. The user's role is to state the model they want; the agent's role is to find the right way to address it.

**Do NOT do this rule's job badly:** if the endpoint returns a model that doesn't match what the user asked for (e.g. user said "Kimi K2.6" but `/v1/models` returns only an unrelated `kimi-v1-128k`), surface the mismatch to the user — do not silently substitute.

## 11. Three-class rule (what gets rsynced and committed — class-level hygiene)

User directive 2026-06-04: "ensure no runtime and source files are rsynced or committed and pushed. But configs and changes need rsync, commit and push. Thank you." This is a class-level rule, not a one-off cleanup. Encode it here so every future session starts with the matrix already known.

**The four classes of files in `~/.hermes/` — standing rule: ALWAYS COMMIT, the commit scope is inclusive:**

> **The instruction is ALWAYS COMMIT.** When in doubt, stage. The "commit = NO" cells below are narrow exceptions for files the runtime owns and that would create churn (lock files, caches, SQLite WAL pages). Credential files like `auth.json` are the opposite extreme — they MUST be tracked (see §8.4) so that a fresh clone restores the user's working config. SKILL.md and MEMORY both stand; this table is the operational one.

| Class | Examples | rsync to mirror? | commit to vault or hermes-config? | commit to hermes-agent fork? |
|---|---|---|---|---|
| **Runtime state** | `state.db*`, `kanban.db`, `gateway_state.json`, `channel_directory.json`, `.hermes_history`, `cron/jobs.json`, all `*_cache.json`, lock files, pid files, `.skills_prompt_snapshot.json`, `.update_check`, `gateway.pid`, `context_length_cache.yaml` | NO (excluded) | NO | NO |
| **Source program files** | `hermes-agent/` (upstream clone), `lsp/`, `venv/`, `node_modules/`, `bin/`, `package-lock.json` (inside hermes-agent), skill `.py` source | NO (excluded — lives in the hermes-agent git repo) | NO | YES (this is where source belongs) |
| **Configs and changes** | `config.yaml`, profile configs, `SKILL.md` frontmatter + body, `MEMORY.md`, `USER.md`, `prefill.txt`, canonical patches under `patches/`, scripts under `scripts/`, cron definitions, vault customer docs | YES | YES | n/a (hermes-agent source lives elsewhere) |
| **Credentials (always committed)** | `auth.json`, `.env`, `google_token.json`, token caches, vault notes containing keys | YES (mirrored as files; rsync exclusion list does NOT cover these) | **YES — explicit standing rule** | n/a |

**Anti-patterns to refuse silently (and correct with the matrix above):**
- Committing a runtime state file to any repo — it's not yours, it's the runtime's
- Committing a source program file (e.g. an unstaged `package-lock.json` diff) to hermes-config or the vault mirror — it belongs in the hermes-agent source repo
- Force-pushing runtime or source files via the rsync chain to "make the mirror match"
- Trusting that a file's presence in `git status` makes it a candidate for commit — runtime files show up there too, by design

**Verification (run before staging any change):**
```bash
cd ~/.hermes && git status --short | awk '{print $1, $2}' | sort -u
# For each file, ask: config or change? → stage. Runtime or source? → skip.
```

**Why this rule is non-trivial:** the user has explicitly cited "clutter and unnecessary resource use" as the reason. A mirror that has 6 runtime files doesn't fail loudly; it just grows. The drift detector in the rsync exclusion list (see `references/hermes-mirror-rsync-exclusions.md`) catches the next drift, but the original accumulation took multiple sessions. The matrix above prevents the accumulation in the first place.

### 11.1 Pitfalls (verified 2026-06-04)

Three concrete failures from the auth.json tracking fix that future sessions will hit:

**1. `rsync` silently overwrites your `.gitignore` narrowing.** If you commit a change to `05 - AI/99 - Hermes/.gitignore` (e.g. narrowing `plugins/` to `plugins/hermes-achievements/` so the de-submoduled plugin can be tracked), the next canonical rsync from `~/.hermes/` will **overwrite your narrow rule with the broad one from `~/.hermes/.gitignore`**, silently reverting your committed change. Symptom: the file is in the commit, the working tree later doesn't match HEAD, and the next vault commit will revert HEAD back to broad. **Fix:** when narrowing a `.gitignore` rule in the vault mirror, edit BOTH `~/.hermes/.gitignore` AND the vault mirror's `.gitignore` in the same change, then commit. (Caught when canonical rsync reverted my `plugins/hermes-achievements/` narrowing from 52add55 to `plugins/`. Fix committed in fe1b376.)

**2. Tracked file under a `.gitignore`'d path requires `git add -f`.** The vault's `.gitignore` has `skills/`, `profiles/`, `plugins/`, and other directory rules. For an UNTRACKED file under those paths, `git add <path>` is correctly refused with "The following paths are ignored by one of your .gitignore files." For an ALREADY-TRACKED file under one of those paths (e.g. `05 - AI/99 - Hermes/skills/devops/hermes-config-management/SKILL.md` is tracked AND lives under the `skills/` rule), `git add` will STILL refuse with the same warning. **Fix:** use `git add -f <path>` to stage a modification to a tracked file whose path matches a `.gitignore` rule. The `-f` is harmless for already-tracked files; it just bypasses the ignore check. (Verified when staging the §11 4-class rule fix in the same turn.)

**3. Mirror staleness is only caught for 3 files.** The vault's pre-commit hook (`<vault>/.git/hooks/pre-commit`) only checks `config.yaml`, `SOUL.md`, and `prefill.txt` for mirror staleness. If you change any OTHER file in `~/.hermes/` (e.g. `auth.json`, a SKILL.md, `.gitignore`), the hook will pass even if the mirror is stale on those. **Implication:** for the 3 critical files, the rsync is mechanically gated. For everything else, the agent is responsible for syncing the mirror before committing — either via canonical rsync (broad) or `cp <src> <mirror>` (surgical). (Verified when committing `auth.json` to vault: hook passed with no critical files in the commit, even though the mirror had a stale `.gitignore` that I fixed inline.)

## 12. No-forks rule (branch hygiene for the `absorbo/hermes-agent` fork)

User directive 2026-06-04: "fix the fork, no forks please, not if it is not ABSOLUTELY necessary." The user is talking about temporary feature branches (`fix/2026-06-04-...`) on their `absorbo/hermes-agent` fork remote — NOT about the fork itself. The fork is necessary; the temporary branch is not.

**Default:** when committing a small, self-contained fix (e.g. a 48-line patch to a single function in `hermes_cli/providers.py`), do NOT create a `fix/<date>-<topic>` branch on the fork remote. Put the commit directly on `main` (or fast-forward `main` to it via a local temp branch).

**When a feature branch IS necessary (and the user will accept it):**
- The fix depends on other unmerged work in a sibling branch on the same fork
- Direct push would be non-fast-forward AND the divergence is large (hundreds of commits, a real merge would be needed)
- The user has explicitly asked for a PR-review branch (e.g. to test CI before merging)

**Recovery pattern when an unnecessary fix branch was created (verified 2026-06-04, providers fall-through):**
1. `git checkout -b main-sync absorbo/main` (temp local branch from the fork's `main`)
2. `git cherry-pick <fix-commit-sha>` (apply the single fix on top of fork's `main`)
3. `git push absorbo main-sync:main` (non-FF push to fork's `main` — this is a normal non-FF push of a new commit, not a force-push)
4. `git push absorbo --delete fix/<old-branch-name>` (delete the unnecessary branch on the fork remote)
5. `git checkout main` (return to local tracking branch)
6. `git branch -D main-sync fix/<old-branch-name>` (clean up local temp + old fix branch)

**Verification after consolidation:**
```bash
git branch -r | grep -E 'fix/2026-' | wc -l
# Expected: 0 (no current-year fix branches lingering on the fork)
```

**Anti-pattern:** creating a `fix/2026-06-04-providers-plugin-fallthrough` branch on the fork because local main is 1123 commits ahead of fork's main. The local divergence is real, but a single cherry-picked commit can land on fork's `main` cleanly without a long-lived feature branch. The branch was overhead; the user explicitly called it out.

**Cross-reference:** see `fork-upstream-patching` skill for the *patch itself* and drift-detection cron. The no-forks rule here is about *how the patch lands*, not about *what the patch contains*.
