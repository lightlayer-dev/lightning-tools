#!/bin/bash
# ⚡ Lightning Tools — PreToolUse hook for Claude Code
# Intercepts slow Unix tools and rewrites them to faster alternatives.
#
# Replacements:
#   grep  → rg (ripgrep)
#   find  → fd
#   cat   → bat --plain
#   du    → dust
#   sed   → sd (simple replacements only)

set -euo pipefail

# Read JSON input from stdin
INPUT=$(cat)

# Extract the command being run
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only process Bash tool calls
if [[ "$TOOL_NAME" != "Bash" ]] || [[ -z "$COMMAND" ]]; then
  exit 0
fi

REWRITTEN=""

# Helper: check if a command starts with or pipes into a tool
# We match the tool as a standalone command (not as part of another word)
uses_tool() {
  local tool="$1"
  local cmd="$2"
  # Match: starts with tool, or has pipe/semicolon/&& before tool
  echo "$cmd" | grep -qE "(^|[|;&]\s*)${tool}(\s|$)"
}

# Replace grep → rg
if uses_tool "grep" "$COMMAND" && command -v rg &>/dev/null; then
  # Replace grep with rg, preserving arguments
  # Handle common grep flags that map directly
  REWRITTEN=$(echo "$COMMAND" | sed -E "s/(^|[|;&]\s*)grep(\s)/\1rg\2/g")
fi

# Replace find → fd
if uses_tool "find" "$COMMAND" && command -v fd &>/dev/null; then
  # Only replace simple find patterns: find <path> -name "pattern"
  # Complex find expressions are left alone
  if echo "$COMMAND" | grep -qE "find\s+\S+\s+-name\s+" && \
     ! echo "$COMMAND" | grep -qE "-exec|-delete|-print0|-newer|-perm"; then
    # Extract path and pattern from: find <path> -name "pattern"
    FIND_PATH=$(echo "$COMMAND" | sed -nE "s/.*find\s+(\S+)\s+-name\s+.*/\1/p")
    FIND_PATTERN=$(echo "$COMMAND" | sed -nE "s/.*find\s+\S+\s+-name\s+['\"]?([^'\"]+)['\"]?.*/\1/p")
    if [[ -n "$FIND_PATH" ]] && [[ -n "$FIND_PATTERN" ]]; then
      REWRITTEN=$(echo "$COMMAND" | sed -E "s/find\s+\S+\s+-name\s+['\"]?[^'\"]+['\"]?/fd '$FIND_PATTERN' $FIND_PATH/")
    fi
  fi
fi

# Replace cat → bat --plain (no decoration, just syntax highlighting)
if uses_tool "cat" "$COMMAND" && command -v bat &>/dev/null; then
  # Only replace simple cat (not cat with flags like -n, -A, etc.)
  if echo "$COMMAND" | grep -qE "(^|[|;&]\s*)cat\s+[^-]" || echo "$COMMAND" | grep -qE "(^|[|;&]\s*)cat\s*$"; then
    REWRITTEN=$(echo "$COMMAND" | sed -E "s/(^|[|;&]\s*)cat(\s)/\1bat --plain --paging=never\2/g")
  fi
fi

# Replace du → dust
if uses_tool "du" "$COMMAND" && command -v dust &>/dev/null; then
  # Replace du -sh or du -h with dust
  if echo "$COMMAND" | grep -qE "(^|[|;&]\s*)du\s+-(s?h|hs)"; then
    REWRITTEN=$(echo "$COMMAND" | sed -E "s/(^|[|;&]\s*)du\s+-(s?h|hs)\s*/\1dust /g")
  fi
fi

# Replace simple sed substitutions → sd
if uses_tool "sed" "$COMMAND" && command -v sd &>/dev/null; then
  # Only replace simple: sed 's/old/new/g' or sed -i 's/old/new/g'
  # Leave complex sed scripts alone
  if echo "$COMMAND" | grep -qE "sed\s+(-i\s+)?'s/" && \
     ! echo "$COMMAND" | grep -qE "sed\s+(-e|--expression|-f|--file)"; then
    # Extract old and new from sed 's/old/new/g'
    SED_OLD=$(echo "$COMMAND" | sed -nE "s/.*sed\s+(-i\s+)?'s\/([^\/]+)\/([^\/]*)\/g?'.*/\2/p")
    SED_NEW=$(echo "$COMMAND" | sed -nE "s/.*sed\s+(-i\s+)?'s\/([^\/]+)\/([^\/]*)\/g?'.*/\3/p")
    SED_FILES=$(echo "$COMMAND" | sed -nE "s/.*sed\s+(-i\s+)?'s\/[^']+'\s+(.*)/\2/p")
    SED_INPLACE=""
    if echo "$COMMAND" | grep -qE "sed\s+-i\s+"; then
      SED_INPLACE="-i"
    fi
    if [[ -n "$SED_OLD" ]]; then
      REWRITTEN="sd $SED_INPLACE '$SED_OLD' '$SED_NEW' $SED_FILES"
    fi
  fi
fi

# If we rewrote the command, return it
if [[ -n "$REWRITTEN" ]] && [[ "$REWRITTEN" != "$COMMAND" ]]; then
  jq -n --arg cmd "$REWRITTEN" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      modifiedToolInput: {
        command: $cmd
      }
    }
  }'
else
  # No rewrite needed, allow as-is
  exit 0
fi
