# Changelog

## v6.2.0 — 2026-05-21 — Memory dispatcher

**Added**
- `bin/memstat.sh` + `/memstat` slash command — a "task manager" for the memory subsystem. Shows:
  - **Processes** — running qmd/ctags processes with PID, RAM, runtime (yellow flag if >30min)
  - **Index** — vectors embedded vs pending, % coverage, per-collection file counts
  - **Refresh** — when the SessionStart hook last refreshed, whether next auto-refresh is due (6h debounce)
  - **Activity** — last line + age of each qmd log
  - **Health** — if an embed is running, samples vector delta over 3s to confirm forward progress; flags possible stall (>2min running, 0 delta) with the PID to kill
  - `--watch [seconds]` for a live auto-refreshing view
- Answers the recurring "why is node.exe eating my CPU and is it stuck?" question. The CPU spikes are the background `qmd embed` launched by the SessionStart hook (6h debounce); on machines without working GPU acceleration it runs CPU-only (~1-3s/chunk, ~30min full re-embed).

## v6.1.0 — 2026-05-19 — Migration tools

**Added**
- `migrate.sh` — mechanical migration of HTML-comment `<!-- last_updated: ISO -->` markers to YAML frontmatter (with `tags:` derived from filename). Auto-detects pre-2026-04-30 legacy directories (`MEMORY.md`, `feedback_*.md`, `project_*.md`, `reference_*.md`) and prints guidance for the AI-synthesis step. `--dry-run` flag for safe preview. Writes `.bak-<timestamp>` for every touched file.
- `commands/migrate-legacy-memory.md` — Claude Code slash command. Spawns an Agent that reads each legacy project directory, synthesizes a single new-format `project.md` per project preserving verbatim technical specificity (reviewer quotes, exact paths, error messages, port/version numbers), and moves originals into `<slug>/memory/legacy/`. Skips projects that already have new-format `project.md`. Non-destructive: only `mv`, never `rm`.
- INSTALL.md: new "Migrating older data" section explaining the two-step path (mechanical → AI synthesis) and when to use each.

## v6.0.1 — 2026-05-19 — Upgrade-safe installer

**Added**
- `install.sh` — idempotent installer. Detects first-install vs upgrade, backs up changed files with `.bak-<timestamp>`, **never overwrites** your `IDENTITY.md` (L0 user data) or `projects/` tree (L1-fallback + L2 sessions). `--dry-run` flag previews changes without writing.
- INSTALL.md: new "Install (or upgrade)" section explaining behaviour per file/dir, rollback recipe, format-compat notes for older installs (HTML-comment `last_updated` markers still work).

**Fixed**
- Manual install path in INSTALL.md guards `cp memory/IDENTITY.md` with a `[ ! -f ... ]` check to prevent silent L0 data loss on upgrade.

**Changed**
- `/recall` default mode flipped to BM25 (`qmd search`), with `--hybrid` flag opt-in for full BM25+vector+rerank. Hybrid requires the full GGUF model bundle loaded and a complete embed index — BM25 covers ~80% of recall queries with zero loading cost.

## v6.0.0 — 2026-05-19 — Initial public release

First public release. Hand-curated, in-repo memory protocol with hybrid retrieval and on-demand symbol map. 100% local. MIT.

## v6 — 2026-05-19 — Retrieval tools (pre-release development log)

**Added**
- `/recall <query>` slash command — hybrid search (BM25 + GGUF embeddings + LLM rerank) over all memory files, backed by [qmd](https://github.com/tobi/qmd)
- `/codemap def|callers|callees|outline <symbol>` — on-demand symbol map for the current repo via universal-ctags + ripgrep; cache in `<repo>/.codemap.tags`
- `/memory status | auto on|off | refresh` — protocol controls and optional auto-capture toggle (off by default)
- `bin/codemap.sh` — portable ctags+rg wrapper, self-locates binaries on Windows (winget paths) / macOS (brew) / Linux (apt)
- SessionStart hook now auto-refreshes the qmd retrieval index in background, debounced 6h

**Changed**
- Knowledge store organization: flat-only rule softened to allow shallow (1-level) folder grouping when a category has 5+ peer files — `protocols/`, `formats/`, `handoffs/` OK; deeper nesting still forbidden. Obsidian tags continue to do the primary categorization.
- Karpathy "LLM-OS" framing added to CLAUDE.md (context = RAM, file system = disk, tools = peripherals)

## v5 — 2026-05-13 — Knowledge store conventions

**Added**
- "Knowledge store organization" section in CLAUDE.md codifying flat + tags + filename-prefix conventions (`protocol_<name>.md`, `format_<name>.md`, `handoff_<topic>.md`)
- `index.md` as the routing source for multi-file knowledge stores
- `raw/` subdirectory convention for non-markdown data dumps
- Rule for when to split single `project.md` into multi-file (>200 lines, ≥3 distinct categories, or cross-file refs needed)

## v4 — 2026-05-07 — In-repo L1 pivot

**Changed**
- L1 split into **L1a** (`<repo>/CLAUDE.md`, thin entry, git-tracked, auto-loaded) + **L1b** (`<repo>/.claude-docs/*.md`, thick lazy-loaded, git-tracked)
- Old account-local `project.md` renamed to **L1-fallback** for repos where in-repo isn't appropriate
- Adopted "midnight server agent test" as the explicit decision rule for layer placement
- Added templates: `templates/repo/CLAUDE.md`, `templates/repo/.claude-docs/{index,gotchas,architecture,conventions}.md`

## v3 — 2026-05-07 — Obsidian compatibility

**Changed**
- HTML-comment `<!-- last_updated: ... -->` migrated to YAML frontmatter with `tags: [memory/l0|l1|l2|repo, ...]`
- StalenessHook regex stays compatible with both formats — no migration needed for existing files

## v2 — 2026-05-05 — Workflow patterns + L1 templates

**Added**
- Workflow patterns: pre-compact checkpoint, post-compact recovery, multi-session handoff, distillation on task wrap-up, bootstrapping in-repo L1
- L1-fallback template with structured sections (Repository, Layout, Stack, Endpoints, Conventions, Known gotchas, Roadmap)
- Rule: "L1 is where grabli live" — non-obvious footguns are the highest-leverage memory

## v1 — 2026-05-05 — Staleness detection + portability

**Added**
- `bin/session-start.sh` staleness check: if `SESSION.md` is >24h old, the hook injects a STALENESS WARNING so the model surfaces it to the user before silently continuing
- Portable hooks (use `$HOME`/`$CLAUDE_HOME` instead of hardcoded paths)
- `templates/` directory with separate `IDENTITY.md`, `project.md` templates for new installs
- Friend-shareable zip packaging
