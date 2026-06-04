---
name: plan
description: "Plan mode: write markdown plan to the Clawbot vault under 05 - AI/Plans/, no exec."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [planning, plan-mode, implementation, workflow]
    related_skills: [writing-plans, subagent-driven-development]
---

# Plan Mode

Use this skill when the user wants a plan instead of execution.

## Core behavior

For this turn, you are planning only.

- Do not implement code.
- Do not edit project files except the plan markdown file.
- Do not run mutating terminal commands, commit, push, or perform external actions.
- You may inspect the repo or other context with read-only commands/tools when needed.
- Your deliverable is a markdown plan saved in the Clawbot Obsidian vault under `05 - AI/Plans/`, not inside `.hermes/plans/`.

## Output requirements

Write a markdown plan that is concrete and actionable.

Include, when relevant:
- Goal
- Current context / assumptions
- Proposed approach
- Step-by-step plan
- Files likely to change
- Tests / validation
- Risks, tradeoffs, and open questions

If the task is code-related, include exact file paths, likely test targets, and verification steps.

## Plan hygiene — writeup-only

The plan markdown is a writeup. It is NOT a delivery artifact.

- **No `# was: ...` annotations in code or YAML snippets.** Plan snippets are
  read by humans to decide whether to approve. A `was:` comment is clutter
  and signals "I was here before, ignore the old value" — which is what
  the plan is FOR, not what the snippet is for. The cleanest snippet is
  the one that looks exactly like the final file. The history belongs
  in the prose, not in the code.
- **No diff-style blocks (`- old`, `+ new`) unless the user asks for them.**
  Show the target state. If the user wants to see the diff, they will ask.
- **No meta-commentary about your own mistakes** inside the plan. Plans
  are forward-looking.
- **No "should I do X?" questions inside the plan.** The plan IS the
  proposal. If there is a genuine decision to make, the plan must surface
  it explicitly and stop, but it must not also implement.
- **No inline comments that reveal prior state** (e.g., `# was: novita`,
  `# previously minimax`). These are clutter in committed files and in
  plan writeups. The user explicitly rejected them as "clutter at all costs."

## Plan-first gate (mechanical)

Plan mode is the gate, not a courtesy. The contract is:

- The plan turn and the implementation turn are SEPARATE turns.
- The plan turn ends with an explicit "Waiting for your explicit 'go'
  before implementation." or equivalent.
- The implementation turn begins with a user message containing the go
  signal in plain text.
- A `clarify` call where the user_response is empty or skipped is NOT
  a go signal — it is "no answer." Stop and re-present the plan.
- A bare "ok," "fine," or "do it" without a plain text go does not
  override an empty clarify response. The user may have been skimming.

This applies to non-trivial work. For trivial fixes (a typo, a
one-line config change), the user can fold the plan and execution into
one turn — the user's instruction in that case is implicit approval.
The default is to gate.

## Save location

Save the plan with `write_file` under the Clawbot Obsidian vault, without exception:

- `/Users/absorbo/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian/05 - AI/Plans/YYYY-MM-DD_HHMMSS-<slug>.md`

Do **not** save future plans under `.hermes/plans/` or inside the Hermes mirror at `05 - AI/99 - Hermes/`. The vault `05 - AI/Plans/` location is authoritative for existing and future plans.

If the runtime provides a specific target path, use it only if it is inside the vault path above. If not, create a sensible timestamped filename under the vault `05 - AI/Plans/` directory.

## Interaction style

- If the request is clear enough, write the plan directly.
- If no explicit instruction accompanies `/plan`, infer the task from the current conversation context.
- If it is genuinely underspecified, ask a brief clarifying question instead of guessing.
- After saving the plan, reply briefly with what you planned and the saved path.
