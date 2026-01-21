---
description: Convert tasks.md into beads issues with full speckit context (acceptance criteria, FR-xxx, success criteria, dependencies, epic structure). (project)
handoffs:
  - label: Implement with Beads
    agent: speckit.beads-implement
    prompt: Start implementation using beads workflow
    send: true
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Language Requirements

**ALL beads issue content MUST be written in Russian (Русский)**
- Issue titles: Russian (technical terms in English OK)
- Descriptions: Russian
- Acceptance criteria: Russian
- Design notes: Russian
- Labels: English (phase:setup, FR-xxx, US1, etc.)
- File paths and code identifiers: English

## Overview

This command imports tasks from speckit's tasks.md into beads with **full context** from all speckit artifacts:

| Speckit Source | Beads Field |
|----------------|-------------|
| Feature name | Epic title |
| User Stories (spec.md) | Sub-epics or labels |
| Tasks (tasks.md) | Issues with `--parent` |
| Acceptance Scenarios (spec.md) | `--acceptance` |
| FR-xxx markers (tasks.md) | `--labels` |
| Success Criteria SC-xxx (spec.md) | `--acceptance` for Polish tasks |
| Edge Cases (spec.md) | `--acceptance` for relevant tasks |
| Technical decisions (research.md) | `--design` |
| Contracts (contracts/) | `--description` |
| Data Model (data-model.md) | `--description` |
| Quickstart validation (quickstart.md) | `--acceptance` for Polish tasks |
| Checklists (checklists/) | Gate issue or pre-check |

## Outline

### Phase 1: Setup and Validation

1. Run `.specify/scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks` from repo root
2. Parse FEATURE_DIR and AVAILABLE_DOCS list
3. Verify beads is initialized: check `.beads/` directory exists
4. If beads not initialized, run `bd init` first

### Phase 2: Load All Speckit Artifacts

Load and parse from FEATURE_DIR:

```text
REQUIRED:
├── tasks.md          → Task list with IDs, phases, dependencies, [P] markers, [FR-xxx] markers
├── spec.md           → User Stories, Acceptance Scenarios, FR-xxx, SC-xxx, Edge Cases
└── plan.md           → Feature name, tech stack, project structure

OPTIONAL (enhance if exist):
├── research.md       → Technical decisions, rationale
├── data-model.md     → Entities, validation rules
├── contracts/        → Interface definitions
├── quickstart.md     → Validation scenarios
└── checklists/       → Pre-implementation checks
```

### Phase 3: Build Context Maps

1. **User Story Map**: Extract from spec.md
   ```
   US1: { title, priority, acceptance_scenarios[], edge_cases[] }
   US2: { title, priority, acceptance_scenarios[], edge_cases[] }
   ...
   ```

2. **Requirements Map**: Extract FR-xxx from spec.md
   ```
   FR-001: "Система ДОЛЖНА предоставлять юнит-тесты для модуля Settings"
   FR-002: "Система ДОЛЖНА предоставлять юнит-тесты для модуля AuthService"
   ...
   ```

3. **Success Criteria Map**: Extract SC-xxx from spec.md
   ```
   SC-001: "Все юнит-тесты выполняются менее чем за 30 секунд"
   SC-005: "Покрытие кода основных модулей ≥ 70%"
   ...
   ```

4. **Task Map**: Parse tasks.md
   ```
   T001: { description, phase, story, parallel, fr_markers[], file_path }
   T002: { description, phase, story, parallel, fr_markers[], file_path }
   ...
   ```

5. **Dependencies Map**: Extract from tasks.md "Dependencies & Execution Order" section
   ```
   T005: depends_on [T001, T002]
   T006: depends_on [T001, T002, T003]
   ...
   ```

6. **Research Decisions Map** (if research.md exists):
   ```
   decision_3: { title: "Boost.Asio Test Fixtures", rationale: "..." }
   ...
   ```

### Phase 4: Check for Existing Beads Issues

1. Run `bd list --json` to get existing issues
2. Check if Epic for this feature already exists
3. Check if tasks already imported (by title match)
4. If issues exist, ask user:
   - "Обнаружены существующие issues. Удалить и создать заново? (yes/no/skip-existing)"

### Phase 5: Create Epic with Context References

**ВАЖНО: Epic хранит ССЫЛКИ на spec-файлы, не копирует контекст.**

Это экономит токены — агент загружает контекст по требованию через `bd-context.sh`.

1. Extract feature name from plan.md or spec.md header
2. Create Epic with **context_ref** section:

