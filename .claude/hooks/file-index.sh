#!/bin/bash
# ⚡ Lightning Tools — File index hook
# Pre-builds and injects a file tree at session start so Claude can
# orient itself immediately without spending tool calls on glob/grep.
#
# Hook type: SessionStart (matcher: "startup")
# Runs on fresh session starts to front-load codebase awareness.

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────
MAX_FILES=200        # Max files to list in the tree
MAX_DEPTH=4          # Max directory depth
IGNORE_DIRS=".git|node_modules|__pycache__|.venv|venv|dist|build|.next|.nuxt|target|vendor|.cache|coverage|.pytest_cache|.mypy_cache|.tox|.eggs|*.egg-info"

# ── Build file index ──────────────────────────────────────────────

INDEX=""

add_section() {
  local header="$1"
  local body="$2"
  if [[ -n "$body" ]]; then
    INDEX+="## ${header}"$'\n'"${body}"$'\n\n'
  fi
}

# 1. File tree — use fd if available, fall back to find
if command -v fd &>/dev/null; then
  FILE_TREE=$(fd --max-depth "$MAX_DEPTH" --type f \
    --exclude .git --exclude node_modules --exclude __pycache__ \
    --exclude .venv --exclude venv --exclude dist --exclude build \
    --exclude .next --exclude target --exclude vendor --exclude coverage \
    --exclude .cache --exclude .pytest_cache --exclude .mypy_cache \
    2>/dev/null | sort | head -"$MAX_FILES")
elif command -v find &>/dev/null; then
  FILE_TREE=$(find . -maxdepth "$MAX_DEPTH" -type f \
    -not -path '*/.git/*' -not -path '*/node_modules/*' \
    -not -path '*/__pycache__/*' -not -path '*/.venv/*' \
    -not -path '*/dist/*' -not -path '*/build/*' \
    -not -path '*/target/*' -not -path '*/vendor/*' \
    -not -path '*/coverage/*' -not -path '*/.cache/*' \
    2>/dev/null | sed 's|^\./||' | sort | head -"$MAX_FILES")
fi

FILE_COUNT=$(echo "$FILE_TREE" | wc -l)
add_section "File tree (${FILE_COUNT} files, depth ${MAX_DEPTH})" "$FILE_TREE"

# 2. Key files summary — detect and highlight important files
KEY_FILES=""
for f in README.md README.rst CLAUDE.md package.json Cargo.toml go.mod \
         pyproject.toml setup.py setup.cfg requirements.txt Gemfile \
         Makefile CMakeLists.txt Dockerfile docker-compose.yml \
         .github/workflows/*.yml tsconfig.json .eslintrc* .prettierrc* \
         jest.config* vitest.config* webpack.config* vite.config* \
         .env.example .editorconfig; do
  # Use glob to expand wildcards
  for match in $f; do
    if [[ -f "$match" ]]; then
      KEY_FILES+="  $match"$'\n'
    fi
  done
done
add_section "Key files" "$KEY_FILES"

# 3. Source directory breakdown — count files by extension in main dirs
SRC_BREAKDOWN=""
for dir in src lib app components pages api routes handlers models \
           controllers services utils helpers test tests spec __tests__ \
           cmd pkg internal; do
  if [[ -d "$dir" ]]; then
    COUNT=$(find "$dir" -type f 2>/dev/null | wc -l)
    # Get top extensions
    EXTS=$(find "$dir" -type f 2>/dev/null | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -3 | \
           awk '{printf ".%s(%d) ", $2, $1}')
    SRC_BREAKDOWN+="  ${dir}/ — ${COUNT} files [${EXTS}]"$'\n'
  fi
done
add_section "Source directories" "$SRC_BREAKDOWN"

# 4. Recently modified files (last 24h)
RECENT=""
if command -v fd &>/dev/null; then
  RECENT=$(fd --max-depth "$MAX_DEPTH" --type f --changed-within 24h \
    --exclude .git --exclude node_modules --exclude __pycache__ \
    --exclude dist --exclude build --exclude target \
    2>/dev/null | head -20 | sed 's/^/  /')
elif command -v find &>/dev/null; then
  RECENT=$(find . -maxdepth "$MAX_DEPTH" -type f -mtime -1 \
    -not -path '*/.git/*' -not -path '*/node_modules/*' \
    -not -path '*/__pycache__/*' -not -path '*/dist/*' \
    2>/dev/null | sed 's|^\./||' | head -20 | sed 's/^/  /')
fi
add_section "Recently modified (24h)" "$RECENT"

# ── Output ────────────────────────────────────────────────────────
INDEX="# Project file index"$'\n\n'"${INDEX}"
echo "$INDEX"
exit 0
