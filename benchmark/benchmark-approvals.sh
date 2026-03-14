#!/bin/bash
# ⚡ Lightning Tools — Auto-Approval Benchmark
# Measures how many commands would be auto-approved vs. sent to the
# permission prompt, and estimates time saved per session.
#
# Usage: ./benchmark/benchmark-approvals.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/../.claude/hooks/auto-approve.sh"

if [[ ! -x "$HOOK_SCRIPT" ]]; then
  echo "Error: auto-approve.sh not found at $HOOK_SCRIPT"
  exit 1
fi

# ── Representative command set ────────────────────────────────────
# Covers all categories: safe, deny, and unknown commands.
# Format: "category|command"

TEST_COMMANDS=(
  # Git read-only (should approve)
  "git-readonly|git status"
  "git-readonly|git log --oneline -10"
  "git-readonly|git diff HEAD~1"
  "git-readonly|git show HEAD"
  "git-readonly|git branch -a"
  "git-readonly|git rev-parse HEAD"
  "git-readonly|git blame README.md"
  "git-readonly|git stash list"

  # File inspection (should approve)
  "file-inspect|ls -la"
  "file-inspect|ls src/"
  "file-inspect|cat README.md"
  "file-inspect|head -20 setup.sh"
  "file-inspect|tail -f /var/log/syslog"
  "file-inspect|wc -l *.sh"
  "file-inspect|tree -L 2"
  "file-inspect|file install.sh"

  # Search (should approve)
  "search|grep -rn TODO ."
  "search|rg -n import src/"
  "search|find . -name '*.sh' -type f"
  "search|fd --type f '.sh$'"
  "search|which node"

  # System info (should approve)
  "sysinfo|uname -a"
  "sysinfo|whoami"
  "sysinfo|date"
  "sysinfo|df -h"
  "sysinfo|du -sh ."
  "sysinfo|echo hello"
  "sysinfo|pwd"

  # Package info (should approve)
  "pkg-info|npm list --depth=0"
  "pkg-info|pip show requests"
  "pkg-info|cargo tree"
  "pkg-info|go version"
  "pkg-info|node --version"
  "pkg-info|python3 --version"

  # Build & test (should approve)
  "build-test|npm test"
  "build-test|npm run lint"
  "build-test|npm run build"
  "build-test|pytest -v"
  "build-test|cargo test --lib"
  "build-test|cargo check"
  "build-test|go test ./..."
  "build-test|make test"
  "build-test|make build"

  # Misc safe (should approve)
  "misc-safe|curl https://api.example.com/status"
  "misc-safe|gh pr list"
  "misc-safe|gh pr view 123"
  "misc-safe|jq '.name' package.json"

  # Destructive (should block)
  "destructive|rm -rf node_modules"
  "destructive|rm temp.txt"
  "destructive|rmdir empty_dir"
  "destructive|mv old.txt new.txt"
  "destructive|chmod 755 script.sh"
  "destructive|sudo apt update"
  "destructive|kill -9 1234"
  "destructive|pkill node"

  # Git write (should block)
  "git-write|git push origin main"
  "git-write|git reset --hard HEAD~1"
  "git-write|git clean -fd"
  "git-write|git checkout -- ."

  # Package install (should block)
  "pkg-install|npm install express"
  "pkg-install|pip install requests"
  "pkg-install|yarn add lodash"
  "pkg-install|cargo install ripgrep"
  "pkg-install|brew install fd"

  # Redirections (should block)
  "redirect|echo hello > output.txt"
  "redirect|cat file.txt >> log.txt"
  "redirect|tee output.log"

  # Unknown (should fall through to prompt)
  "unknown|ansible-playbook deploy.yml"
  "unknown|terraform apply"
  "unknown|docker run -it ubuntu bash"
  "unknown|ssh user@server"
)

# ── Run tests ─────────────────────────────────────────────────────

# Category counters (associative arrays)
declare -A CAT_TOTAL
declare -A CAT_APPROVED