```bash
bd create "Linux Test Framework" \
  --type epic \
  --priority 1 \
  --description "Создание инфраструктуры тестирования для CoreVPN под Linux.

**User Stories:**
- US1: Запуск юнит-тестов (P1)
- US2: Запуск интеграционных тестов (P2)
- US3: Генерация отчётов о покрытии (P3)
- US4: E2E тесты с network namespaces (P2)

**Success Criteria:**
- SC-001: Юнит-тесты < 30 сек
- SC-005: Покрытие ≥ 70%

**Context References (lazy load via bd-context.sh):**
- spec: specs/001-linux-test-framework/spec.md
- plan: specs/001-linux-test-framework/plan.md
- research: specs/001-linux-test-framework/research.md
- data-model: specs/001-linux-test-framework/data-model.md
- contracts: specs/001-linux-test-framework/contracts/" \
  --labels "feature:001-linux-test-framework"
```

3. Save Epic ID for `--parent` in tasks

### Phase 6: Create Checklist Gate (if checklists/ exists)

If `checklists/` directory contains files:

```bash
bd create "Gate: Pre-implementation Checklist" \
  --type gate \
  --priority 0 \
  --parent "$EPIC_ID" \
  --description "Проверить все checklists перед началом имплементации.

**Checklists:**
- requirements.md" \
  --acceptance "Все чеклисты должны быть выполнены (0 incomplete items)"
```

### Phase 7: Create Tasks with MINIMAL Context (Token-Optimized)

**ВАЖНО: Задачи содержат МИНИМУМ информации. Полный контекст загружается через `bd-context.sh --level full`.**

For each task in tasks.md, create beads issue:

**7.1 Build MINIMAL description (одна строка):**
```
{task_description from tasks.md} — {file_path}
```

**7.2 НЕ копировать acceptance criteria в задачу!**
```
Acceptance criteria хранятся в Epic → Context References → spec.md
Агент загружает через: bd-context.sh show T001 --level full
```

**7.3 НЕ копировать design notes!**
```
Design notes хранятся в Epic → Context References → research.md
Агент загружает по требованию
```

**7.4 Build labels (это ВАЖНО — они используются для фильтрации):**
```
phase:{phase}, {story_label}, {FR-xxx markers}, {parallel if [P]}
```

**7.5 Create MINIMAL issue (экономия токенов):**
```bash
bd create "{task_id}: {task_title}" \
  --type task \
  --priority {priority from story} \
  --parent "$EPIC_ID" \
  --labels "{labels}" \
  --description "{one-line description} — {file_path}"
```

**НЕ передавать --acceptance и --design!** Контекст в Epic.

**7.6 Save task_id → beads_id mapping for dependencies**

### Phase 8: Add Dependencies

After all tasks created, add dependencies:

```bash
# T005 depends on T001 and T002
bd dep add {beads_id_T005} {beads_id_T001}
bd dep add {beads_id_T005} {beads_id_T002}
```

### Phase 9: SKIP (контекст в Epic)

~~Не добавлять Success Criteria в задачи~~ — они в Epic → spec.md

### Phase 10: SKIP (контекст в Epic)

~~Не добавлять Quickstart Validation~~ — загружается через `bd-context.sh --level full`

### Phase 11: Report Summary

Output summary:

```text
## Beads Import Summary

**Epic:** {epic_id} - {feature_name}
**Tasks Created:** {count}
**Dependencies Added:** {count}

### Structure:
Epic: {epic_id}
├── Gate: {gate_id} (if exists)
├── Phase 1: Setup
│   ├── {task_id}: T001 - ...
│   └── {task_id}: T002 - ...
├── Phase 2: Foundational
│   └── ...
├── Phase 3: US1 - Unit Tests
│   └── ...
└── Phase N: Polish
    └── ...

### Ready to Start:
{output of bd ready}

### Next Steps:
1. Run `/speckit.beads-implement` to start implementation
2. Or manually: `bd ready` → `bd show <id>` → work → `bd close <id>`
```

## Error Handling

- If tasks.md not found → suggest running `/speckit.tasks` first
- If beads not initialized → run `bd init` automatically
- If Epic already exists → ask user to delete or reuse
- If dependency cycle detected → report and skip that dependency
- If bd command fails → report error, continue with other tasks

## Notes

- Tasks are created in order from tasks.md to preserve IDs
- [P] marker is added as label `parallel:true` for filtering
- FR-xxx markers from tasks.md are added as labels
- User Story acceptance scenarios are inherited by all tasks in that story
- Edge cases are added only to relevant tasks (based on description matching)
