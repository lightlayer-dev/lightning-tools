# Lightning Tools

## Git

- Always add co-author trailer to commits:
  `Co-authored-by: Isaac Chang <chang.isaac97@gmail.com>`

## Project

- All hooks are shell scripts in `.claude/hooks/`
- Hooks must be executable (`chmod +x`)
- Benchmarks live in `benchmark/`
- Keep hooks independent — each should work standalone without the others
- Use `set -euo pipefail` in all scripts
- Test hooks by piping JSON through stdin: `echo '{"tool_name":"Bash","tool_input":{"command":"..."}}' | .claude/hooks/hook.sh`
