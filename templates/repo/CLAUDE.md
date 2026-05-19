# CLAUDE.md — <PROJECT NAME>

Entry point for Claude Code agents (interactive or headless). For deeper reference, see [`.claude-docs/`](.claude-docs/index.md).

<!-- This file is auto-loaded into every session whose cwd is inside this repo.
     Keep it THIN — bloated entries eat context across every session.
     Anything thick goes in .claude-docs/<file>.md, indexed below. -->

## Documentation index

- [.claude-docs/index.md](.claude-docs/index.md) — start here when unsure where to look
- [.claude-docs/gotchas.md](.claude-docs/gotchas.md) — non-obvious footguns, "looks wrong but is intentional"
- [.claude-docs/architecture.md](.claude-docs/architecture.md) — stack, layout, dirs, env, deploy
- [.claude-docs/conventions.md](.claude-docs/conventions.md) — code style, naming, commit format, lint rules

<!-- Add more files as categories emerge:
     - patterns.md — recurring code patterns
     - cookbook.md — recipes for common tasks
     - api.md / stores.md / ui-components.md — code-area-specific references
     Just add a line here when you create one. -->

## Commands

- `<build>` — what the build is
- `<test>` — how tests run
- `<lint>` — what to run before commit
- `<dev>` — how to run locally

## Boundaries

### MUST

- <e.g. update gotchas.md when discovering a footgun>
- <e.g. run `lint` before every commit>
- <e.g. show diff before committing>

### MUST NOT

- <e.g. do not edit `.env` files — use the existing one>
- <e.g. do not add dependencies without discussion>
- <e.g. do not edit files in `/generated/`>

## Workflow

- Tracker: <Jira / Linear / GitHub Issues>, branches: `<pattern, e.g. TRND-xxx>`
- Git remote: <GitHub / GitLab / Bitbucket>
- Default branch: `<main | master>`

## Verification

- Lint: `<command>`
- Build: `<command>` — must succeed without errors
- Done when: <criteria, e.g. no lint errors, build succeeds, no new console warnings>
