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

# Only process Bash tool calls with a command
if [[ "$TOOL_NAME" != "Bash" ]] || [[ -z "$COMMAND" ]]; then
  exit 0
fi

REWRITTEN=""

# Helper: check if a command uses a tool as a standalone command
# Matches: starts with tool, or appears after pipe/semicolon/&&/||
uses_tool() {
  local tool="$1"
  local cmd="$2"
  echo "$cmd" | grep -qE "(^|\||;|&&|\|\|)\s*${tool}(\s|$)"
}

# Replace grep → rg
if uses_tool "grep" "$COMMAND" && command -v rg &>/dev/null; then
  REWRITTEN=$(echo "$COMMAND" | sed -E "s/(^|\||;|&&|\|\|)(\s*)grep(\s)/\1\2rg\3/g")
fi

# Replace find → fd (simple patterns only)
if uses_tool "find" "$COMMAND" && command -v fd &>/dev/null; then
  # Only replace simple: find <path> -name "pattern" [-type f/d]
  # Leave complex expressions alone (-exec, -delete, -print0, etc.)
  if echo "$COMMAND" | grep -qE "find\s+\S+\s+-name\s+" && \
     ! echo "$COMMAND" | grep -qE "-exec|-delete|-print0|-newer|-perm|-prune|-regex"; then
    FIND_PATH=$(echo "$COMMAND" | sed -nE "s/.*find\s+(\S+)\s+-name\s+.*/\1/p")
    FIND_PATTERN=$(echo "$COMMAND" | sed -nE "s/.*find\s+\S+\s+-name\s+['\"]?([^'\"]+)['\"]?.*/\1/p")
    FIND_TYPE=""
    if echo "$COMMAND" | grep -qE "\s-type\s+f"; then
      FIND_TYPE="--type f"
    elif echo "$COMMAND" | grep -qE "\s-type\s+d"; then
      FIND_TYPE="--type d"
    fi
    if [[ -n "$FIND_PATH" ]] && [[ -n "$FIND_PATTERN" ]]; then
      REWRITTEN=$(echo "$COMMAND" | sed -E "s/find\s+\S+\s+-name\s+['\"]?[^'\"]+['\"]?(\s+-type\s+[fd])?/fd $FIND_TYPE '$FIND_PATTERN' $FIND_PATH/")
    fi
  fi
fi

# Replace cat → bat --plain (no decoration)
if uses_tool "cat" "$COMMAND" && command -v bat &>/dev/null; then
  # Only replace simple cat <file> (not cat with flags like -n, -A, -e, etc.)
  if echo "$COMMAND" | grep -qE "(^|\||;|&&|\|\|)\s*cat\s+[^-]"; then
    REWRITTEN=$(echo "$COMMAND" | sed -E "s/(^|\||;|&&|\|\|)(\s*)cat(\s)/\1\2bat --plain --paging=never\3/g")
  fi
fi

# Replace du -sh / du -h → dust
if uses_tool "du" "$COMMAND" && command -v dust &>/dev/null; then
  if echo "$COMMAND" | grep -qE "(^|\||;|&&|\|\|)\s*du\s+-(s?h|hs)"; then
    REWRITTEN=$(echo "$COMMAND" | sed -E "s/(^|\||;|&&|\|\|)(\s*)du\s+-(s?h|hs)\s*/\1\2dust /g")
  fi
fi

# Replace simple sed 's/old/new/g' → sd
if uses_tool "sed" "$COMMAND" && command -v sd &>/dev/null; then
  # Only replace simple: sed [-i] 's/old/new/[g]' <files>
  # Leave complex sed scripts alone (-e, -f, multiple expressions, etc.)
  if echo "$COMMAND" | grep -qE "sed\s+(-i\s+)?'s/" && \
     ! echo "$COMMAND" | grep -qE "sed\s+(-e|--expression|-f|--file)"; then
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

# If we rewrote the command, return it using the correct Claude Code hook format
if [[ -n "$REWRITTEN" ]] && [[ "$REWRITTEN" != "$COMMAND" ]]; then
  jq -n --arg cmd "$REWRITTEN" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      updatedInput: {
        command: $cmd
      }
    }
  }'
else
  # No rewrite needed, allow as-is
  exit 0
fi
