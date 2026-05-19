---
tags: [memory/repo, index]
---

# Docs index

Routing table. The repo's [CLAUDE.md](../CLAUDE.md) is the entry point — it lists conventions and commands; this folder is the deeper reference.

## When you don't know where to look

| You need to … | Read |
|---|---|
| Avoid a footgun, understand a non-obvious behaviour | [gotchas.md](gotchas.md) |
| Understand stack, layout, env, deploy | [architecture.md](architecture.md) |
| Follow code conventions (naming, style, commits) | [conventions.md](conventions.md) |

<!-- Add rows as you add files:
     | Make an API call | api.md |
     | Modify a Pinia store | stores.md |
     | Build a UI primitive | ui-components.md |
     | Recipe for common task | cookbook.md |
     | Recurring code pattern | patterns.md | -->

## Maintenance rules

- **Add to `.claude-docs/`** when you discover a new pattern, gotcha, store, composable, endpoint group, or component category — anything other agents/humans need to know about this codebase.
- **Add to `CLAUDE.md`** only when a top-level command, convention, or MUST/MUST NOT changes. Keep it short — it's the entry point, not the manual.
- **Use account-local memory** (`~/.claude/memory/IDENTITY.md`, `~/.claude/projects/<slug>/memory/SESSION.md`) for personal preferences and per-task scratch — not for codebase facts. Codebase facts go here.
- **Server agents see only git-tracked files.** If you find a contradiction between code and docs, fix the doc as part of your task.
