# /migrate-legacy-memory — Convert pre-2026-04-30 legacy files to new L1-fallback format

Scans `~/.claude/projects/*/memory/` for legacy files (`MEMORY.md`, `feedback_*.md`, `project_*.md`, `reference_*.md`) and synthesizes them into a single new-format `project.md` per project. Old files are MOVED (not deleted) to `<slug>/memory/legacy/`.

This complements the mechanical `migrate.sh` script in the package — that one handles HTML→YAML frontmatter (no AI needed), this one handles the AI-synthesis case.

## How to execute

### 1. Discover candidates

Run via Bash:
```bash
for d in ~/.claude/projects/*/memory; do
  [ -d "$d" ] || continue
  # has legacy files AND no legacy/ subdir AND no new-format project.md (or one without frontmatter)?
  legacy_count=$(ls "$d"/MEMORY.md "$d"/feedback_*.md "$d"/project_*.md "$d"/reference_*.md 2>/dev/null | wc -l)
  has_new_project=$([ -f "$d/project.md" ] && grep -q "tags: \[memory/l1" "$d/project.md" 2>/dev/null && echo yes || echo no)
  if [ "$legacy_count" -gt 0 ] && [ ! -d "$d/legacy" ] && [ "$has_new_project" = "no" ]; then
    echo "candidate: $d ($legacy_count legacy files)"
  fi
done
```

If zero candidates → tell the user there's nothing to migrate, stop.

### 2. Delegate to Agent

For 3+ candidates, dispatch a single `general-purpose` Agent (parallelism is fine — it'll batch the project list). Brief it with:

> Task: migrate legacy Claude memory files into new L1-fallback format.
>
> For each project directory in the list:
> 1. Read all `.md` files matching `MEMORY.md`, `feedback_*.md`, `project_*.md`, `reference_*.md`. Do NOT touch `SESSION.md` (new-format L2) or any existing new-format `project.md` (has `tags: [memory/l1` frontmatter).
> 2. Synthesize a single `project.md` in this exact structure (only include sections with actual extractable content — don't fabricate):
>    - YAML frontmatter:
>      ```
>      ---
>      tags: [memory/l1, project]
>      project: <inferred_name_from_slug>
>      ---
>      ```
>    - `# Project: <NAME>` heading + 1-2 line elevator pitch inferred from legacy content
>    - `## Repository` (if legacy mentions GitHub URL / paths / branch)
>    - `## Stack` (language, framework, storage — if mentioned)
>    - `## Known gotchas / Известные грабли` — **PRIMARY VALUE**. Convert each `feedback_*.md` to a numbered one-liner preserving verbatim technical specificity (don't summarize away exact filenames, paths, error messages, reviewer quotes, port numbers, version numbers).
>    - `## Reference` — for `reference_*.md` content (links to other projects, lead reviewers with name+email+expertise, related codebases)
>    - `## Conventions` — codebase-wide style/naming/commit rules if any
>    - `## Operations` — restart/reset/deploy notes if mentioned
> 3. Create `<dir>/legacy/` if absent. `mv` (not `cp`) all `MEMORY.md`, `feedback_*.md`, `project_*.md`, `reference_*.md` into it. SESSION.md stays untouched.
> 4. Russian content stays Russian — do not translate.
>
> Report per project: N legacy files → M gotchas extracted, ~K lines in resulting project.md. Flag anomalies (empty legacy, dossier orthogonal to project name, etc).

### 3. Report

Show the user a compact table:
```
✓ C--dev-trends-prod:   7 legacy → 5 gotchas + 1 reference (Pronchev review notes)
✓ C--dev-openclaw-jarvis: 8 legacy → 5 gotchas (WSL stop, apiRoot key, ...)
⊘ C--dev-air:            already has new-format project.md, skipped
...
Backups in <slug>/memory/legacy/ — review and delete when satisfied.
```

## Hard constraints (must brief the Agent)

- NEVER modify any `SESSION.md`
- NEVER `rm` or `delete` — only `mv` to `legacy/`
- NEVER touch projects with existing new-format `project.md` (has `tags: [memory/l1` in frontmatter)
- PRESERVE technical specificity verbatim: reviewer quotes, exact filenames, paths, port numbers, error messages, version numbers
- Do NOT fabricate sections — if legacy has no Stack info, omit the Stack section

## When to NOT run this

- If user has manually curated `project.md` files and the legacy/ files are just stale leftovers — let user delete them by hand instead.
- If a project's legacy files are all empty or 1-line stubs — skip rather than create thin synthesis.
