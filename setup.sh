#!/bin/bash
# ⚡ Lightning Tools — Set up hooks in a project
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-.}"

if [[ ! -d "$TARGET" ]]; then
  echo "Error: $TARGET is not a directory"
  exit 1
fi

TARGET="$(cd "$TARGET" && pwd)"
echo "⚡ Setting up lightning tools in $TARGET"

# 1. Copy hook script
mkdir -p "$TARGET/.claude/hooks"
cp "$SCRIPT_DIR/.claude/hooks/lightning.sh" "$TARGET/.claude/hooks/lightning.sh"
chmod +x "$TARGET/.claude/hooks/lightning.sh"
echo "  ✓ Copied hook to .claude/hooks/lightning.sh"

# 2. Merge settings
SETTINGS="$TARGET/.claude/settings.json"
if [[ -f "$SETTINGS" ]]; then
  # Merge hook config into existing settings
  if command -v jq &>/dev/null; then
    TEMP=$(mktemp)
    jq -s '.[0] * .[1]' "$SETTINGS" "$SCRIPT_DIR/settings-snippet.json" > "$TEMP"
    mv "$TEMP" "$SETTINGS"
    echo "  ✓ Merged hook config into existing .claude/settings.json"
  else
    echo "  ⚠ jq not found — please manually add contents of settings-snippet.json to $SETTINGS"
  fi
else
  cp "$SCRIPT_DIR/settings-snippet.json" "$SETTINGS"
  echo "  ✓ Created .claude/settings.json with hook config"
fi

# 3. Add CLAUDE.md hint if not present
CLAUDE_MD="$TARGET/CLAUDE.md"
HINT="
## ⚡ Lightning Tools

This project uses lightning-tools hooks that automatically replace slow Unix commands with faster alternatives:
- \`grep\` → \`rg\` (ripgrep) — much faster recursive search
- \`find\` → \`fd\` — simpler syntax, faster file finding
- \`cat\` → \`bat\` — syntax-highlighted output
- \`du\` → \`dust\` — visual disk usage
- \`sed\` → \`sd\` — simpler find-and-replace

You can use the fast tools directly in your commands for best results.
"

if [[ -f "$CLAUDE_MD" ]]; then
  if ! grep -q "Lightning Tools" "$CLAUDE_MD"; then
    echo "$HINT" >> "$CLAUDE_MD"
    echo "  ✓ Appended lightning tools hint to CLAUDE.md"
  else
    echo "  ✓ CLAUDE.md already has lightning tools hint"
  fi
else
  echo "$HINT" > "$CLAUDE_MD"
  echo "  ✓ Created CLAUDE.md with lightning tools hint"
fi

echo ""
echo "⚡ Done! Lightning tools are ready in $TARGET"
echo "  Run 'install.sh' first if you haven't installed the fast tools yet."
