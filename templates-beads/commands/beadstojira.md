---
description: Sync beads issues to Jira with proper field mapping and speckit context preservation.
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Supported arguments:**
- `push` — Export beads → Jira (default)
- `pull` — Import Jira → beads
- `sync` — Bidirectional sync
- `dry-run` — Preview without changes
- `status` — Show sync status only

## Language Requirements

**ALL user interaction MUST be in Russian (Русский)**
- Status reports: Russian
- Error messages: Russian
- Prompts: Russian
- Jira issue content: Russian (following speckit convention)

## Overview

This command synchronizes beads issues with Jira, preserving speckit context:

| Beads Field | Jira Field |
|-------------|------------|
| `title` | Summary |
| `description` | Description (first section) |
| `acceptance` | Description (Acceptance Criteria section) |
| `design` | Description (Design Notes section) |
| `priority` (0-4) | Priority (Highest-Lowest) |
| `status` | Status (with workflow mapping) |
| `labels` | Labels |
| `type` (task/bug/epic) | Issue Type |
| `external_ref` | ← Jira issue key (e.g., PROJ-123) |

## Prerequisites

### Jira Configuration

Before running, ensure Jira is configured:

```bash
# Check current config
bd config get jira.url
bd config get jira.project
bd config get jira.username

# Or set if not configured
bd config set jira.url "https://company.atlassian.net"
bd config set jira.project "PROJ"
bd config set jira.username "your_email@company.com"
bd config set jira.api_token "YOUR_API_TOKEN"
```

**API Token:**
- Jira Cloud: https://id.atlassian.com/manage-profile/security/api-tokens
- Jira Server: Personal Access Token or username/password

## Outline

### Phase 1: Configuration Check

1. **Check Jira configuration:**
   ```bash
   bd config get jira.url
   bd config get jira.project
   bd config get jira.username
   ```

2. **If not configured:**
   - Ask user for Jira URL, project key, username
   - Guide to get API token
   - Set configuration with `bd config set`

3. **Verify connection:**
   ```bash
   bd jira status
   ```

### Phase 2: Pre-Sync Analysis

1. **Get beads statistics:**
   ```bash
   bd stats
   ```

2. **Preview sync (always run first):**
   ```bash
   bd jira sync --dry-run
   ```

3. **Show preview to user:**
   ```text
   ## Превью синхронизации

   **Beads → Jira (push):**
   - Новые issues: {count}
   - Обновления: {count}

   **Jira → Beads (pull):**
   - Новые issues: {count}
   - Обновления: {count}

   **Конфликты:**
   - {list of conflicts if any}
   ```

4. **Ask for confirmation:**
   - "Выполнить синхронизацию? (yes/no/push-only/pull-only)"

### Phase 3: Field Mapping Preparation

Before sync, prepare description field for Jira format:

**Beads description + acceptance + design → Jira Description:**

```markdown
{description}

---

## Acceptance Criteria

{acceptance}

---

## Design Notes

{design}

---

## Metadata

- **Beads ID:** {beads_id}
- **Labels:** {labels}
- **Phase:** {phase from labels}
- **User Story:** {story from labels}
```

### Phase 4: Execute Sync

**Mode: push (beads → Jira)**
```bash
bd jira sync --push
```

**Mode: pull (Jira → beads)**
```bash
bd jira sync --pull
```

**Mode: sync (bidirectional)**
```bash
bd jira sync --prefer-local  # or --prefer-jira based on user choice
```

**Mode: dry-run**
```bash
bd jira sync --dry-run
```

### Phase 5: Epic Handling

Jira Epics require special handling:

1. **Create Epic first:**
   - Beads epic → Jira Epic issue type
   - Set Epic Name field

2. **Link tasks to Epic:**
   - Use Jira's Epic Link field
   - Or parent link for next-gen projects

3. **Sync Epic status:**
   - Auto-close Epic when all children done (optional)

### Phase 6: Status Mapping

Map beads status to Jira workflow:

| Beads Status | Jira Status (typical) |
|--------------|----------------------|
| `open` | To Do / Open / Backlog |
| `in_progress` | In Progress |
| `closed` | Done / Closed |
| `blocked` | Blocked (if exists) |

**Custom mapping (if needed):**
```bash
bd config set jira.status_map.open "To Do"
bd config set jira.status_map.in_progress "In Progress"
bd config set jira.status_map.closed "Done"
```

### Phase 7: Post-Sync Report

```text
## Результат синхронизации

**Jira Project:** {project_key}
**URL:** {jira_url}

### Созданные issues в Jira:

| Beads ID | Jira Key | Title |
|----------|----------|-------|
| core-vpn-2-55c | PROJ-101 | T001: Create tests/ directory |
| core-vpn-2-jbn | PROJ-102 | T002: Create CMakeLists.txt |
| ... | ... | ... |

### Обновлённые issues:

| Beads ID | Jira Key | Изменения |
|----------|----------|-----------|
| ... | ... | status: open → in_progress |

### Ошибки (если есть):

- {error_description}

### Ссылки:

- Epic: {jira_url}/browse/PROJ-100
- Board: {jira_url}/jira/software/projects/PROJ/boards/1
```

### Phase 8: Update External Refs

After push, beads issues get `external_ref` with Jira key:

```bash
bd show core-vpn-2-55c
# external_ref: PROJ-101
```

This enables:
- `bd jira sync` to update existing issues
- Link back to Jira from beads
- Two-way sync in future

## Special Scenarios

### First-Time Export (New Jira Project)

```bash
# 1. Create project in Jira (if not exists)
# 2. Configure beads
bd config set jira.url "https://company.atlassian.net"
bd config set jira.project "NEWPROJ"
bd config set jira.username "email@company.com"
bd config set jira.api_token "token"

# 3. Push all issues
bd jira sync --push --create-only
```

### Incremental Sync (Ongoing Work)

```bash
# After completing work locally
bd close core-vpn-2-55c
bd jira sync --push  # Updates status in Jira

# After updates in Jira
bd jira sync --pull  # Pulls changes to beads
```

### Conflict Resolution

If same issue modified in both systems:

1. Show conflict details:
   ```text
   Конфликт: core-vpn-2-55c (PROJ-101)

   Beads (updated 2025-12-29 18:00):
   - status: closed

   Jira (updated 2025-12-29 18:30):
   - status: in_progress
   ```

2. Ask user:
   - "Какую версию использовать? (beads/jira/skip)"

3. Apply resolution:
   ```bash
   bd jira sync --prefer-local   # or --prefer-jira
   ```

## Error Handling

| Error | Solution |
|-------|----------|
| 401 Unauthorized | Check API token, regenerate if expired |
| 404 Project not found | Verify project key in config |
| 400 Invalid field | Check field mapping, custom fields |
| Rate limited | Wait and retry, or use `--batch-size` |

## Notes

- Attachments are NOT synced (beads limitation)
- Comments are NOT synced (beads limitation)
- Custom Jira fields require additional mapping
- Jira workflows may reject status transitions
- Epic hierarchy is preserved where possible
