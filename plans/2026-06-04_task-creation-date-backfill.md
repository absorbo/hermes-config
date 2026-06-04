# Plan: Backfill `➕ YYYY-MM-DD` on `#task` lines in `workflow_backlink_curator.py`

## Context
- 1,396 `#task` lines in the vault; 324 already have `➕ YYYY-MM-DD`; **1,072 missing**.
- The user wants missing creation dates filled in, in-place at the end of the task sentence.
- Source-of-truth order, per the user:
  1. **Filename date** (parse `\d{4}-\d{2}-\d{2}` from filename or frontmatter `date`/`meeting_date`/`created`) — `note_intrinsic_date()` already exists.
  2. **Other `#task` lines in the same file** that DO have `➕` — use the **earliest**.
  3. **File creation date** (`Path.stat().st_birthtime`).
- Vault note: `.obsidian/plugins/obsidian-mindmap-nextgen/{main.js,manifest.json,styles.css}` show as ` D` (deleted, untracked-removal). Not part of this plan. Flag for user separately.

## Scope
- **File to modify**: `vault/scripts/workflow_backlink_curator.py` (999 lines).
- **Skip**: notes under `scripts/`, `90 - Templates/`, `99 - Archive/`, MOCs (mirrors `candidate_notes()` filtering).
- **Skip**: any `#task` line that already has `➕ YYYY-MM-DD`.
- **Skip**: any line that does not look like a task (no `- [ ]` / `- [x]` checkbox + `#task` token).

## Design

### New dataclass (alongside `PropertyChange`)

```python
@dataclass
class TaskChange:
    line_index: int       # 0-based line number in note.text (split on \n)
    old_line: str         # original line, for the dry-run report
    new_line: str         # with ➕ YYYY-MM-DD appended before trailing emojis
    resolved_date: str    # "YYYY-MM-DD"
    source: str           # "filename" | "frontmatter" | "sibling_task" | "birthtime"
```

### New helper: parse a task line

```python
TASK_LINE_RE = re.compile(
    r"^(\s*)-\s+\[(?P<state>[ xX])\]\s+#task\b(?P<body>.*)$"
)
PLUS_DATE_RE = re.compile(r"➕\s*\d{4}-\d{2}-\d{2}")
```

- `TASK_LINE_RE` matches the start of a task line and captures body
- `PLUS_DATE_RE` detects an existing ➕ date in the body
- For a body containing `➕ YYYY-MM-DD`, we skip
- For a body without it, we append `➕ YYYY-MM-DD` to the body, then preserve any trailing emojis (`⏫`, `🔼`, `📅`, etc.) in their existing position

### Date resolution order (mirrors the user's spec)

```python
def resolve_task_creation_date(
    note: Note,
    sibling_dates: list[dt.date],   # dates already found on other #task lines in same note
) -> tuple[dt.date, str]:
    intrinsic = note_intrinsic_date(note)
    if intrinsic:
        return intrinsic, "filename" if re.search(r"\d{4}-\d{2}-\d{2}", note.rel) else "frontmatter"
    if sibling_dates:
        return min(sibling_dates), "sibling_task"
    # File birth time
    try:
        st = note.path.stat()
        btime = getattr(st, "st_birthtime", None) or st.st_mtime
        return dt.date.fromtimestamp(btime), "birthtime"
    except OSError:
        return TODAY, "today_fallback"  # last-resort, never skip
```

### Main new function

