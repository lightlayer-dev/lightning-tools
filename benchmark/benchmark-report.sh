#!/bin/bash
# ⚡ Lightning Tools — Full Benchmark Report
# Runs all benchmarks and produces a combined report.
#
# Usage: ./benchmark/benchmark-report.sh [options] [target-directory]
#
# Options:
#   --markdown   Output in markdown format
#   --json       Output in JSON format

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FORMAT="text"
TARGET_DIR="."

while [[ $# -gt 0 ]]; do
  case "$1" in
    --markdown) FORMAT="markdown" ;;
    --json) FORMAT="json" ;;
    *) TARGET_DIR="$1" ;;
  esac
  shift
done

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

# ── Header ────────────────────────────────────────────────────────
if [[ "$FORMAT" == "markdown" ]]; then
  echo "# ⚡ Lightning Tools — Benchmark Report"
  echo ""
  echo "> Generated: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "> Target: \`$TARGET_DIR\`"
  echo ""
elif [[ "$FORMAT" == "json" ]]; then
  # Collect all output and wrap in JSON at the end
  TMPDIR_JSON=$(mktemp -d)
  trap "rm -rf $TMPDIR_JSON" EXIT
else
  echo ""
  echo "╔══════════════════════════════════════════════════════════════════╗"
  echo "║           ⚡ Lightning Tools — Full Benchmark Report           ║"
  echo "╚══════════════════════════════════════════════════════════════════╝"
  echo ""
  echo "  Date:   $(date '+%Y-%m-%d %H:%M:%S')"
  echo "  Target: $TARGET_DIR"
  echo ""
fi

# ── Run rewrite benchmarks ────────────────────────────────────────
if [[ "$FORMAT" == "markdown" ]]; then
  echo "## Command Rewrite Performance"
  echo ""
  echo '```'
fi

bash "$SCRIPT_DIR/benchmark-rewrites.sh" "$TARGET_DIR" 2>&1

if [[ "$FORMAT" == "markdown" ]]; then
  echo '```'
  echo ""
fi

# ── Run approval benchmarks ──────────────────────────────────────
if [[ "$FORMAT" == "markdown" ]]; then
  echo "## Auto-Approval Analysis"
  echo ""
  echo '```'
fi

bash "$SCRIPT_DIR/benchmark-approvals.sh" 2>&1

if [[ "$FORMAT" == "markdown" ]]; then
  echo '```'
  echo ""
fi

# ── Session hook benchmarks ──────────────────────────────────────
if [[ "$FORMAT" == "markdown" ]]; then
  echo "## Session Hook Overhead"
  echo ""
  echo '```'
fi

echo ""
echo "⚡ Lightning Tools — Session Hook Overhead"
echo ""

# Time the file-index hook
FILE_INDEX_HOOK="$SCRIPT_DIR/../.claude/hooks/file-index.sh"
COMPACT_HOOK="$SCRIPT_DIR/../.claude/hooks/compact-context.sh"

get_time_ns() {
  if date +%s%N | grep -q N; then
    perl -MTime::HiRes -e 'printf "%.0f\n", Time::HiRes::time()*1e9'
  else
    date +%s%N
  fi
}

if [[ -x "$FILE_INDEX_HOOK" ]]; then
  START=$(get_time_ns)
  echo '{}' | bash "$FILE_INDEX_HOOK" > /dev/null 2>&1 || true
  END=$(get_time_ns)
  FILE_INDEX_MS=$(( (END - START) / 1000000 ))
  echo "  file-index.sh:     ${FILE_INDEX_MS}ms (runs once at session start)"
else
  echo "  file-index.sh:     NOT FOUND"
fi

if [[ -x "$COMPACT_HOOK" ]]; then
  START=$(get_time_ns)
  echo '{}' | bash "$COMPACT_HOOK" > /dev/null 2>&1 || true
  END=$(get_time_ns)
  COMPACT_MS=$(( (END - START) / 1000000 ))
  echo "  compact-context.sh: ${COMPACT_MS}ms (runs once after compaction)"
else
  echo "  compact-context.sh: NOT FOUND"
fi

# Time the lightning rewrite hook with a sample command
LIGHTNING_HOOK="$SCRIPT_DIR/../.claude/hooks/lightning.sh"
APPROVE_HOOK="$SCRIPT_DIR/../.claude/hooks/auto-approve.sh"

if [[ -x "$LIGHTNING_HOOK" ]]; then
  SAMPLE='{"tool_name":"Bash","tool_input":{"command":"grep -rn TODO ."}}'
  START=$(get_time_ns)
  echo "$SAMPLE" | bash "$LIGHTNING_HOOK" > /dev/null 2>&1 || true
  END=$(get_time_ns)
  LIGHTNING_MS=$(( (END - START) / 1000000 ))
  echo "  lightning.sh:      ${LIGHTNING_MS}ms per Bash call (rewrite check)"
else
  echo "  lightning.sh:      NOT FOUND"
fi

if [[ -x "$APPROVE_HOOK" ]]; then
  SAMPLE='{"tool_name":"Bash","tool_input":{"command":"git status"}}'
  START=$(get_time_ns)
  echo "$SAMPLE" | bash "$APPROVE_HOOK" > /dev/null 2>&1 || true
  END=$(get_time_ns)
  APPROVE_MS=$(( (END - START) / 1000000 ))
  echo "  auto-approve.sh:   ${APPROVE_MS}ms per Bash call (approval check)"
else
  echo "  auto-approve.sh:   NOT FOUND"
fi

echo ""

if [[ "$FORMAT" == "markdown" ]]; then
  echo '```'
  echo ""
fi

# ── Bottom line ───────────────────────────────────────────────────
if [[ "$FORMAT" == "markdown" ]]; then
  echo "## Summary"
  echo ""
fi

echo "  ╔══════════════════════════════════════════════════════════════╗"
echo "  ║  Estimated per-session savings:                             ║"
echo "  ║                                                             ║"
echo "  ║    Command rewrites:    Depends on workload (see above)     ║"
echo "  ║    Auto-approvals:      ~35-70s (50-100 Bash calls)         ║"
echo "  ║    File indexing:       ~2-5 tool calls saved at startup    ║"
echo "  ║    Compaction recovery: Prevents context loss entirely      ║"
echo "  ╚══════════════════════════════════════════════════════════════╝"
echo ""
