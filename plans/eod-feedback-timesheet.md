# Plan: End-of-Day Feedback & Automatic Timesheet System

## Context
- Daily notes auto-generated at 04:00 by Morning Briefing cron
- Timesheet pre-filled at 17:00 with `[ESTIMATE]` tags (inferred from meetings/tasks)
- Weekly rollup on Friday aggregates timesheets
- User currently has to manually review and correct estimates

## Goal
Enable daily end-of-work feedback (voice/text) that:
1. Captures confirmed hours per customer
2. Records personal reflections and customer observations
3. Automatically updates timesheets with **confirmed** (non-estimate) data
4. Surfaces relevant customer feedback in the next day's Morning Briefing
5. Archives everything else for weekly review/search
6. Makes weekly timesheet completion a zero-lookup operation

## What Will Change

### 1. Daily Note Template (`90 - Templates/Daily Note.md`)
Add structured sections:
```markdown
## 📝 End-of-Day Feedback
> _Awaiting Maarten's end-of-day input. Send voice/text with: hours per customer, personal notes, customer observations._

## 📋 Timesheet
> _Populated at 17:00. If EOD feedback exists, these are CONFIRMED hours (no [ESTIMATE]). If not, inferred._
```

### 2. New: EOD Feedback Capture Skill
When Maarten sends an end-of-day message:
- **Parse** into structured fields:
  - `hours`: List of {customer, hours, description}
  - `personal_feedback`: Personal reflections, mood, blockers
  - `customer_feedback`: Observations about specific customers
  - `follow_ups`: Anything needing action tomorrow
- **Write** to today's daily note under `## 📝 End-of-Day Feedback`
- **Update** `## 📋 Timesheet` immediately with confirmed hours (remove [ESTIMATE])
- **Archive** to `05 - AI/Daily Feedback Archive/YYYY-MM.md` for searchability
- **Queue** customer-relevant notes for tomorrow's Morning Briefing (write to a transient file or frontmatter)

### 3. Modified: Evening Timesheet Pre-Fill Cron (17:00)
Update prompt logic:
1. Check if `## 📝 End-of-Day Feedback` exists in today's note
2. **If yes:** Extract hours from feedback → write to `## 📋 Timesheet` as **confirmed** (no [ESTIMATE] tags)
3. **If no:** Fall back to current inference logic with [ESTIMATE] tags
4. Always preserve any `[CONFIRM: ...]` flags for things needing review

### 4. Modified: Morning Briefing Cron (04:00)
Update prompt to:
1. Read yesterday's `## 📝 End-of-Day Feedback`
2. Extract customer-relevant notes/observations
3. Include in a new `## 📌 Yesterday's Follow-Up Notes` section
4. Flag any follow-ups that need action today

### 5. Modified: Weekly Rollup Cron (Friday 15:00)
Update prompt to:
1. Prioritize **confirmed** hours from EOD feedback sections
2. Fall back to [ESTIMATE] entries only if no feedback exists
3. Clearly mark which days had confirmed vs estimated data
4. Produce final timesheet table ready for submission

## What Will NOT Change
- No changes to email triage, meeting briefs, content pipeline, or other daily note sections
- No changes to JIRA update pre-fill
- No changes to GraphWeaver, Eisenhower, or other existing crons
- No new external dependencies
- No automatic submission of timesheets (still manual final approval)

## Trigger Phrases for EOD Feedback
Maarten can send any of these to trigger capture:
- "End of day" / "EOD" / "Day review"
- "Timesheet: ..." (listing hours)
- Any voice/text that mentions customer hours + reflections

The system will detect intent and ask for clarification if ambiguous.

## Files to Create/Modify
| File | Action |
|------|--------|
| `90 - Templates/Daily Note.md` | Add EOD Feedback + Timesheet placeholders |
| `~/.hermes/skills/eod-feedback-capture/SKILL.md` | New skill for parsing and recording EOD feedback |
| `~/.hermes/cron/jobs.json` | Update Morning Briefing, Evening Timesheet Pre-Fill, Weekly Rollup prompts |
| `05 - AI/Daily Feedback Archive/` | New folder for monthly archives |

## Verification
1. Send test EOD message → confirm it appears in today's note
2. Confirm timesheet section updated with confirmed hours
3. Next morning → confirm relevant feedback appears in Morning Briefing
4. Friday → confirm weekly rollup uses confirmed data

## Rollback
- All changes are additive; removing the skill and reverting cron prompts restores previous behavior
- Daily note template changes are harmless if skill is removed