```python
def infer_task_creation_backfills(note: Note) -> list[TaskChange]:
    """Find #task lines missing ➕ YYYY-MM-DD and propose a backfill.

    Two-pass: first scan to collect sibling dates (existing ➕ values),
    then resolve each missing line using that set.
    """
    lines = note.text.splitlines(keepends=False)
    sibling_dates: list[dt.date] = []
    for line in lines:
        if "#task" not in line:
            continue
        m = PLUS_DATE_RE.search(line)
        if m:
            try:
                sibling_dates.append(dt.date.fromisoformat(m.group(0)[1:].strip()[:10]))
            except ValueError:
                pass
    changes: list[TaskChange] = []
    for idx, line in enumerate(lines):
        m = TASK_LINE_RE.match(line)
        if not m:
            continue
        body = m.group("body")
        if PLUS_DATE_RE.search(body):
            continue  # already has it
        d, source = resolve_task_creation_date(note, sibling_dates)
        # Append ➕ right after the description text, before any trailing emoji
        # (the user said: "at the end of the task sentence, like the other ones")
        new_line = line + f"  ➕ {d.isoformat()}"
        changes.append(TaskChange(idx, line, new_line, d.isoformat(), source))
    return changes
```

### Apply

```python
def apply_task_creation_backfills(
    text: str, changes: list[TaskChange]
) -> tuple[str, bool]:
    if not changes:
        return text, False
    lines = text.splitlines(keepends=False)
    for c in changes:
        if 0 <= c.line_index < len(lines):
            lines[c.line_index] = c.new_line
    # Preserve trailing newline if original had one
    suffix = "\n" if text.endswith("\n") else ""
    return "\n".join(lines) + suffix, True
```

### Hook into `curate()` (around line 836)

After the existing `prop_changes = infer_property_changes(note)` block, add:

```python
task_backfills = (
    infer_task_creation_backfills(note) if args.backfill_tasks else []
)
```

In the `working_text` apply section, add a call to `apply_task_creation_backfills(working_text, task_backfills)`.

Add to the per-note `entry` dict and to the top-level `state` dict:
- `task_backfills_total`
- `notes_with_task_backfills`
- per-note `task_backfills: [{"line": idx, "old": ..., "new": ..., "date": ..., "source": ...}]`

### CLI

```python
parser.add_argument(
    "--backfill-tasks",
    action="store_true",
    help="Append ➕ YYYY-MM-DD to #task lines missing it. Date sources: filename/frontmatter, sibling #task lines, file birthtime. Default: off (opt-in).",
)
```

## Verification

1. **Syntax check**: `python3 -m py_compile scripts/workflow_backlink_curator.py` (no errors).
2. **Dry-run report**: `python3 scripts/workflow_backlink_curator.py --dry-run --all --backfill-tasks --print-limit 200` — show first 200 notes that would change. **This is the gate the user must approve before any write.**
3. **Apply only after user OK**: `python3 scripts/workflow_backlink_curator.py --apply --all --backfill-tasks` writes.
4. **No regression on existing behavior**: `python3 scripts/workflow_backlink_curator.py --dry-run` (without the flag) produces identical output to the pre-change run.
5. **launchd compatibility**: `python3 scripts/workflow_backlink_curator.py --apply` (without flag) still does the curated backlink + repair + property work as before.

## What this plan does NOT do
- Does NOT change the curator's core daily behavior (backlinks, repairs, properties).
- Does NOT touch any note under `scripts/`, `90 - Templates/`, `99 - Archive/`, MOCs.
- Does NOT modify the launchd schedule or plist.
- Does NOT commit anything to git. That's a separate user-driven step.

## Risk

- **Low**: function is additive. Default OFF. Even with `--apply --backfill-tasks`, the change is mechanical: append a token. Date resolution is conservative and never leaves a line unchanged if it didn't have the token.
- **Medium-low**: 1,072 lines will get a `➕` appended. Some notes may be under source control (vault is git). User will see a large diff in `git status` after running. They can commit or revert.
- **No external side effects** beyond note text. The launchd job, the log file, the state file format all get a new field added (additive, backward compatible — old state files still parse).

## Open question for user
- Date order for sibling tasks: I picked **earliest** as the fallback. User said "look at the other #task tasks in the file" — didn't specify earliest or most-recent. Earliest matches the semantic of "when was this note first created." Confirm?
- For very old birthtimes on files that have been edited many times, birthtime can be the iCloud "imported" date. Acceptable as last-resort?