APPROVED=0
PROMPTED=0
TOTAL=${#TEST_COMMANDS[@]}

echo ""
echo "⚡ Lightning Tools — Auto-Approval Benchmark"
echo "  Testing ${TOTAL} representative commands"
echo ""
printf "  %-10s %-50s %s\n" "Result" "Command" "Category"
echo "  ──────────────────────────────────────────────────────────────────"

for entry in "${TEST_COMMANDS[@]}"; do
  category="${entry%%|*}"
  cmd="${entry#*|}"

  # Initialize category counters
  CAT_TOTAL["$category"]=$(( ${CAT_TOTAL["$category"]:-0} + 1 ))

  # Build JSON input
  INPUT=$(jq -n --arg cmd "$cmd" '{tool_name: "Bash", tool_input: {command: $cmd}}')

  # Run through hook
  RESULT=$(echo "$INPUT" | bash "$HOOK_SCRIPT" 2>/dev/null) || true

  if echo "$RESULT" | jq -e '.hookSpecificOutput.permissionDecision == "allow"' &>/dev/null 2>&1; then
    printf "  %-10s %-50s %s\n" "APPROVED" "$cmd" "$category"
    APPROVED=$((APPROVED + 1))
    CAT_APPROVED["$category"]=$(( ${CAT_APPROVED["$category"]:-0} + 1 ))
  else
    printf "  %-10s %-50s %s\n" "PROMPT" "$cmd" "$category"
    PROMPTED=$((PROMPTED + 1))
  fi
done

# ── Category summary ──────────────────────────────────────────────
echo ""
echo "  Category Breakdown"
echo "  ──────────────────────────────────────────────────────────────────"

# Sort categories for consistent output
CATEGORIES=(git-readonly file-inspect search sysinfo pkg-info build-test misc-safe destructive git-write pkg-install redirect unknown)

for cat in "${CATEGORIES[@]}"; do
  total=${CAT_TOTAL["$cat"]:-0}
  approved=${CAT_APPROVED["$cat"]:-0}
  if [[ "$total" -gt 0 ]]; then
    pct=$(awk "BEGIN{printf \"%.0f\", ($approved / $total) * 100}")
    printf "    %-16s %2d/%2d approved (%3s%%)\n" "$cat" "$approved" "$total" "$pct"
  fi
done

# ── Summary ───────────────────────────────────────────────────────
APPROVAL_RATE=$(awk "BEGIN{printf \"%.1f\", ($APPROVED / $TOTAL) * 100}")

echo ""
echo "  Summary"
echo "  ──────────────────────────────────────────────────────────────────"
echo "    Auto-approved:     $APPROVED/$TOTAL ($APPROVAL_RATE%)"
echo "    Permission prompt: $PROMPTED/$TOTAL"
echo ""
echo "  Estimated Time Savings"
echo "  ──────────────────────────────────────────────────────────────────"
echo "    Average permission prompt delay: ~2-3 seconds"
echo "    Per 50 Bash calls/session (typical):"

# Estimate: if APPROVAL_RATE% of commands are auto-approved
CMDS_SAVED=$(awk "BEGIN{printf \"%.0f\", 50 * $APPROVAL_RATE / 100}")
TIME_SAVED_LOW=$((CMDS_SAVED * 2))
TIME_SAVED_HIGH=$((CMDS_SAVED * 3))
echo "      ~$CMDS_SAVED prompts skipped → ${TIME_SAVED_LOW}-${TIME_SAVED_HIGH}s saved"

CMDS_SAVED_100=$(awk "BEGIN{printf \"%.0f\", 100 * $APPROVAL_RATE / 100}")
TIME_SAVED_LOW_100=$((CMDS_SAVED_100 * 2))
TIME_SAVED_HIGH_100=$((CMDS_SAVED_100 * 3))
echo "    Per 100 Bash calls/session (heavy):"
echo "      ~$CMDS_SAVED_100 prompts skipped → ${TIME_SAVED_LOW_100}-${TIME_SAVED_HIGH_100}s saved"
echo ""
