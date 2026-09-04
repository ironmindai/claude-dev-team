# docs/ — agent-maintained project documentation

This directory is intentionally (almost) empty. **The agents create and maintain
these files themselves** — you don't write them, and neither does the orchestrator.

Copy this folder to `<your-project>/docs/` (or just let agents create `docs/`
on first use). Each specialist owns exactly one file:

| File | Maintained by | Contents |
|---|---|---|
| `backend-routes.md` | backend-coder | Every API route: method, path, params, auth |
| `system-devops-admin.md` | system-devops-admin | Ports, nginx sites, services, packages — a snapshot, not a changelog |
| `scheduled-tasks.md` | scheduled-tasks-coder | Every cron/timer/worker with schedule and log location |
| `database-schema-manager.md` | database-schema-manager | Schema state and migration history |
| `brandbook.md` | frontend-brand-guardian | Colors, typography, spacing, component patterns |
| `workflows.md` | llm-workflow-architect | Every LLM pipeline: steps, models, schemas, costs |
| `headless-http.md` | headless-http-explorer | Observed HTTP/API surface maps of external apps |

Rules (encoded in each agent's definition):
- Each agent reads its file FIRST before acting, and updates it after real changes.
- Agents never create other documentation files without asking.
- Files begin with `> *Maintained by: <agent> agent*` so any LLM knows who to consult.
- These docs are how agents share state without talking to each other — the
  orchestrator checks them before re-spawning an agent for something already done.
