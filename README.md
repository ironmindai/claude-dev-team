# Claude Dev Team

A production-tested pack of **8 specialist subagents + 1 optional agent** for
[Claude Code](https://claude.com/claude-code), plus the orchestration rules and
documentation conventions that make them work as a *team* rather than a pile of
role prompts. Extracted from the daily-driver setup of a working dev shop.

> **🤖 Installing with an AI agent?** Point it at [`INSTALL.md`](INSTALL.md) —
> it contains step-by-step instructions written for an LLM to follow.

## What's in the box

```
claude-dev-team/
├── README.md                ← you are here
├── INSTALL.md               ← machine-followable install guide (humans welcome too)
├── CLAUDE.md.template       ← the glue: routing rules + orchestration policy
├── agents/
│   ├── backend-coder.md
│   ├── frontend-brand-guardian.md
│   ├── frontend-backend-sync-reviewer.md
│   ├── system-devops-admin.md
│   ├── database-schema-manager.md
│   ├── scheduled-tasks-coder.md
│   ├── llm-workflow-architect.md
│   ├── headless-http-explorer.md
│   └── optional/
│       └── ui-browser-debugger.md   (needs a browser automation setup)
├── docs-scaffold/           ← explains the agent-maintained docs/ convention
└── kb/                      ← knowledge-base skeleton (index + article template)
```

## The agents

| Agent | Role |
|---|---|
| **backend-coder** | Server-side code: Python, Node, Go, Rust. APIs, business logic, DB interactions. Maintains `docs/backend-routes.md`. |
| **frontend-brand-guardian** | All frontend code. Enforces (and bootstraps, if missing) `docs/brandbook.md` so every page stays on-brand. |
| **frontend-backend-sync-reviewer** | Runs *after* backend/frontend work to verify every frontend API call has a matching backend route. Catches integration breakage before runtime. |
| **system-devops-admin** | The only agent allowed to touch the system: packages, nginx, SSL, systemd, ports, venvs. Maintains `docs/system-devops-admin.md`. |
| **database-schema-manager** | Sole authority for schema changes — everything goes through reversible Alembic migrations. |
| **scheduled-tasks-coder** | Cron, systemd timers, background workers. Maintains `docs/scheduled-tasks.md`. |
| **llm-workflow-architect** | Designs multi-step LLM pipelines with structured outputs, logging, and cost control. |
| **headless-http-explorer** | Maps the HTTP/API surface of web apps by observing real network traffic (headless only, no scraping tooling). |
| **ui-browser-debugger** *(optional)* | Visual UI debugging with a real browser. Requires a browser automation setup — see the CONFIGURE ME block in the file. |

## The philosophy (why this is a system, not a prompt pack)

Three rules, all encoded in `CLAUDE.md.template` and in the agent files themselves:

1. **Flat call tree.** Only the orchestrator (your main Claude Code conversation)
   spawns agents. Specialists *cannot* spawn each other — their `tools:` lists
   deliberately exclude the Task/Agent tool. When a specialist hits something out
   of scope, it stops and reports back what's needed, and the orchestrator spawns
   the right agent next. This keeps every run auditable and prevents runaway
   agent chains.

2. **Docs as shared memory.** Each specialist owns exactly one file in the
   project's `docs/` folder, reads it before acting, and updates it after real
   changes. That's how agents coordinate without talking to each other, and how
   the orchestrator avoids re-doing work (e.g. re-requesting a port that's
   already allocated). See `docs-scaffold/README.md` for the full table.

3. **Decisions made once, up front.** Ports and Python venvs are allocated by
   the orchestrator via system-devops-admin at the start — never ad hoc by a
   coding agent mid-task. When backend and frontend agents run in parallel on
   the same feature, the orchestrator pre-decides the shared contract (route
   path, payload shape) and puts it in both prompts.

The knowledge base (`kb/`) is the fourth pillar: a user-level index of
integration articles (`~/.claude/kb-index.md`) that any agent in any project can
consult. The pack ships the skeleton and an article template; you fill it with
your own integrations over time.

## Installation

### User level (recommended)

Agents live in `~/.claude/agents/` and the rules in `~/.claude/CLAUDE.md`, so
the whole team is available in **every project** on your machine:

```bash
git clone https://github.com/ironmindai/claude-dev-team.git
cd claude-dev-team

# 1. Agents
mkdir -p ~/.claude/agents
cp agents/*.md ~/.claude/agents/
# optional agent, only if you have browser automation set up:
# cp agents/optional/ui-browser-debugger.md ~/.claude/agents/

# 2. CLAUDE.md — merge, don't clobber
#    If ~/.claude/CLAUDE.md exists, merge the template's sections into it.
#    If not:
cp CLAUDE.md.template ~/.claude/CLAUDE.md

# 3. Knowledge base skeleton
mkdir -p ~/.claude/kb/scripts
cp kb/kb-index.md ~/.claude/kb-index.md
cp kb/_article-template.md ~/.claude/kb/
```

Then open `~/.claude/CLAUDE.md` and `~/.claude/agents/system-devops-admin.md`
and fill in the **CONFIGURE ME** placeholders (company name, dev server domain).

### Project level (quick trial)

Want to test-drive without touching your global setup? Everything also works
scoped to a single project:

```bash
mkdir -p <project>/.claude/agents
cp agents/*.md <project>/.claude/agents/
cp CLAUDE.md.template <project>/CLAUDE.md   # or merge into existing
cp -r docs-scaffold <project>/docs           # optional; agents create docs/ anyway
```

Project-level agents override user-level ones with the same name, so you can
trial here and promote to `~/.claude/` later. The KB is the one piece that's
inherently user-level (`~/.claude/kb-index.md`) — at project level, either skip
it or adjust the KB paths in your project CLAUDE.md.

**Rule of thumb: user level is the intended deployment; project level is the demo.**

## Configuration checklist

After copying files, before first use:

- [ ] `CLAUDE.md` — fill in `{{YOUR_COMPANY}}` in About Us; delete the header comment
- [ ] `agents/system-devops-admin.md` — replace `{{DEV_SERVER_FQDN}}` with your dev server's domain; review the SUDO ACCESS section against your actual sudoers setup
- [ ] `agents/optional/ui-browser-debugger.md` — only install if you have a browser automation service or MCP; follow its CONFIGURE ME block
- [ ] `~/.claude/kb-index.md` — replace example entries as you add real articles

Everything else works with zero configuration.

## Requirements

- Claude Code (CLI, desktop, or IDE)
- For **system-devops-admin**: a Linux dev server where your user has (ideally
  passwordless) sudo for nginx/certbot/systemctl/apt — the agent verifies with
  `sudo -l` before assuming anything
- For **database-schema-manager**: Python projects using SQLAlchemy + Alembic
  (adapt the file if your stack differs)
- For **headless-http-explorer**: it installs Playwright/Puppeteer itself when needed
- For **ui-browser-debugger** (optional): a browser automation setup (cloud
  browser service or a local browser MCP server)

## FAQ

**Do I need all the agents?** No. Each file is standalone — delete what you
don't use and remove its routing line from CLAUDE.md. The core four are
backend-coder, frontend-brand-guardian, system-devops-admin, and
frontend-backend-sync-reviewer.

**Can agents really not spawn each other?** Correct — none of their `tools:`
frontmatter lists include the Task tool, so it's enforced by the harness, not
by prompt hope.

**Why do agents keep writing to docs/?** That's the feature. The docs are the
team's shared memory across sessions. Commit them.

**My CLAUDE.md already has content.** Merge the template's sections in
(Agent Usage, Knowledge Base, Project Documentation, Development Practices).
Never blind-overwrite an existing CLAUDE.md.

## License

MIT — use it, fork it, ship it to your own team.
