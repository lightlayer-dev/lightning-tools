#!/bin/bash
# ⚡ Lightning Tools — Auto-approve safe commands
# Skips the permission prompt for read-only and safe Bash commands,
# eliminating the biggest time sink in most Claude Code sessions.
#
# How it works:
#   - Matches commands against a list of known-safe patterns
#   - Returns permissionDecision: "allow" to skip the prompt
#   - Falls through (exit 0) for anything not on the safe list

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [[ "$TOOL_NAME" != "Bash" ]] || [[ -z "$COMMAND" ]]; then
  exit 0
fi

# Strip leading whitespace
COMMAND_TRIMMED=$(echo "$COMMAND" | sed 's/^\s*//')

# ── Safe command patterns ──────────────────────────────────────────
# Read-only / informational commands that can't modify state.
# Each pattern matches the *first* command in a pipeline or chain.

SAFE_PATTERNS=(
  # Git read-only
  "git status"
  "git log"
  "git diff"
  "git show"
  "git branch"
  "git tag"
  "git remote"
  "git rev-parse"
  "git ls-files"
  "git ls-tree"
  "git blame"
  "git stash list"
  "git config --get"
  "git config --list"

  # File/directory inspection
  "ls"
  "pwd"
  "tree"
  "wc "
  "wc$"
  "file "
  "stat "
  "head "
  "tail "
  "cat "
  "bat "
  "less "

  # Search tools (read-only)
  "grep "
  "rg "
  "find "
  "fd "
  "which "
  "whereis "
  "type "

  # System info
  "uname"
  "whoami"
  "hostname"
  "date"
  "uptime"
  "df "
  "du "
  "dust"
  "free"
  "env$"
  "printenv"
  "echo "

  # Package info (read-only)
  "npm list"
  "npm ls"
  "npm outdated"
  "npm view"
  "npm info"
  "npm show"
  "npm explain"
  "npm why"
  "yarn list"
  "yarn info"
  "yarn why"
  "pip list"
  "pip show"
  "pip freeze"
  "pip check"
  "pipenv graph"
  "cargo metadata"
  "cargo tree"
  "go list"
  "go version"
  "go env"
  "rustc --version"
  "node --version"
  "python --version"
  "python3 --version"
  "ruby --version"
  "java -version"

  # Build & test (safe to run, produces output only)
  "npm test"
  "npm run test"
  "npm run lint"
  "npm run check"
  "npm run build"
  "npx tsc --noEmit"
  "npx tsc --version"
  "npx eslint"
  "npx prettier --check"
  "yarn test"
  "yarn lint"
  "yarn build"
  "yarn check"
  "pytest"
  "python -m pytest"
  "python3 -m pytest"
  "cargo test"
  "cargo check"
  "cargo clippy"
  "cargo build"
  "cargo fmt -- --check"
  "go test"
  "go vet"
  "go build"
  "make test"
  "make check"
  "make lint"
  "make build"
  "bundle exec rspec"
  "bundle exec rubocop"

  # Misc safe
  "jq "
  "curl "       # read-only fetches
  "wget -O- "
  "gh pr view"
  "gh pr list"
  "gh pr checks"
  "gh pr diff"
  "gh issue view"
  "gh issue list"
  "gh repo view"
  "gh run view"
  "gh run list"
)

# ── Deny patterns ─────────────────────────────────────────────────
# Commands that look safe but could be destructive in context.
# If any deny pattern matches, we fall through to the permission prompt.

DENY_PATTERNS=(
  "rm "
  "rm$"
  "rmdir"
  "mv "
  "chmod "
  "chown "
  "sudo "
  "su "
  "dd "
  "> "         # output redirection (write)
  ">> "        # append redirection (write)
  "tee "
  "kill "
  "pkill "
  "killall "
  "shutdown"
  "reboot"
  "mkfs"
  "git push"
  "git reset"
  "git clean"
  "git checkout -- "
  "git restore "
  "npm publish"
  "pip install"
  "npm install"  # can modify node_modules + lockfile
  "yarn add"
  "yarn install"
  "cargo install"
  "apt "
  "brew install"
  "brew uninstall"
  "docker rm"
  "docker rmi"
  "kubectl delete"
)

# Check deny patterns first (takes priority)
for pattern in "${DENY_PATTERNS[@]}"; do
  if echo "$COMMAND_TRIMMED" | grep -qE "(^|;|&&|\|\||\|)\s*${pattern}"; then
    exit 0  # Fall through to permission prompt
  fi
done

# Check if the first command in a chain matches a safe pattern
for pattern in "${SAFE_PATTERNS[@]}"; do
  if echo "$COMMAND_TRIMMED" | grep -qE "^${pattern}"; then
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "allow",
        permissionDecisionReason: "Auto-approved: read-only command"
      }
    }'
    exit 0
  fi
done

# Not on the safe list — fall through to permission prompt
exit 0
