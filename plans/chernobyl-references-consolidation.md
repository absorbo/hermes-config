# Plan: Chernobyl References Consolidation

**Date**: 2026-05-29
**Directory**: `70 - Writing/01_Input/the-chernobyl-overlap/references/`

## Current State

| Category | Count | Description |
|----------|-------|-------------|
| Good numbered files (01-23) | 23 | Properly organized, descriptive names — **DO NOT TOUCH** |
| Untitled-numbered stubs (10-33) | 24 | Auto-generated frontmatter wrappers with little/no content |
| Raw ALL-CAPS files | 14 | Source material already organized into good files 10-23 — **duplicates** |
| Raw CIA documents | 19 | Declassified CIA docs with full OCR content — **unique** |
| Raw misc files | 5 | Other unique sources (Alexievich book, Historical Docs, NSA, USSR Recovery, INFCIRC510) |

## Problem

1. 24 "untitled-" stubs are empty wrappers (frontmatter skeleton + workflow backlinks, no substantive content)
2. 14 ALL-CAPS raw files are duplicates of already-organized good files 10-23
3. 24 unique raw files (19 CIA + 5 misc) have no properly-numbered counterpart — their untitled stubs are useless

## Plan

### Phase 1: Remove Duplicates and Stubs

1. **Delete 24 untitled-numbered stubs** (files with `untitled-` prefix, numbers 10-33)
2. **Delete 14 ALL-CAPS raw duplicates** — source material already in good files:
   - `USSR  CHERNOBYL AND GORBA[16473577].md` → covered by `10-ussr-chernobyl-and-gorbachev-cia-nid.md`
   - `USSR IN BRIEF[16468033].md` → covered by `11-ussr-in-brief-chernobyl-reactor-3-abandonment.md`
   - `EASTERN EUROPE  AFTERMATH[16468022].md` → covered by `12-eastern-europe-aftermath-of-chernobyl.md`
   - `UKRAINE  WHO WILL MANAGE [16473580].md` → covered by `13-ukraine-who-will-manage-chernobyl.md`
   - `sov-87-10078x.md` → covered by `14-the-chernobyl-accident-social-and-political-implications.md`
   - `european review[15314002].md` + `european review[15313996].md` → covered by `15-european-review-chernobyl-impact-on-nuclear-programs.md`
   - `east european grain produ[15489147].md` → covered by `17-east-european-grain-production-chernobyl-agricultural-impact.md`
   - `TWO ARTICLES ON CHERNOBYL[16468051].md` → covered by `18-ussr-reactor-accident-update-and-handling-of-chernobyl.md`
   - `EFFECTS OF THE CHERNOBYL [16468043].md` → covered by `19-effects-of-chernobyl-on-soviet-export-promotion.md`
   - `EASTERN EUROPE  ECONOMIC [16468030].md` → covered by `20-eastern-europe-economic-effects-of-chernobyl.md`
   - `THE SOVIET NUCLEAR POWER [16474289].md` → covered by `21-the-soviet-nuclear-power-program-after-chernobyl.md`
   - `SANITIZED ORGANIZATIONAL [16471384].md` → covered by `22-organizational-consequences-and-cleanup-efforts-of-chernobyl.md`
   - `STATUS OF ENVIRONMENTAL R[16474283].md` → covered by `23-status-of-environmental-remediation-at-chernobyl.md`

### Phase 2: Organize Unique Raw Files into Numbered Files

Transform 24 unique raw files into properly-numbered files (24-47), following the existing format of files 10-23:

**Format standard** (from good files):
```yaml
---
type: reference
tags: [chernobyl-overlap, reference]
era: "1986"
confidence: high
---
# NN — Descriptive Title

> **CIA Source.** Declassified document. Cleaned of OCR page markers and classification stamps.

## Content

[raw content preserved verbatim]

## Workflow Backlinks
[...]
```

**New file mapping**:

| New # | Raw Source | Topic/Title |
|-------|------------|-------------|
| 24 | Alexievich_Svetlana_Voices_From_Chernobyl__The_Oz-lib.org_.epub.md | Alexievich — Voices from Chernobyl (full book) |
| 25 | CIA-RDP08S01350R000401290002-0.md | CIA declassified — Soviet nuclear safety (2013 release) |
| 26 | CIA-RDP09-00997R000100270001-9.md | CIA declassified — Large document collection (2013 release) |
| 27 | CIA-RDP86T01017R000404140001-7.md | CIA declassified — Chernobyl initial assessment (1986) |
| 28 | CIA-RDP87R00529R000100070033-1.md | CIA declassified — SECRET Chernobyl briefing (1987) |
| 29 | CIA-RDP87T01145R000200170007-1.md | CIA declassified — Chernobyl follow-up (1987) |
| 30 | CIA-RDP88B00443R000401740004-5.md | CIA declassified — Chernobyl update (1988) |
| 31 | CIA-RDP89G00720R000500060008-2.md | CIA declassified — Chernobyl assessment (1989) |
| 32 | CIA-RDP90-00552R000605740004-7.md | CIA declassified — Chernobyl implications (1990) |
| 33 | CIA-RDP90-00965R000100110105-6.md | CIA declassified — Soviet nuclear program (1990) |
| 34 | CIA-RDP90-00965R000201440017-6.md | CIA declassified — Chernobyl aftermath (1990) |
| 35 | CIA-RDP90-00965R000503820017-9.md | CIA declassified — Nuclear safety impact (1990) |
| 36 | CIA-RDP90-00965R000503830003-3.md | CIA declassified — Reactor safety measures (1990) |
| 37 | CIA-RDP90G01359R000300010004-2.md | CIA declassified — Soviet energy policy (1990) |
| 38 | CIA-RDP90G01359R000300050004-8.md | CIA declassified — Chernobyl consequences (1990) |
| 39 | CIA-RDP91-00561R000100100021-7.md | CIA declassified — Nuclear industry review (1991) |
| 40 | CIA-RDP91-00561R000100130018-8.md | CIA declassified — Chernobyl status update (1991) |
| 41 | CIA-RDP91-00587R000100190001-2.md | CIA declassified — Soviet nuclear future (1991) |
| 42 | CIA-RDP91B00874R000100170009-5.md | CIA declassified — Chernobyl legacy (1991) |
| 43 | CIA-RDP93T01142R000100360001-3.md | CIA declassified — Post-Soviet nuclear assessment (1993) |
| 44 | Historical Documents - Office of the Historian.md | State Dept FRUS — Chernobyl implications |
| 45 | National-Security-Archive-Doc-02-Central.md | NSA — Chernobyl decision-making documents |
| 46 | USSR CHERNOBYL RECOVERY [16468058].md | USSR Chernobyl Recovery report |
| 47 | infcirc510.md | IAEA INFCIRC/510 — Convention on Nuclear Safety |

### Phase 3: Verify

1. File count after: 23 (original good) + 24 (new) = 47 files — no more, no less
2. No data loss: all raw files accounted for
3. All good files 01-23 untouched

### What This Does NOT Do

- Does NOT alter content of existing good files 01-23
- Does NOT rewrite or restructure the raw content — preserves complete original text
- Does NOT merge related topics — each source gets its own file
- Does NOT invent descriptive titles beyond what the source provides
