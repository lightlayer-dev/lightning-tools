# ⚡ Lightning Tools

Drop-in speed upgrades for Claude Code. Replaces slow standard Unix tools with faster modern alternatives using Claude Code hooks.

When Claude Code tries to use `grep`, `find`, `cat`, or `du`, the hook intercepts the call and rewrites it to use `ripgrep`, `fd`, `bat`, or `dust` instead — automatically and transparently.

## What gets replaced

| Slow | Fast | Speedup |
|------|------|---------|
| `grep` | [`ripgrep`](https://github.com/BurntSushi/ripgrep) (`rg`) | 5-50x |
| `find` | [`fd`](https://github.com/sharkdp/fd) (`fd`) | 5-10x |
| `cat` | [`bat`](https://github.com/sharkdp/bat) (`bat`) | Syntax highlighting + paging |
| `du` | [`dust`](https://github.com/bootandy/dust) (`dust`) | Faster + visual output |
| `sed` | [`sd`](https://github.com/chmln/sd) (`sd`) | Simpler syntax, faster |

## Install

```bash
# 1. Install the fast tools
./install.sh

# 2. Copy hook + settings into your project
./setup.sh /path/to/your/project
```

This adds:
- `.claude/hooks/lightning.sh` — the PreToolUse hook that rewrites commands
- Merges hook config into `.claude/settings.json`
- A `CLAUDE.md` hint so Claude Code knows the fast tools are available

## How it works

Claude Code fires a `PreToolUse` hook before every `Bash` tool call. Our hook:

1. Reads the command from stdin (JSON)
2. Checks if it uses a slow tool (`grep`, `find`, etc.)
3. Rewrites the command to use the fast alternative
4. Returns the rewritten command via `hookSpecificOutput`

Claude Code then executes the fast version instead. No prompt engineering, no hoping the model picks the right tool — it's deterministic.

## Manual setup

If you prefer to set things up yourself:

1. Copy `.claude/hooks/lightning.sh` to your project
2. Add the hook config to your `.claude/settings.json` (see `settings-snippet.json`)
3. Optionally copy `CLAUDE.md` guidance

## Uninstall

Remove the hook from `.claude/settings.json` and delete `.claude/hooks/lightning.sh`.

## License

MIT
