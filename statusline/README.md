# Status line — install guide (for humans and AI agents)

A two-line custom status line for Claude Code:

```
Opus 4 | my-project (main) | ~12.3k loc | 34% 68k/200k [######--------------] | api:4m12s | v2.x | +120 -30
Stockholm 10:27 Fri 02 Oct | 5 Hour Usage: 4% → 10:39  |  7 Day Usage: 21% → Mon 06:59
```

Line 1: model, project, git branch, lines of code, context-window usage bar,
API time, Claude Code version, lines added/removed.
Line 2: local time and Claude Max plan usage (5-hour and 7-day windows, with reset times).

## Instructions for an AI agent

Follow in order. Do not skip the confirmation in step 2.

1. **Check requirements.** Run `command -v jq git curl python3`. All four must
   exist; if any is missing, tell the user and offer to install it (e.g.
   `sudo apt install jq`). `tokei` is optional (LOC count); if absent the LOC
   segment is simply omitted. Mention `cargo install tokei` if they want it.
2. **Check for an existing status line.** Read `~/.claude/settings.json`. If a
   `statusLine` key already exists, show it to the user and ask before replacing it.
3. **Install the script** (from the repo root):
   ```bash
   mkdir -p ~/.claude
   cp statusline/statusline.sh ~/.claude/statusline.sh
   chmod +x ~/.claude/statusline.sh
   ```
   If `~/.claude/statusline.sh` already exists, show a diff and ask first.
4. **Merge the setting** into `~/.claude/settings.json`. Preserve every existing
   key; create the file as `{}` first if it doesn't exist. Use `jq` rather than
   hand-editing:
   ```bash
   f=~/.claude/settings.json; [ -f "$f" ] || echo '{}' > "$f"
   jq --arg cmd "/bin/bash $HOME/.claude/statusline.sh" \
      '.statusLine = {"type":"command","command":$cmd}' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
   ```
5. **Verify** with sample input (should print two colored lines, or one if not
   logged in with a Claude subscription):
   ```bash
   echo '{"model":{"display_name":"Test"},"workspace":{"project_dir":"/tmp/x"},"context_window":{"used_percentage":12,"context_window_size":200000}}' \
     | bash ~/.claude/statusline.sh
   ```
   Then tell the user to restart Claude Code (or open a new session) to see it.

## Notes

- **Plan usage (line 2)** reads the user's own OAuth token from
  `$CLAUDE_CODE_OAUTH_TOKEN`, `~/.claude/.credentials.json`, or the GNOME keyring,
  and calls `api.anthropic.com` only. Results are cached 60 s in
  `/tmp/claude-statusline/` with back-off on rate limits. API-key users with no
  subscription simply get no line 2.
- **LOC count** is cached for 10 minutes and only runs inside a git repo.
- Nothing in this script is machine-specific; no edits are needed.
