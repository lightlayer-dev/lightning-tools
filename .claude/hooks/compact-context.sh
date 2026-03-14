#!/bin/bash
# ⚡ Lightning Tools — Context-aware compaction hook
# Re-injects critical project context after context window compaction,
# so Claude doesn't lose its bearings and waste tool calls re-orienting.
#
# Hook type: SessionStart (matcher: "compact")
# Runs only when a session resumes after compaction, not on fresh starts.

set -euo pipefail

# ── Gather project context ────────────────────────────────────────

CONTEXT=""

add_section() {
  local header="$1"
  local body="$2"
  if [[ -n "$body" ]]; then
    CONTEXT+="## ${header}"$'\n'"${body}"$'\n\n'
  fi
}

# 1. Detect project type and key files
PROJECT_TYPE=""
BUILD_CMD=""
TEST_CMD=""
LINT_CMD=""

if [[ -f "package.json" ]]; then
  PROJECT_TYPE="Node.js"
  # Extract scripts from package.json
  SCRIPTS=$(jq -r '.scripts // {} | to_entries[] | "  \(.key): \(.value)"' package.json 2>/dev/null | head -15)
  add_section "npm scripts" "$SCRIPTS"

  # Detect common test/build/lint commands
  TEST_CMD=$(jq -r '.scripts.test // empty' package.json 2>/dev/null)
  BUILD_CMD=$(jq -r '.scripts.build // empty' package.json 2>/dev/null)
  LINT_CMD=$(jq -r '.scripts.lint // empty' package.json 2>/dev/null)
fi

if [[ -f "Cargo.toml" ]]; then
  PROJECT_TYPE="Rust"
  TEST_CMD="cargo test"
  BUILD_CMD="cargo build"
  LINT_CMD="cargo clippy"
fi

if [[ -f "go.mod" ]]; then
  PROJECT_TYPE="Go"
  MODULE=$(head -1 go.mod | sed 's/^module //')
  add_section "Go module" "$MODULE"
  TEST_CMD="go test ./..."
  BUILD_CMD="go build ./..."
  LINT_CMD="go vet ./..."
fi

if [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]] || [[ -f "requirements.txt" ]]; then
  PROJECT_TYPE="Python"
  if [[ -f "pyproject.toml" ]]; then
    PROJECT_NAME=$(grep '^name' pyproject.toml 2>/dev/null | head -1 | sed 's/.*= *"\(.*\)"/\1/')
    add_section "Python project" "$PROJECT_NAME"
  fi
  TEST_CMD="pytest"
  LINT_CMD="ruff check ."
fi

if [[ -f "Gemfile" ]]; then
  PROJECT_TYPE="Ruby"
  TEST_CMD="bundle exec rspec"
  LINT_CMD="bundle exec rubocop"
fi

if [[ -f "Makefile" ]]; then
  TARGETS=$(grep -E '^[a-zA-Z_-]+:' Makefile 2>/dev/null | sed 's/:.*//' | head -15 | sed 's/^/  /')
  add_section "Makefile targets" "$TARGETS"
fi

# 2. Quick commands reference
COMMANDS=""
[[ -n "$TEST_CMD" ]] && COMMANDS+="  Test:  $TEST_CMD"$'\n'
[[ -n "$BUILD_CMD" ]] && COMMANDS+="  Build: $BUILD_CMD"$'\n'
[[ -n "$LINT_CMD" ]] && COMMANDS+="  Lint:  $LINT_CMD"$'\n'
add_section "Quick commands" "$COMMANDS"

# 3. Git state
if git rev-parse --git-dir &>/dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null)
  RECENT_COMMITS=$(git log --oneline -5 2>/dev/null)
  DIRTY=$(git status --porcelain 2>/dev/null | head -10)

  GIT_STATE="  Branch: $BRANCH"$'\n'
  if [[ -n "$DIRTY" ]]; then
    GIT_STATE+="  Uncommitted changes:"$'\n'"$(echo "$DIRTY" | sed 's/^/    /')"$'\n'
  fi
  GIT_STATE+="  Recent commits:"$'\n'"$(echo "$RECENT_COMMITS" | sed 's/^/    /')"
  add_section "Git state" "$GIT_STATE"
fi

# 4. Directory structure (top-level only, fast)
STRUCTURE=$(ls -1 2>/dev/null | head -25 | sed 's/^/  /')
add_section "Top-level files" "$STRUCTURE"

# 5. Project type summary
if [[ -n "$PROJECT_TYPE" ]]; then
  CONTEXT="# Post-compaction context (${PROJECT_TYPE} project)"$'\n\n'"${CONTEXT}"
else
  CONTEXT="# Post-compaction context"$'\n\n'"${CONTEXT}"
fi

# ── Output ────────────────────────────────────────────────────────
# stdout is injected as context on exit 0
echo "$CONTEXT"
exit 0
