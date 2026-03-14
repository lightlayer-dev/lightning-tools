# ⚡ Lightning Tools

Drop-in speed upgrades for Claude Code. Uses Claude Code hooks to make sessions faster — command rewrites, auto-approval, file indexing, and compaction recovery.

> **Note:** Command rewrites only apply to Claude Code's **Bash tool**. Claude Code's built-in tools (Grep, Read, Write, etc.) are already optimized. Lightning Tools catches the cases where Claude Code reaches for standard Unix commands in Bash instead.

## Features

### 1. Command rewrites (`lightning.sh`)

Transparently replaces slow Unix tools with faster modern alternatives:

| Slow | Fast | Speedup |
|------|------|---------|
| `grep` | [`ripgrep`](https://github.com/BurntSushi/ripgrep) (`rg`) | 5-50x |
| `find` | [`fd`](https://github.com/sharkdp/fd) (`fd`) | 5-10x |
| `cat` | [`bat`](https://github.com/sharkdp/bat) (`bat`) | Syntax highlighting + paging |
| `du` | [`dust`](https://github.com/bootandy/dust) (`dust`) | Faster + visual output |
| `sed` | [`sd`](https://github.com/chmln/sd) (`sd`) | Simpler syntax, faster |

### 2. Auto-approve safe commands (`auto-approve.sh`)

Skips the permission prompt for read-only and safe commands — the biggest time sink in most sessions. Covers:

- **Git read-only** — `git status`, `git log`, `git diff`, `git branch`, etc.
- **File inspection** — `ls`, `cat`, `head`, `tail`, `wc`, `tree`, etc.
- **Search** — `grep`, `rg`, `find`, `fd`, `which`, etc.
- **Package info** — `npm list`, `pip show`, `cargo tree`, `go list`, etc.
- **Build & test** — `npm test`, `pytest`, `cargo test`, `make test`, etc.

Destructive commands (`rm`, `sudo`, `git push`, `pip install`, etc.) always go through the permission prompt.

### 3. File index on startup (`file-index.sh`)

Injects a file tree and project overview at session start so Claude can orient itself immediately without spending tool calls on glob/grep. Includes:

- File tree (up to 200 files, depth 4)
- Key files (README, package.json, Cargo.toml, Dockerfile, etc.)
- Source directory breakdown with file counts by extension
- Recently modified files (last 24h)

### 4. Compaction recovery (`compact-context.sh`)

Re-injects critical project context after context window compaction so Claude doesn't lose its bearings. Includes:

- Project type detection (Node, Rust, Go, Python, Ruby)
- Build/test/lint commands
- Git state (branch, recent commits, uncommitted changes)
- Top-level directory structure

## Install

```bash
# 1. Install the fast tools (for command rewrites)
./install.sh

# 2. Copy hooks + settings into your project
./setup.sh /path/to/your/project
```

This adds:
- `.claude/hooks/lightning.sh` — command rewriting (PreToolUse)
- `.claude/hooks/auto-approve.sh` — safe command auto-approval (PreToolUse)
- `.claude/hooks/file-index.sh` — file tree injection (SessionStart)
- `.claude/hooks/compact-context.sh` — compaction recovery (SessionStart)
- Merges hook config into `.claude/settings.json`
- A `CLAUDE.md` hint describing available optimizations

## How it works

Lightning Tools uses Claude Code's hook system at two points:

**PreToolUse hooks** fire before every Bash tool call:
1. `lightning.sh` rewrites slow commands to fast alternatives
2. `auto-approve.sh` skips permission prompts for safe commands

**SessionStart hooks** fire when a session begins:
1. `file-index.sh` runs on fresh starts — injects file tree and project overview
2. `compact-context.sh` runs after compaction — re-injects project context

## Manual setup

If you prefer to set things up yourself:

1. Copy `.claude/hooks/*.sh` to your project's `.claude/hooks/`
2. Add the hook config to your `.claude/settings.json` (see `settings-snippet.json`)
3. Optionally copy `CLAUDE.md` guidance

You can use any subset of the hooks — they're independent. Just include the ones you want in your `settings.json`.

## Uninstall

Remove the hooks from `.claude/settings.json` and delete the scripts from `.claude/hooks/`.

## License

[MIT](LICENSE)
