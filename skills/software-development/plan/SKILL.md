---
name: plan
description: "Plan mode: write markdown plan to .hermes/plans/, no exec."
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
- Your deliverable is a markdown plan saved inside the active workspace under `.hermes/plans/`.

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
