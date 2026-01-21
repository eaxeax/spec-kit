#!/usr/bin/env bash
#
# bd-context.sh — Beads wrapper with context detail levels
#
# Saves tokens by loading only the required level of information.
#
# Usage:
#   bd-context.sh show <id> [--level brief|standard|full]
#   bd-context.sh ready [--level brief|standard]
#   bd-context.sh epic [--level brief|standard|full]
#
# Levels:
#   brief    — ID, title, status, deps only (~100 tokens)
#   standard — + acceptance criteria, labels (~300 tokens)
#   full     — + design notes, spec context (~800+ tokens)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Defaults
LEVEL="standard"
OUTPUT_FORMAT="text"

usage() {
    cat <<EOF
bd-context — Beads wrapper with detail levels

Commands:
  show <id>     Show task with selected context level
  ready         List ready tasks
  epic          Epic context (shared across all tasks)
  stats         Brief statistics

Options:
  --level, -l   Level: brief | standard | full (default: standard)
  --json        Output in JSON format
  --help, -h    Show help

Examples:
  bd-context.sh show T001 --level brief     # Minimal (~100 tokens)
  bd-context.sh show T001                   # Standard (~300 tokens)
  bd-context.sh show T001 --level full      # Full (~800+ tokens)
  bd-context.sh ready --level brief         # Only ready task IDs
  bd-context.sh epic --level standard       # Epic context
EOF
    exit 0
}

# Parse arguments
COMMAND=""
TASK_ID=""
POSITIONAL=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --level|-l)
            LEVEL="$2"
            shift 2
            ;;
        --json)
            OUTPUT_FORMAT="json"
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

set -- "${POSITIONAL[@]}"

COMMAND="${1:-}"
shift || true

case "$COMMAND" in
    show)
        TASK_ID="${1:-}"
        if [[ -z "$TASK_ID" ]]; then
            echo "Error: task ID required" >&2
            exit 1
        fi
        ;;
    ready|epic|stats)
        ;;
    *)
        usage
        ;;
esac

# Find beads issue by T-number or full ID
find_issue_id() {
    local search="$1"
    if [[ "$search" =~ ^T[0-9]+ ]]; then
        # Search by T-number in title
        jq -r "select(.title | contains(\"$search:\")) | .id" "$BEADS_DIR/issues.jsonl" | head -1
    else
        echo "$search"
    fi
}

# Get feature directory from Epic
get_feature_dir() {
    local epic_desc
    # Use -c to get compact JSON, then extract description
    epic_desc=$(jq -c 'select(.issue_type == "epic")' "$BEADS_DIR/issues.jsonl" | head -1 | jq -r '.description')

    # Extract spec path from Epic description
    echo "$epic_desc" | grep -oP 'specs/[^/]+' | head -1
}

BEADS_DIR="$(get_repo_root)/.beads"
REPO_ROOT="$(get_repo_root)"

if [[ ! -d "$BEADS_DIR" ]]; then
    echo "Error: beads not initialized. Run 'bd init' first." >&2
    exit 1
fi

# ============================================================================
# SHOW command — display task with selected detail level
# ============================================================================
cmd_show() {
    local issue_id
    issue_id=$(find_issue_id "$TASK_ID")

    if [[ -z "$issue_id" ]]; then
        echo "Error: issue not found: $TASK_ID" >&2
        exit 1
    fi

    local issue
    issue=$(jq "select(.id == \"$issue_id\")" "$BEADS_DIR/issues.jsonl")

    if [[ -z "$issue" ]]; then
        echo "Error: issue not found: $issue_id" >&2
        exit 1
    fi

    case "$LEVEL" in
        brief)
            show_brief "$issue"
            ;;
        standard)
            show_standard "$issue"
            ;;
        full)
            show_full "$issue"
            ;;
        *)
            echo "Error: unknown level: $LEVEL" >&2
            exit 1
            ;;
    esac
}

show_brief() {
    local issue="$1"

    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo "$issue" | jq '{id, title, status, priority, labels, deps: [.dependencies[]?.depends_on_id]}'
    else
        echo "=== $(echo "$issue" | jq -r '.title') ==="
        echo "ID: $(echo "$issue" | jq -r '.id')"
        echo "Status: $(echo "$issue" | jq -r '.status')"
        echo "Priority: $(echo "$issue" | jq -r '.priority')"

        local deps
        deps=$(echo "$issue" | jq -r '[.dependencies[]?.depends_on_id] | join(", ")')
        if [[ -n "$deps" ]]; then
            echo "Depends on: $deps"
        fi
    fi
}

show_standard() {
    local issue="$1"

    # Brief + description + labels
    show_brief "$issue"

    if [[ "$OUTPUT_FORMAT" != "json" ]]; then
        echo ""
        echo "Description: $(echo "$issue" | jq -r '.description')"
        echo "Labels: $(echo "$issue" | jq -r '.labels | join(", ")')"

        # Extract FR-xxx from labels and show requirements
        local fr_labels
        fr_labels=$(echo "$issue" | jq -r '.labels[]? | select(startswith("FR-"))')

        if [[ -n "$fr_labels" ]]; then
            echo ""
            echo "Requirements:"
            for fr in $fr_labels; do
                echo "  - $fr"
            done
        fi
    fi
}

