# Plan: Take ownership of `05 - AI/99 - Hermes/plugins/superpowers`

## Context

The superpowers plugin at `05 - AI/99 - Hermes/plugins/superpowers/` is a Hermes
adapter for `obra/superpowers` (Jesse Vincent / Prime Radiant). The local copy
is at upstream **main HEAD (2026-05-29)**, which is 25 days newer than the
latest tagged release v5.1.0 (2026-05-04).

70 of 148 files differ from upstream main. The diff is **100% mechanical**:
every difference is either

- a prepended `type: ai / tags: [ai]` Obsidian frontmatter block, and/or
- an appended `## Workflow Backlinks` block (added by the curator).

The base content of every file is byte-identical to upstream main HEAD.

**Adaptation evidence (high quality, minimal, additive):**
- 1 new file: `plugin.yaml` (Hermes-specific adapter; declares `pre_llm_call` hook and the `superpowers:*` skill namespace).
- 1 cosmetic change: `AGENTS.md` is a symlink to `CLAUDE.md` (upstream has the reverse; both directions are equivalent).
- 1 macOS artifact: `.DS_Store` (should be deleted and gitignored).
- 70 files: Obsidian frontmatter + curator backlinks block.

**Git state (the problem):**
- clawbot-vault's index has a stale **gitlink** (mode 160000) for
  `05 - AI/99 - Hermes/plugins/superpowers` — the parent thinks it's a git
  submodule. There is no `.gitmodules` file and no `.git/config` submodule
  entry. The gitlink is **orphaned**.
- `git ls-files` on the dir returns 1 entry (the gitlink).
- `git status -uall` shows 0 untracked files.
- `git check-ignore` returns "fatal: Pathspec ... is in submodule ...".
- Net effect: the entire 148-file plugin is invisible to git's normal
  file-tracking machinery.

## Scope

**Take ownership**: per the user's instruction, the plugin is adapted, the
adaptation is good quality, and we keep our local copy as part of the vault
rather than pointing back at the upstream repo.

## Steps (no destructive operations; reversible until commit)

### 1. Strip upstream git config from the plugin dir
- Delete `.gitignore` (7 lines, upstream-git exclude patterns)
- Delete `.gitattributes` (1 line, upstream CRLF normalization)
- Delete `.github/` (whole dir: 4 ISSUE_TEMPLATE files + PULL_REQUEST_TEMPLATE.md + FUNDING.yml)
- Delete `.version-bump.json` (upstream release-tooling config, irrelevant to a local plugin)
- Delete `.DS_Store` (macOS metadata)

### 2. Edit `plugin.yaml` to drop upstream attribution
Current description (line 5):
```
description: "Hermes adapter for obra/superpowers: registers all Superpowers
skills as qualified plugin skills and injects the using-superpowers bootstrap
automatically on every turn."
```
New description:
```
description: "Hermes plugin: registers all Superpowers skills as qualified
plugin skills and injects the using-superpowers bootstrap automatically on
every turn."
```

Current author (line 6):
```
author: "Jesse Vincent / Prime Radiant; Hermes adapter installed locally"
```
New author:
```
author: "Maarten Loose / TruSecure (Hermes integration); framework by Jesse Vincent / Prime Radiant"
```

### 3. Convert the stale gitlink to regular file tracking
- `git rm --cached "05 - AI/99 - Hermes/plugins/superpowers"` — removes the
  gitlink from the index without touching the working tree.
- `git add "05 - AI/99 - Hermes/plugins/superpowers"` — adds all 142 surviving
  files (148 - 6 deleted in step 1) to regular tracking.
- Verify: `git ls-files "05 - AI/99 - Hermes/plugins/superpowers/" | wc -l`
  should return 142.
- Verify: `git status` for the dir should show 0 untracked and 0 modified.

### 4. Verify the rsync scope
The vault is the source of truth for the rsync; this dir lives inside
`05 - AI/99 - Hermes/plugins/superpowers/`. The vault's existing
`.gitignore` lines for `05 - AI/99 - Hermes/` exclude hermes-agent source,
venv, node_modules, state db, logs, sessions, cache — none of which touch
our 142 files. No rsync changes needed.

