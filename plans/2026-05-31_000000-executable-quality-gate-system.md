# Executable Quality Gate System for Hermes

**Date:** 2026-05-31
**Status:** DESIGN (awaiting approval)
**Author:** Hermes Agent (default)
**Source:** Investigation of [a5c-ai/babysitter](https://github.com/a5c-ai/babysitter) → Porting quality gate concept to Hermes

---

## 1. Problem Statement

### Current State
Hermes uses **text-based gates** in `SOUL.md` and `prefill.txt` to constrain agent behavior:

- **Documentation Gate:** "Read docs before acting"
- **Plan Gate:** "State a plan before executing"
- **Commit Gate:** "Sync vault mirror before git operations"
- **Context Gate:** "Read 00-Overview.md before Verlinfo questions"

**These gates fail** because they are text instructions injected into the LLM's context window. The agent can (and has repeatedly) ignored them:
- May 23: Agent `git init`'d in `~/.hermes/` and force-pushed, bypassing the Commit Gate
- May 28: Agent did it AGAIN, identical violation
- Multiple sessions: Agent skipped documentation reads, acted on assumptions

### Root Cause
Text instructions in SOUL.md/prefill.txt are **advisory**, not **mechanical**. The LLM chooses whether to follow them. Confidence and "I already know" override the gates.

### What Babysitter Does Differently
Babysitter's quality gates are **executable code** that the agent literally cannot bypass:
- "Process as Code" → JavaScript defines what the agent CAN do
- "Mandatory Stop" → Agent cannot proceed past a failed gate
- "Deterministic Completion" → "Done" = gates passed, not self-certification

---

## 2. Design Goals

| Goal | Description |
|------|-------------|
| **Mechanical enforcement** | Gates must block execution, not just advise against it |
| **Transparent to the agent** | The agent should NOT be able to reason about bypassing gates |
| **Self-verifying** | Output is cryptographically/signature-tracked; gate pass/fail is unambiguous |
| **Hermes-native** | Uses Hermes' existing `hooks: {}` mechanism where possible |
| **Incremental adoption** | Start with pilot gates; expand without rearchitecting |
| **Defense in depth** | Mechanical layer (hooks) + file-system layer (git hooks) + context layer (prefill) |

---

## 3. Architecture

### 3.1 Gate Layer Model

```
┌─────────────────────────────────────────────┐
│  HERMES AGENT                                │
│  ┌─────────────────────────────────────────┐ │
│  │  LLM Context (SOUL.md + prefill.txt)    │ │  ← Advisory (current)
│  │  "You MUST do X before Y..."            │ │
│  └─────────────────────────────────────────┘ │
│                    ⬇                          │
│  ┌─────────────────────────────────────────┐ │
│  │  EXECUTABLE GATES (~/.hermes/gates/)    │ │  ← Mechanical (NEW)
│  │  Pre-tool hooks → BLOCK/ALLOW           │ │
│  │  Post-tool hooks → VERIFY/REJECT        │ │
│  └─────────────────────────────────────────┘ │
│                    ⬇                          │
│  ┌─────────────────────────────────────────┐ │
│  │  TOOL EXECUTION                         │ │  ← Blocked if gate fails
│  │  terminal(), write_file(), git, etc.    │ │
│  └─────────────────────────────────────────┘ │
│                    ⬇                          │
│  ┌─────────────────────────────────────────┐ │
│  │  POST-EXECUTION VERIFICATION            │ │  ← Mechanical (NEW)
│  │  Output validation gates                │ │
│  └─────────────────────────────────────────┘ │
│                    ⬇                          │
│  ┌─────────────────────────────────────────┐ │
│  │  GATE JOURNAL (.hermes/gates/journal/)  │ │  ← Audit trail (NEW)
│  │  Immutable pass/fail records            │ │
│  └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

### 3.2 Gate Types

#### Type A: Pre-Execution Hooks (BLOCKING)
Fire BEFORE the tool call reaches execution. If the hook returns non-zero, the tool call is BLOCKED and the agent receives the hook's error message.

| Hook | Trigger | Check |
|------|---------|-------|
| `git-pre-commit` | Any `git commit`/`git push`/`git init` | Has `rsync ~/.hermes/ → vault` been run this session? |
| `file-write-guard` | Any `write_file` to `~/.hermes/` | Is the agent in a design-only mode? Has user approved file writes? |
| `vault-delete-guard` | Any `rm`/`delete` touching vault path | Has user explicitly approved this specific deletion? |
| `delegate-before-action` | Any direct action in specialist domain | Has profile routing been checked? |

#### Type B: Post-Execution Hooks (VERIFYING)
Fire AFTER the tool call completes. If result doesn't match expectations, the hook can flag/reject.

| Hook | Trigger | Check |
|------|---------|-------|
| `git-post-push` | After `git push` | Does vault mirror match `~/.hermes/`? Did hermes-config push SECOND? |
| `config-integrity` | After config.yaml write | Is config.yaml still valid YAML? Are required keys present? |
| `vault-consistency` | After vault file create/delete | Do wikilinks still resolve? No orphan notes? |

#### Type C: Session Gates (SESSION-LEVEL)
Fire at session boundaries.

| Hook | Trigger | Check |
|------|---------|-------|
| `session-start` | New session init | Verify SOUL.md hasn't been tampered with since last session |
| `session-end` | Session termination | Verify all gates passed during session; final journal audit |

### 3.3 Gate Chain Execution

```
TOOL CALL REQUESTED
        │
        ▼
┌───────────────────┐
│ Pre-Execution     │  ← Type A hooks run in order
│ Gate Chain        │     Any failure = BLOCK tool call
│                   │     Agent receives hook's stderr as error
└───────┬───────────┘
        │ ALL PASS
        ▼
┌───────────────────┐
│ Tool Executes     │
└───────┬───────────┘
        │
        ▼
┌───────────────────┐
│ Post-Execution    │  ← Type B hooks run in order
│ Gate Chain        │     Any failure = flag/reject result
│                   │     Agent receives verification report
└───────┬───────────┘
        │ ALL PASS
        ▼
┌───────────────────┐
│ Journal Entry     │  ← Record in .hermes/gates/journal/
│ (immutable)       │     Timestamp, gate name, pass/fail, hash
└───────────────────┘
```

---

## 4. Integration with Existing Hermes Infrastructure

### 4.1 Existing `hooks: {}` Mechanism

Hermes already has a hooks configuration at `config.yaml:463`:

```yaml
hooks: {}
hooks_auto_accept: false
```

**Question to resolve:** Does this mechanism support:
- Pre-tool-execution hooks? (blocking)
- Post-tool-execution hooks? (verification)
- Session lifecycle hooks? (start/end)

**If YES:** Use the native hooks mechanism. Define gates as hook scripts.
**If NO:** Build a Python-based wrapper that sits between the agent and the tool execution layer. This is more invasive but feasible.

### 4.2 Integration with Existing Gates

This system does NOT replace SOUL.md/prefill.txt gates — it **adds a mechanical layer beneath them**:

```
prefill.txt (advisory) → hooks (mechanical) → tool execution
```

The prefill instruction "SYNC VAULT FIRST" still exists as a reminder, but now a hook BLOCKS `git commit` until the rsync has actually been executed in this session. Three layers:

1. **Context layer** (SOUL.md + prefill.txt): Instructs the agent what to do
2. **Mechanical layer** (hooks/gates): Prevents the agent from doing it wrong
3. **File-system layer** (git pre-commit hook): Catches anything the first two miss

### 4.3 Relationship to `tirith`

Hermes has `tirith` enabled at `config.yaml:469-471`:
```yaml
security:
  tirith_enabled: true
  tirith_path: tirith
  tirith_timeout: 5
  tirith_fail_open: true
```

Tirith appears to be a security validation layer. The quality gate system should be **compatible** with tirith but operates at a different level — tirith validates security, gates validate behavioral compliance.

---

## 5. File Structure

```
~/.hermes/
├── gates/                          # NEW: Gate definitions
│   ├── README.md                   # Gate system documentation
│   ├── gate-registry.yaml          # Master gate configuration
│   ├── pre-execution/              # Type A: Blocking hooks
│   │   ├── git-commit-gate.sh      # Commit gate (pilot #1)
│   │   ├── file-write-guard.sh     # File write guard
│   │   ├── vault-delete-guard.sh   # Vault deletion guard
│   │   └── profile-routing-gate.sh # Must delegate to specialist?
│   ├── post-execution/             # Type B: Verifying hooks
│   │   ├── git-push-verify.sh      # Verify push order
│   │   ├── config-integrity.py     # Validate config.yaml
│   │   └── vault-consistency.py    # Check wikilink integrity
│   ├── session/                    # Type C: Session gates
│   │   ├── session-init.sh         # Session start verification
│   │   └── session-end.sh          # Session end audit
│   └── journal/                    # Immutable gate pass/fail records
│       └── YYYY-MM-DD/
│           └── <session-id>.jsonl  # Append-only event log
├── config.yaml                     # MODIFIED: hooks section populated
├── SOUL.md                         # MODIFIED: references gate system
└── prefill.txt                     # MODIFIED: references gate system
```

### 5.1 gate-registry.yaml Schema

```yaml
# ~/.hermes/gates/gate-registry.yaml
version: "1.0"
gates:
  - name: git-commit-gate
    type: pre-execution
    enabled: true
    triggers:
      - tool: terminal
        command_pattern: "git (commit|push|init|add)"
      - tool: terminal
        command_pattern: "gh pr create"
    script: pre-execution/git-commit-gate.sh
    timeout: 10
    on_failure: block        # block | warn | log_only
    message: "COMMIT GATE FAILED: vault mirror not synced first. See ~/.hermes/gates/README.md"
    
  - name: file-write-guard
    type: pre-execution
    enabled: true
    triggers:
      - tool: write_file
        path_pattern: "~/.hermes/*"
      - tool: patch
        path_pattern: "~/.hermes/*"
      - tool: terminal
        command_pattern: ".*>\\s*~/\\.hermes/.*"
    script: pre-execution/file-write-guard.sh
    timeout: 5
    on_failure: block
    
  - name: vault-delete-guard
    type: pre-execution
    enabled: true
    triggers:
      - tool: terminal
        command_pattern: "rm .*Obsidian"
      - tool: terminal
        command_pattern: "git rm .*Obsidian"
    script: pre-execution/vault-delete-guard.sh
    timeout: 5
    on_failure: block
    message: "VAULT DELETE GUARD: deletion of vault files requires explicit user approval."

  - name: git-push-verify
    type: post-execution
    enabled: true
    triggers:
      - tool: terminal
        command_pattern: "git push"
    script: post-execution/git-push-verify.sh
    timeout: 30
    on_failure: warn

  - name: config-integrity
    type: post-execution
    enabled: true
    triggers:
      - tool: write_file
        path: "~/.hermes/config.yaml"
      - tool: patch
        path: "~/.hermes/config.yaml"
    script: post-execution/config-integrity.py
    timeout: 15
    on_failure: warn

  - name: session-init
    type: session
    enabled: true
    triggers:
      - event: session_start
    script: session/session-init.sh
    timeout: 5
    on_failure: warn

  - name: session-end
    type: session
    enabled: true
    triggers:
      - event: session_end
    script: session/session-end.sh
    timeout: 30
    on_failure: log_only
```

---

## 6. Pilot Gate: Commit Gate (v1)

The Commit Gate is the highest-priority pilot because it:
1. Has been bypassed the most times (May 23, May 28 — identical violations)
2. Has a clear mechanical check (has `rsync` been run this session?)
3. Is self-contained and low-risk to implement

### 6.1 Pilot Gate Script

```bash
#!/bin/bash
# ~/.hermes/gates/pre-execution/git-commit-gate.sh
# Trigger: ANY git commit, push, init, or add command
# Check: Has `rsync ~/.hermes/ → vault mirror` been run in this session?
# Failure: BLOCK the git command

SESSION_STAMP="/tmp/hermes-gate-session-${HERMES_SESSION_ID}.synced"
VAULT_PATH="/Users/absorbo/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian"
MIRROR_PATH="${VAULT_PATH}/05 - AI/99 - Hermes"

# If session stamp exists, gate passes
if [ -f "$SESSION_STAMP" ]; then
    exit 0
fi

# Sync now automatically?
# NO — we BLOCK and force the agent to run rsync explicitly
echo "⛔ COMMIT GATE: BLOCKED"
echo ""
echo "Before any git operation, the vault mirror must be synced."
echo "Required command:"
echo "  rsync -av --delete ~/.hermes/ \"${MIRROR_PATH}/\""
echo "  rm -f \"${MIRROR_PATH}/state.db\"*"
echo "  rm -rf \"${MIRROR_PATH}/state-snapshots/\""
echo ""
echo "After running the sync, the gate will create: ${SESSION_STAMP}"
echo "Then git operations will be allowed for this session."
exit 1
```

### 6.2 Integration with Existing git Pre-Commit Hook

The vault already has a git pre-commit hook that blocks commits with stale Hermes mirrors. The gate layer ADDS an earlier block — the agent can't even START the git command until the rsync is done. This creates:

```
Gate (pre-exec) → blocks git command before it runs
    ↓ (if bypassed somehow)
pre-commit hook (filesystem) → blocks git commit if mirror stale
    ↓ (if both bypassed)
SOUL.md instruction → text reminder that this was wrong
```

Three layers of defense for the most-violated rule.

---

## 7. Implementation Plan

### Phase 1: Research & Foundation (1 day)

| Step | Task | Deliverable |
|------|------|-------------|
| 1.1 | Investigate Hermes `hooks: {}` mechanism — what events, what signature, what return codes | Documented API |
| 1.2 | Test hook integration — can hooks intercept tool calls before execution? | Proof-of-concept |
| 1.3 | If hooks don't support pre-execution, design Python wrapper approach | Alternative design |

### Phase 2: Pilot Gate — Commit Gate (1 day)

| Step | Task | Deliverable |
|------|------|-------------|
| 2.1 | Create `~/.hermes/gates/` directory structure | File structure |
| 2.2 | Write `git-commit-gate.sh` pilot script | Gate script |
| 2.3 | Write `gate-registry.yaml` with commit gate entry | Registry |
| 2.4 | Write `gates/README.md` documentation | Documentation |
| 2.5 | Register hook in `~/.hermes/config.yaml` `hooks:` section | Config change |
| 2.6 | Test: attempt `git push` without running rsync → BLOCKED | Verification |
| 2.7 | Test: run rsync → session stamp created → `git push` ALLOWED | Verification |
| 2.8 | Test: attempt `git init` in `~/.hermes/` → BLOCKED by gate OR pre-commit hook | Verification |

### Phase 3: Additional Gates (2-3 days)

| Step | Gate | Priority |
|------|------|----------|
| 3.1 | `vault-delete-guard.sh` — blocks deletion of vault files without explicit approval | HIGH |
| 3.2 | `file-write-guard.sh` — blocks writes to `~/.hermes/` files in design-only mode | HIGH |
| 3.3 | `git-push-verify.sh` — verifies push order (vault FIRST, hermes-config SECOND) | MEDIUM |
| 3.4 | `config-integrity.py` — validates config.yaml after modifications | MEDIUM |
| 3.5 | `profile-routing-gate.sh` — checks delegate_task before direct action in specialist domain | LOW |
| 3.6 | `session-init.sh` — verifies SOUL.md integrity on session start | LOW |

### Phase 4: Journal & Audit (1 day)

| Step | Task | Deliverable |
|------|------|-------------|
| 4.1 | Create append-only JSONL journal in `.hermes/gates/journal/` | Journal format |
| 4.2 | Each gate logs: timestamp, gate_name, trigger_command, pass/fail, hash | Journal entries |
| 4.3 | Create `hermes gate log` command to query journal | CLI tool |
| 4.4 | Gate failure notifications — alert user when critical gates fail | Alert mechanism |

---

## 8. Success Criteria

| Criterion | How to Verify |
|-----------|---------------|
| Commit gate blocks `git push` without prior rsync | Run `git push` → expect BLOCK with error message |
| Commit gate allows `git push` after rsync | Run rsync → run `git push` → expect ALLOW |
| Vault delete guard blocks `rm` on vault files | Run `rm <vault-file>` → expect BLOCK |
| Gate journal records all pass/fail events | Check journal file after gate interactions |
| Existing SOUL.md/prefill.txt gates still function | Smoke test: documentation gate still fires in context |
| No false positives — normal operations unaffected | Smoke test: terminal, write_file, browser, delegate all work normally |

---

## 9. Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Hermes `hooks: {}` doesn't support pre-execution blocking | MEDIUM | Fallback to Python wrapper that intercepts tool calls before they reach the execution layer |
| Gate scripts have bugs causing false blocks | MEDIUM | Gates default to `on_failure: warn` during beta; switch to `block` after validation |
| Agent learns to disable gates | LOW | Gates are file-system-level scripts, not LLM-manipulable; gate-registry.yaml is read-only to the agent except via `hermes gate` CLI |
| Performance impact of gate checks | LOW | Each gate has a timeout (5-30s); gate scripts are lightweight shell/Python |
| Gate system conflicts with tirith | LOW | Gates operate on behavioral compliance; tirith on security; separate trigger chains |

---

## 10. Open Questions

1. **Does Hermes' `hooks: {}` mechanism support pre-tool-execution interception?** The `hooks:` config at line 463 is empty. We need to discover the API: what events trigger hooks, what signature hook scripts must have, and whether hooks can BLOCK (return non-zero to abort the tool call). Without the `hermes-agent` skill installed, we lack documentation.

2. **Can hooks be bypassed by the agent through config modification?** If the agent can edit `config.yaml` to remove hooks, the gate system has a single point of failure. We may need to make gate scripts read from a separate config that the agent cannot modify (e.g., `~/.hermes/gates/` — but the agent has write access to all of `~/.hermes/`).

3. **Should gates be per-profile or global?** The commit gate should be global (all profiles). But `profile-routing-gate.sh` might be default-agent-only. Design should support both scopes.

4. **How to handle session tracking for gates?** The `SESSION_STAMP` approach uses `/tmp/` files keyed by `HERMES_SESSION_ID`. Need to verify this env var exists and is stable across a session.

5. **Should gate scripts be in Python (like Hermes) or shell (like git hooks)?** Shell scripts are simpler and have fewer dependencies, but Python scripts have better error handling and can import Hermes internals. Shell for simple pre-exec checks; Python for post-exec verification that needs YAML/JSON parsing.

---

## 11. What This Plan Does NOT Do

- ❌ Does NOT implement anything — this is a design document
- ❌ Does NOT modify SOUL.md, prefill.txt, or config.yaml
- ❌ Does NOT create any gate scripts
- ❌ Does NOT replace Babysitter as an orchestrator — it adapts its quality gate concept
- ❌ Does NOT change Hermes' fundamental agent architecture
- ❌ Does NOT require npm/Node.js (Babysitter is Node.js; this stays in Hermes' Python/shell ecosystem)

---

## 12. References

- [Babysitter GitHub](https://github.com/a5c-ai/babysitter) — MIT licensed orchestration framework
- [a5c.ai](https://www.a5c.ai/) — Product page with architecture overview
- [Ry Walker Research: Babysitter](https://rywalker.com/research/babysitter) — Independent technical analysis
- `~/.hermes/SOUL.md` — Current text-based gate definitions
- `~/.hermes/prefill.txt` — Pre-execution injection rules
- `~/.hermes/config.yaml:463` — `hooks: {}` mechanism
- `~/.hermes/skills/execution-discipline/SKILL.md` — Commit gate protocol