show_full() {
    local issue="$1"

    # Standard output first
    show_standard "$issue"

    if [[ "$OUTPUT_FORMAT" != "json" ]]; then
        # Load spec context
        local feature_dir
        feature_dir=$(get_feature_dir)

        if [[ -n "$feature_dir" && -d "$REPO_ROOT/$feature_dir" ]]; then
            echo ""
            echo "=== Spec Context ==="

            # Extract relevant FR-xxx from spec.md
            local fr_labels
            fr_labels=$(echo "$issue" | jq -r '.labels[]? | select(startswith("FR-"))')

            if [[ -n "$fr_labels" && -f "$REPO_ROOT/$feature_dir/spec.md" ]]; then
                echo "Functional Requirements:"
                for fr in $fr_labels; do
                    grep -A2 "$fr" "$REPO_ROOT/$feature_dir/spec.md" 2>/dev/null | head -3 || true
                done
            fi

            # Extract user story context
            local story_label
            story_label=$(echo "$issue" | jq -r '.labels[]? | select(startswith("phase:US") or startswith("US"))')

            if [[ -n "$story_label" && -f "$REPO_ROOT/$feature_dir/spec.md" ]]; then
                echo ""
                echo "User Story Context:"
                grep -A5 "### $story_label" "$REPO_ROOT/$feature_dir/spec.md" 2>/dev/null | head -6 || true
            fi

            # Design notes from research.md
            if [[ -f "$REPO_ROOT/$feature_dir/research.md" ]]; then
                echo ""
                echo "Design Notes (research.md):"
                head -20 "$REPO_ROOT/$feature_dir/research.md" | tail -15
            fi
        fi
    fi
}

# ============================================================================
# READY command — list ready tasks
# ============================================================================
cmd_ready() {
    case "$LEVEL" in
        brief)
            # Only ID and title
            bd ready 2>/dev/null | grep -oP '\[task\] [^:]+: [^$]+' | head -10
            ;;
        standard)
            # Full bd ready output
            bd ready
            ;;
        *)
            bd ready
            ;;
    esac
}

# ============================================================================
# EPIC command — epic context
# ============================================================================
cmd_epic() {
    local epic
    # Use -c for compact single-line JSON, then take first match
    epic=$(jq -c 'select(.issue_type == "epic")' "$BEADS_DIR/issues.jsonl" | head -1)

    if [[ -z "$epic" ]]; then
        echo "No Epic found" >&2
        exit 1
    fi

    case "$LEVEL" in
        brief)
            echo "=== Epic ==="
            echo "ID: $(echo "$epic" | jq -r '.id')"
            echo "Title: $(echo "$epic" | jq -r '.title')"
            echo "Status: $(echo "$epic" | jq -r '.status')"
            ;;
        standard)
            echo "=== Epic: $(echo "$epic" | jq -r '.title') ==="
            echo ""
            echo "$epic" | jq -r '.description'
            ;;
        full)
            echo "=== Epic: $(echo "$epic" | jq -r '.title') ==="
            echo ""
            echo "$epic" | jq -r '.description'

            # Load full spec context
            local feature_dir
            feature_dir=$(get_feature_dir)

            if [[ -n "$feature_dir" && -d "$REPO_ROOT/$feature_dir" ]]; then
                echo ""
                echo "=== Tech Stack (plan.md) ==="
                if [[ -f "$REPO_ROOT/$feature_dir/plan.md" ]]; then
                    grep -A20 "## Tech Stack\|## Technologies\|## Technical Context" "$REPO_ROOT/$feature_dir/plan.md" 2>/dev/null | head -20 || true
                fi

                echo ""
                echo "=== Acceptance Criteria (spec.md) ==="
                if [[ -f "$REPO_ROOT/$feature_dir/spec.md" ]]; then
                    grep -A3 "SC-[0-9]\+" "$REPO_ROOT/$feature_dir/spec.md" 2>/dev/null | head -30 || true
                fi
            fi
            ;;
    esac
}

# ============================================================================
# STATS command — brief statistics
# ============================================================================
cmd_stats() {
    local open closed in_progress blocked
    open=$(jq -r 'select(.status == "open") | .id' "$BEADS_DIR/issues.jsonl" | wc -l)
    closed=$(jq -r 'select(.status == "closed") | .id' "$BEADS_DIR/issues.jsonl" | wc -l)
    in_progress=$(jq -r 'select(.status == "in_progress") | .id' "$BEADS_DIR/issues.jsonl" | wc -l)

    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo "{\"open\": $open, \"closed\": $closed, \"in_progress\": $in_progress}"
    else
        echo "Open: $open | In Progress: $in_progress | Closed: $closed"
    fi
}

# Execute command
case "$COMMAND" in
    show)
        cmd_show
        ;;
    ready)
        cmd_ready
        ;;
    epic)
        cmd_epic
        ;;
    stats)
        cmd_stats
        ;;
esac
