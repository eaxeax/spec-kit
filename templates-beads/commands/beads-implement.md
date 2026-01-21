---
description: Execute implementation using beads workflow (bd ready → bd show → implement → bd close) with full speckit context. (project)
handoffs:
  - label: Sync to tasks.md
    agent: speckit.beads-sync
    prompt: Sync beads statuses back to tasks.md
    send: true
---

## User Input

```text
$ARGUMENTS
```

Consider user input: task ID (T005), phase (phase 1), or "parallel" mode.

## Language

**ALL output in Russian.** Code/paths in English.

## Token-Optimized Workflow

```
bd ready              → List unblocked tasks (~100 tokens)
bd-context.sh show T001 --level brief    → Minimal info (~100 tokens)
bd-context.sh show T001 --level standard → + labels, FR-xxx (~300 tokens)
bd-context.sh show T001 --level full     → + spec context (~800 tokens)
```

**Правило: начинай с `--level brief`, загружай `--level full` только при реализации.**

## Phases (Compact)

### 1. Init
```bash
.specify/scripts/bash/check-prerequisites.sh --json
bd stats
```

### 2. Select Task
```bash
bd ready                                    # List ready tasks
.specify/scripts/bash/bd-context.sh show {id} --level brief   # Quick look
```

### 3. Load Context (only when implementing)
```bash
.specify/scripts/bash/bd-context.sh show {id} --level full    # Full context
.specify/scripts/bash/bd-context.sh epic --level standard     # Epic context if needed
```

### 4. Implement
1. `bd update {id} --status in_progress`
2. Implement based on acceptance criteria from `--level full`
3. Validate against FR-xxx requirements

### 5. Close
```bash
bd close {id} --reason "Реализовано: {summary}"
bd ready   # Show newly unblocked
```

### 6. Report (Russian)
```
## Завершено: {task_id}
**Файлы:** {created/modified}
**Разблокировано:** {next tasks}
```

## Context Levels Reference

| Level | Tokens | Use When |
|-------|--------|----------|
| brief | ~100 | Выбор задачи, обзор |
| standard | ~300 | Понимание требований |
| full | ~800 | Реализация, валидация |

## Error Handling

- Task blocked → show blockers, offer to work on blocker
- Validation fails → keep in_progress, report failed criteria
- bd fails → report, suggest manual fix

## Notes

- Beads = source of truth
- Context loaded via `bd-context.sh`, not by reading spec files directly
- Labels (FR-xxx, phase:*) used for filtering and validation