## What this plan does NOT do

- Does **not** change any upstream content of any skill, hook, test, or doc.
- Does **not** remove the curator's `## Workflow Backlinks` blocks (the
  curator will re-emit them on the next dry-run if anything else changes; the
  diff size is small and stable).
- Does **not** modify `.gitmodules` (doesn't exist), `.git/config`
  (no submodule entry), or any file outside the plugin dir.
- Does **not** commit anything to git — that is a separate user-driven step.
- Does **not** delete the upstream `obra/superpowers` URL references that
  appear in:
  - `.cursor-plugin/plugin.json` (homepage, repository URLs)
  - `.opencode/INSTALL.md` (install instructions pointing at the upstream repo)
  - `RELEASE-NOTES.md` (historical changelog with upstream URLs)
  - `docs/plans/2025-11-22-opencode-support-implementation.md` (upstream plan doc)
  These are provenance / credit and historical context, not "git relations".

## Verification

1. **File deletions verified**:
   `ls -la 05\ -\ AI/99\ -\ Hermes/plugins/superpowers/ | grep -E "gitignore|gitattributes|github|version-bump|DS_Store"`
   should return nothing.

2. **plugin.yaml edit verified**:
   `grep -E "obra|Maarten Loose" 05\ -\ AI/99\ -\ Hermes/plugins/superpowers/plugin.yaml`
   should show the new strings.

3. **Git tracking verified**:
   `git ls-files "05 - AI/99 - Hermes/plugins/superpowers/" | wc -l` → 142.

4. **No remaining gitlink**:
   `git ls-tree HEAD "05 - AI/99 - Hermes/plugins/superpowers"` should show
   tree entries (mode 040000) or files, not a single commit (mode 160000).

5. **No content regression**:
   `diff -rq "05 - AI/99 - Hermes/plugins/superpowers/" /tmp/superpowers-main/`
   should show the **same 70 files** differing (the frontmatter + backlinks
   block on those 70 files) — the adaptations are preserved through the
   git-track conversion.

6. **Hermes runtime sanity** (post-conversion):
   - The plugin can still be loaded by Hermes (it reads `plugin.yaml` and the
     `skills/*/SKILL.md` files; both unchanged except for the metadata in
     `plugin.yaml`).
   - The curator's next dry-run will see the same 5 + 14 = 19 notes under
     `superpowers/` flagged as "AI material" and re-emit their
     `## Workflow Backlinks` block (no-op for unchanged content; will fire
     only if some other curator pass changes the rendered block).

## Risk

- **Low**: All file deletions target upstream git-config files that are
  inert in a local-only context. The gitlink → regular-files conversion is
  fully reversible: `git restore --staged <path>` would restore the gitlink
  and re-orphan the files.
- **Low**: The `plugin.yaml` edit is metadata only; the manifest schema is
  unchanged. Skill registration still works.
- **No external side effects** beyond the local vault repo.
- **No `hermes upgrade` interaction**: this is in the vault, not in
  `~/.hermes/hermes-agent/`, so a future Hermes upgrade will not touch it.

## Open questions for user

1. **RELEASE-NOTES.md**: keep the entire 67KB upstream changelog (it has
   upstream URLs), or trim to just the v5.1.0 entry (latest tag), or
   keep as-is?
2. **Tests directory**: keep all upstream test scripts (~30 files for
   claude-code / codex / copilot / explicit-skill-requests), or remove the
   ones for harnesses we don't run?
3. **docs/plans/ and docs/superpowers/**: keep all upstream design /
   planning docs (they're historical context, ~14 files), or remove?
4. **Should `05 - AI/99 - Hermes/plugins/superpowers/` get a `README.md`
   note** explaining "this is the local take-over of obra/superpowers, synced
   to upstream main as of 2026-05-29, with Obsidian-integration frontmatter
   and Hermes adapter `plugin.yaml`"? If yes, I'd write a short one.
