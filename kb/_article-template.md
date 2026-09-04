# {{Service or Tool Name}}

<!-- KB article template. One article = one integration/tool/pattern.
Keep it operational: an agent should be able to use the service after
reading only this file. NEVER commit real credentials to a public repo —
in your private ~/.claude/kb/ they can live here or point to an env file. -->

## What it is
One or two sentences: what this service/tool does and why we use it.

## Credentials / Access
- Where credentials live (env var name, credentials file path — not the values themselves if this file is shared)
- Account/tenant identifiers if relevant

## How to use
Minimal working example (curl or script invocation):

```bash
curl -s https://api.example.com/v1/thing \
  -H "Authorization: Bearer $EXAMPLE_API_KEY"
```

## Gotchas
- Rate limits, quirks, error modes, things that cost real debugging time.

## Related
- Scripts: `~/.claude/kb/scripts/example.py`
- Docs: https://docs.example.com
