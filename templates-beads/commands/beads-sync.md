---
description: Synchronize beads issue statuses back to tasks.md for documentation (project)
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).
- If user specifies "dry-run", show changes without applying
- If user specifies "force", update without confirmation

## Language Requirements

**ALL user interaction and reporting MUST be in Russian (Русский)**
- Progress reports: Russian
- Status tables: Russian
- Questions to user: Russian
- Error messages: Russian

## Overview

This command synchronizes beads issue statuses back to tasks.md for documentation purposes.

**Direction**: beads → tasks.md (one-way sync)

**Source of truth**: beads (`.beads/issues.jsonl`)

```
┌─────────────────────────────────────────────────────────────────┐
│  beads (source of truth)                                         │
│  ├── closed issues        →  [ ] becomes [x] in tasks.md        │
│  ├── open issues          →  [x] becomes [ ] in tasks.md        │
│  └── in_progress issues   →  [ ] stays [ ] (optionally mark)    │
└─────────────────────────────────────────────────────────────────┘
```

## Outline

### Phase 1: Setup and Validation

1. Run `.specify/scripts/bash/check-prerequisites.sh --json --require-tasks` from repo root
2. Parse FEATURE_DIR and locate tasks.md
3. Verify beads is initialized: check `.beads/` directory exists
4. If beads not initialized, abort with message: "Beads не инициализирован. Запустите `/speckit.taskstobeads` сначала."

### Phase 2: Load Current State

1. **Load beads issues:**
   ```bash
   bd list --json
   ```
   Parse into map: `{ task_id: { beads_id, status, title } }`

2. **Load tasks.md:**
   - Parse all task lines matching: `- [ ] T###` or `- [x] T###` or `- [X] T###`
   - Extract: task_id, current_status (checked/unchecked), line_number

3. **Build comparison table:**
   ```text
   | Task ID | tasks.md | beads | Action |
   |---------|----------|-------|--------|
   | T001    | [ ]      | closed | Mark [x] |
   | T002    | [x]      | open   | Mark [ ] |
   | T003    | [ ]      | closed | Mark [x] |
   | T004    | [ ]      | open   | No change |
   ```

### Phase 3: Calculate Changes

1. **Identify changes needed:**
   - `tasks.md [ ]` + `beads closed` → change to `[x]`
   - `tasks.md [x]` + `beads open` → change to `[ ]`
   - `tasks.md [x]` + `beads closed` → no change
   - `tasks.md [ ]` + `beads open` → no change

2. **Handle missing mappings:**
   - Task in tasks.md but not in beads → warn, skip
   - Task in beads but not in tasks.md → warn, skip

3. **Generate change summary:**
   ```text
   ## Изменения для синхронизации

   | Task | Текущий | Новый | Причина |
   |------|---------|-------|---------|
   | T001 | [ ]     | [x]   | beads: closed |
   | T005 | [x]     | [ ]   | beads: reopened |

   Всего изменений: N
   ```

### Phase 4: Apply Changes (or Dry Run)

**If dry-run mode:**
- Display change summary only
- Exit without modifying files

**If normal mode:**
1. Display change summary
2. Ask: "Применить изменения к tasks.md? (yes/no)"
3. If "yes":
   - Read tasks.md content
   - For each change, replace checkbox:
     - `- [ ] T###` → `- [x] T###` (for closed)
     - `- [x] T###` → `- [ ] T###` (for reopened)
     - `- [X] T###` → `- [ ] T###` (for reopened)
   - Write updated tasks.md
4. If "no", exit without changes

**If force mode:**
- Apply changes without confirmation

### Phase 5: Update Status Header

After applying checkbox changes, update the tasks.md status header:

1. **Calculate new statistics:**
   ```bash
   bd stats
   ```

2. **Determine overall status:**
   - All tasks closed → `## Status: COMPLETED ✅`
   - Some tasks open → `## Status: IN PROGRESS ⚠️`
   - All tasks open → `## Status: NOT STARTED`

3. **Update status section** at top of tasks.md:
   ```markdown
   ## Status: IN PROGRESS ⚠️

   **Прогресс**: 44/51 задач завершено (86%)

   | Статус | Количество |
   |--------|------------|
   | Closed | 44 |
   | Open | 5 |
   | In Progress | 2 |
   | Blocked | 0 |

   Последняя синхронизация: 2025-12-29 19:30
   ```

### Phase 6: Report Summary

Output final report:

```text
## Синхронизация завершена

**Файл:** specs/001-linux-test-framework/tasks.md
**Источник:** beads (.beads/issues.jsonl)

### Изменения:
- Помечено как выполненные: N задач
- Помечено как открытые: M задач
- Без изменений: K задач

### Текущий статус:
| Статус | Количество |
|--------|------------|
| ✅ Closed | X |
| 🔄 Open | Y |
| 🚧 In Progress | Z |
| 🚫 Blocked | W |

### Предупреждения:
- {warnings about missing mappings if any}
```

## Error Handling

- **beads not initialized** → abort, suggest `/speckit.taskstobeads`
- **tasks.md not found** → abort, suggest `/speckit.tasks`
- **No changes needed** → report "Синхронизация не требуется. tasks.md актуален."
- **Parse error** → report specific line/issue, continue with valid entries

## Notes

- This is a one-way sync: beads → tasks.md
- beads remains the source of truth
- tasks.md is updated for documentation/GitHub readability
- Run after major beads status changes or before commits
- Safe to run multiple times (idempotent)
