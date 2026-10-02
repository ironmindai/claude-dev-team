# INSTALL.md — instructions for AI agents (and humans)

> **If you are an AI coding agent** (Claude Code, Cursor, Codex, etc.) asked to
> install this pack: follow the steps below exactly. They are written for you.
> Key rules: **never overwrite an existing CLAUDE.md — merge**; **ask the user
> the 3 questions in Step 0 before writing anything**; **verify each step**.

## Step 0 — Ask the user (or infer, then confirm)

1. **Scope**: user-level (`~/.claude/`, applies to all projects — recommended)
   or project-level (`<project>/.claude/`, quick trial)?
2. **Dev server domain** for system-devops-admin (e.g. `dev.example.com`).
   If they have no shared dev server / nginx setup, still install the agent but
   tell them to review it before use.
3. **Optional agent**: do they have browser automation (a cloud browser service
   or a local browser MCP like Playwright MCP)? Only install
   `agents/optional/ui-browser-debugger.md` if yes.

Also capture the company/team name for the CLAUDE.md "About Us" section.

## Step 1 — Copy agent files

User-level:
```bash
mkdir -p ~/.claude/agents
cp agents/*.md ~/.claude/agents/
```
Project-level: same, into `<project>/.claude/agents/`.

**Conflict rule**: if a target filename already exists, do NOT overwrite it.
Show the user a diff and ask.

## Step 2 — Install or merge CLAUDE.md

Target: `~/.claude/CLAUDE.md` (user-level) or `<project>/CLAUDE.md` (project-level).

- If the target does **not** exist: copy `CLAUDE.md.template` there, fill in
  `{{YOUR_COMPANY}}`, delete the template's header comment block.
- If it **exists**: read it, then merge in these sections without destroying
  existing content: `## Agent Usage`, `## Knowledge Base`,
  `## Project Documentation`, `## Development Practices`. If a section already
  exists, append the pack's bullet points that aren't already covered; do not
  duplicate rules. Show the user the resulting diff.

The two rules that MUST survive any merge (they're what makes the pack work):
1. The **NO SUBAGENT-TO-SUBAGENT SPAWNING** block.
2. The **orchestrator owns venv/port allocation via system-devops-admin** rules.

## Step 3 — Configure placeholders

- In the installed `system-devops-admin.md`: replace every `{{DEV_SERVER_FQDN}}`
  with the user's dev domain from Step 0, then delete the `CONFIGURE ME`
  comment block.
- In the installed CLAUDE.md: `{{YOUR_COMPANY}}` → their team name.
- If installing ui-browser-debugger: follow its own `CONFIGURE ME` block
  (choose cloud-browser vs local-MCP mode, delete the inapplicable sections).

## Step 4 — Knowledge base (user-level installs only)

```bash
mkdir -p ~/.claude/kb/scripts
cp kb/_article-template.md ~/.claude/kb/
[ -f ~/.claude/kb-index.md ] || cp kb/kb-index.md ~/.claude/kb-index.md
```
If `~/.claude/kb-index.md` already exists, leave it alone.

For project-level installs, skip this step and remove the
`## Knowledge Base` section from the project CLAUDE.md (it references
user-level paths).

## Step 4b — Status line (optional, ask the user first)

A custom two-line status line (context bar, git branch, plan usage). Offer it;
if the user says yes, follow [`statusline/README.md`](statusline/README.md)
exactly — it covers requirements, conflict handling, installation and verification.

## Step 5 — Verify

1. `ls ~/.claude/agents/` (or the project equivalent) — 8 files present
   (9 with the optional agent).
2. `grep -c '{{' <each installed file>` — must be 0 (no unfilled placeholders,
   except kb/_article-template.md which keeps its `{{...}}` intentionally).
3. Confirm no agent file's frontmatter `tools:` list contains `Task` or
   `Agent` — this is the flat-call-tree enforcement. (`grep -l 'tools:.*Task' ~/.claude/agents/*.md` should return nothing; note ui-browser-debugger has no
   tools line at all, which is fine.)
4. In a new Claude Code session, ask: *"what agents do you have available?"* —
   the specialist agents should be listed.
5. Report to the user: what was installed where, what was merged (with diff),
   and which placeholders were filled with what values.

## What NOT to do

- Do not overwrite existing CLAUDE.md, kb-index.md, or agent files without showing a diff and asking.
- Do not install ui-browser-debugger without a working browser automation setup.
- Do not add the Task/Agent tool to any specialist's `tools:` list — subagent-to-subagent spawning is intentionally impossible.
- Do not invent extra documentation files; the agents manage `docs/` themselves.
- Do not commit real credentials into KB articles if the KB is ever shared/published.
