# Claude Code 3-Layer Memory System — Installation (v6)

A replacement for Claude Code's default memory system, battle-tested over a few weeks of real use across multiple projects. **v6 adds retrieval tools** (qmd-based hybrid search, universal-ctags symbol map) on top of the curated-markdown core.

## What you get

Three layers with different decay rates and **deliberate placement** — codebase facts live in the repo (with the code, in git), personal/per-task facts live in account-local memory.

| Layer | Path | Git? | Purpose |
|---|---|---|---|
| **L0 Identity** | `~/.claude/memory/IDENTITY.md` | no | who you are, hard preferences, env-wide creds (≤25 lines) |
| **L1a Repo entry** | `<repo>/CLAUDE.md` | **yes** | thin entry point: commands, conventions, **doc index** |
| **L1b Repo docs** | `<repo>/.claude-docs/*.md` | **yes** | thick lazy-loaded: `gotchas.md` (highest leverage), `architecture.md`, `conventions.md`, etc. |
| **L1-fallback** | `~/.claude/projects/<slug>/memory/project.md` | no | for projects without a repo, or where in-repo isn't appropriate |
| **L2 Session** | `~/.claude/projects/<slug>/memory/SESSION.md` | no | per-task working state — survives compact, dies with task |

Two hooks enforce discipline:
- **SessionStart** — injects protocol reminder; warns if `SESSION.md` is >24h stale (likely from a different task; model must surface this and ask user before continuing)
- **PreCompact** — reminds Claude to flush working state to `SESSION.md` before compaction wipes everything

The killer move: **gotchas in L1b** + **verbatim Recent turns in L2**. Future sessions hit the same project foot-guns with a one-line warning waiting; post-compact recovery doesn't lose the user's exact wording. Knowledge that should be team-shared lives in git, not on one developer's laptop.

**Decision rule (the heart of the system):**
> *"Would a server agent at midnight, with no memory and no human, need this?"*
> — yes → in-repo (`<repo>/CLAUDE.md` or `<repo>/.claude-docs/<file>.md`)
> — no → account-local (`~/.claude/memory/...`)

**Obsidian-friendly:** memory files use YAML frontmatter with hierarchical tags (`memory/l0` / `memory/l1` / `memory/l2` / `memory/repo`). Open `~/.claude/` or any repo as a vault and you get graph view + tag filtering. See "Obsidian" section below.

## Requirements

- **bash** (Git Bash on Windows, native on macOS/Linux)
- **GNU `date`** — needed for `date -d <ISO>`. macOS `/usr/bin/date` is BSD and won't work; install `coreutils` (`brew install coreutils`) and ensure `gdate`/`date` from coreutils is on PATH, OR replace `date -d` calls in `session-start.sh` with `gdate -d`.
- `grep -oE`, `sed` — present everywhere

## Install (or upgrade)

**Easiest:** run the bundled `install.sh`. It detects first-install vs upgrade, backs up changed files with `.bak-<timestamp>`, NEVER overwrites your `IDENTITY.md` (L0 user data) or `projects/` tree (L1-fallback + L2 session memory), and prints settings.json merge instructions instead of blindly clobbering hook config.

```bash
unzip claude-memory-3layer-v*.zip -d cm-pkg && cd cm-pkg

./install.sh --dry-run   # see what would change, write nothing
./install.sh             # do it
```

The script writes everything under `$CLAUDE_HOME` (defaults to `~/.claude`). Manual install instructions below if you prefer step-by-step or are on a system without bash.

### What the installer preserves vs replaces

| File / dir | Behaviour |
|---|---|
| `~/.claude/memory/IDENTITY.md` | **Preserved if exists.** Template installed as `IDENTITY.template.md` alongside, for reference. |
| `~/.claude/projects/` | **Never touched.** Your `SESSION.md` + `project.md` + `legacy/` stay as-is. |
| `~/.claude/CLAUDE.md` | Replaced, `.bak-<ts>` backup if content differs. |
| `~/.claude/hooks/*.sh` | Replaced, `.bak-<ts>` backup if content differs. |
| `~/.claude/commands/{recall,memory,codemap}.md` | Replaced, `.bak-<ts>` backup if content differs. (Your own `task.md`/etc. untouched.) |
| `~/.claude/settings.json` | Never auto-merged. Created fresh if absent. If exists without our hooks, you're told to merge by hand. |
| `~/.cache/qmd/`, `<repo>/.codemap.tags` | Never touched. They're caches, rebuilt on demand. |

### Rollback

Each install pass tags backups with the same timestamp. To restore a previous run:

```bash
TS=20260519-181949   # whatever the installer printed
for f in ~/.claude/**/*.bak-$TS; do mv "$f" "${f%.bak-$TS}"; done
```

### Format compatibility with older installs

`SESSION.md` and `project.md` files written by earlier versions of this protocol use HTML comments (`<!-- last_updated: ISO -->`) for the staleness marker. The hook's regex accepts both the legacy HTML-comment form and the new YAML frontmatter. **No migration required** — old files keep working immediately.

Old account-local files from the pre-2026-04-30 system (`MEMORY.md`, `feedback_*.md`, `project_*.md`, `reference_*.md`) are ignored by the new hook — they sit harmlessly on disk.

### Migrating older data (optional but recommended)

Two migration paths, both shipped in the package:

**Mechanical (no AI needed) — `migrate.sh`** handles HTML-comment `last_updated` → YAML frontmatter, with backup. Auto-detects pre-2026-04-30 legacy directories and prints guidance for the next step.

```bash
./migrate.sh --dry-run   # preview
./migrate.sh             # apply (writes .bak-<ts> for each touched file)
```

**Smart synthesis — `/migrate-legacy-memory` slash command** (requires Claude Code session). Spawns an Agent that reads each legacy directory, synthesizes a single new-format `project.md` per project preserving verbatim technical details (reviewer quotes, exact paths, error messages), and moves originals into `<slug>/memory/legacy/` as backup.

```
# In any Claude Code session:
/migrate-legacy-memory
```

The slash command is non-destructive: only `mv` to `legacy/`, never `rm`. Skips projects that already have new-format `project.md`. Safe to re-run.

## Manual install (alternative to `install.sh`)

Assuming you unzipped this archive to some folder (call it `<pkg>`):

### 1. Lay out account-local files

```bash
mkdir -p ~/.claude/hooks ~/.claude/memory ~/.claude/debug

cp <pkg>/CLAUDE.md                  ~/.claude/CLAUDE.md
# ⚠ IDENTITY.md: only copy if FIRST install — overwriting existing one loses your data
[ ! -f ~/.claude/memory/IDENTITY.md ] && cp <pkg>/memory/IDENTITY.md ~/.claude/memory/IDENTITY.md
cp <pkg>/hooks/session-start.sh     ~/.claude/hooks/session-start.sh
cp <pkg>/hooks/pre-compact.sh       ~/.claude/hooks/pre-compact.sh
chmod +x ~/.claude/hooks/*.sh
```

> **Heads up:** if `~/.claude/CLAUDE.md` already exists, back it up first (`cp ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.bak`) — this file replaces the default memory instructions wholesale.

### 2. Wire up the hooks in `~/.claude/settings.json`

Open `~/.claude/settings.json` (create it if it doesn't exist) and merge in the `hooks` block from `settings.snippet.json`. If the file is empty, copy the snippet wholesale:

```bash
cp <pkg>/settings.snippet.json ~/.claude/settings.json
```

If you already have a `settings.json`, paste only the `"hooks": { ... }` portion into your existing object. **Do not duplicate the `hooks` key** — merge into the existing one if present.

### 3. Edit your IDENTITY

```bash
$EDITOR ~/.claude/memory/IDENTITY.md
```

Fill in name, language, OS/shell, style preferences. **Hard cap: 25 lines.** This file loads into every session — keep it tight. The template includes commented examples of env-wide credentials (GitHub SSH wrapper, AWS profile, etc.) — uncomment what applies, delete the rest.

### 4. Bootstrap in-repo L1 for a project (recommended)

When you start substantive work in a repo, copy the L1 templates into the repo and commit them:

```bash
cd /path/to/your/repo
mkdir -p .claude-docs
cp <pkg>/templates/repo/CLAUDE.md                    ./CLAUDE.md
cp <pkg>/templates/repo/.claude-docs/index.md        .claude-docs/index.md
cp <pkg>/templates/repo/.claude-docs/gotchas.md      .claude-docs/gotchas.md
cp <pkg>/templates/repo/.claude-docs/architecture.md .claude-docs/architecture.md
cp <pkg>/templates/repo/.claude-docs/conventions.md  .claude-docs/conventions.md

$EDITOR CLAUDE.md  # fill in commands, conventions, MUST/MUST NOT
$EDITOR .claude-docs/architecture.md  # describe stack/layout
# leave gotchas.md empty — populate as you discover footguns
```

Or just tell Claude: *"Заведи L1 для этого проекта"* / *"Set up in-repo L1 for this project"* — it'll create the files for you, populate what it can infer, and leave placeholders for what it can't.

**Why in-repo:** the knowledge travels with the code. Clone the repo on a new machine → all gotchas, conventions, architecture notes are right there. Teammates see them. Server agents (headless Claude runs) see them. They version with the code.

### 5. (Optional) L1-fallback for personal/no-repo projects

For projects without a repo, or where you don't want L1 in-repo (proprietary, solo experiments):

```bash
mkdir -p ~/.claude/projects/<slug>/memory
cp <pkg>/templates/project.md.fallback.template ~/.claude/projects/<slug>/memory/project.md
$EDITOR ~/.claude/projects/<slug>/memory/project.md
```

Compute slug from cwd: `C:\dev\foo` → `C--dev-foo` (drive uppercase + `--` + remaining path with `/`→`-`).

### 6. Verify

Start a new Claude Code session in any project. Within Claude's first action you should see reads of `IDENTITY.md` (and `SESSION.md`/`project.md` if they exist) and `<repo>/CLAUDE.md` auto-loaded. Hook firings log to `~/.claude/debug/hook-trace.log`:

```bash
tail -f ~/.claude/debug/hook-trace.log
```

To see the staleness warning fire end-to-end: artificially backdate a SESSION.md by replacing its first-line `last_updated` with a timestamp >24h ago, start a fresh session, and Claude should explicitly ask you "continue or reset?" instead of silently using the loaded state.

## How it works (TL;DR for the model)

1. **Session start** → hook injects protocol reminder + computes slug from cwd → model reads `IDENTITY.md` + `SESSION.md` (account-local). `<repo>/CLAUDE.md` is auto-loaded by Claude Code itself; `.claude-docs/*` are read on demand via the index.
2. **During work** → model writes decisions, file map, key files, recent user turns to `SESSION.md` continuously, refreshing `last_updated:` on every write. Discovers a project gotcha → adds it to `<repo>/.claude-docs/gotchas.md` and the user commits it as part of the work.
3. **Pre-compact** → user signals compact → model does PRE-COMPACT CHECKPOINT (git status, full SESSION.md flush including verbatim Recent turns) → hook reminds → compact runs → after compact, model's first action is reading SESSION.md back.
4. **Next session** → hook reads `last_updated`. If >24h, injects STALENESS WARNING — model must ask user "continue or reset?" instead of silently continuing with stale state from a different task.
5. **Task done** without "remember" → SESSION.md gets wiped to template. Cross-session promotion is **explicit-only**: user says "запомни" / "remember" → relevant info migrates into IDENTITY.md (personal) or `<repo>/.claude-docs/<file>.md` (codebase fact, user commits).

## Retrieval tools (v6, optional but recommended)

These tools let the model recall things across memory and query code structure without grep-thrashing. All local, no daemons.

### 1. `qmd` — hybrid search over memory files (Phase 1+2)

[Tobi Lütke's qmd](https://github.com/tobi/qmd) — BM25 + GGUF embeddings + LLM reranker, all local. Replaces what would otherwise be ~300 LOC of custom retrieval.

**Install:**

```bash
# Node 18+ required (qmd uses node-llama-cpp under the hood)
winget install OpenJS.NodeJS.LTS   # Windows
# brew install node                # macOS
# apt install nodejs npm           # Linux (need 18+; may need NodeSource)
```

> **nvm users (Linux/macOS):** nvm injects `node` into PATH via `~/.bashrc`, but Claude Code's `Bash` tool runs a **non-interactive** shell that does not source `~/.bashrc`. Even if `node --version` works in your terminal, `qmd` (which uses `#!/usr/bin/env node`) will fail with `node: not found` inside Claude Code sessions. Fix: drop stable symlinks into a directory that is unconditionally on PATH (e.g. `~/.local/bin`):
> ```bash
> ln -sf "$NVM_BIN/node" ~/.local/bin/node
> ln -sf "$NVM_BIN/npm"  ~/.local/bin/npm
> ln -sf "$NVM_BIN/npx"  ~/.local/bin/npx
> ```
> `~/.local/bin` is on PATH by default on most modern Linux distros (Ubuntu 17.10+, Fedora, Arch). Verify with `echo $PATH | tr : '\n' | grep local`. Alternatively, install Node system-wide via [NodeSource](https://github.com/nodesource/distributions) (`curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo bash - && sudo apt install -y nodejs`) to avoid the issue entirely.

```bash
npm install -g @tobilu/qmd

# Configure collections for memory files
qmd collection add ~/.claude/memory --name claude-l0
qmd collection add ~/.claude/projects --name claude-projects
qmd context add qmd://claude-l0/ "L0 identity layer"
qmd context add qmd://claude-projects/ "L1-fallback project notes + L2 sessions"

# First-time embed (downloads ~2GB of GGUF models, slow CPU-only on first run)
QMD_LLAMA_GPU=none qmd embed   # CPU backend. Use 'cuda' or 'vulkan' if you have GPU acceleration set up.
```

**Windows GPU note:** node-llama-cpp's default Vulkan path may fail on Windows with "ErrorExtensionNotPresent". Use `QMD_LLAMA_GPU=none` (CPU) for reliability. The session-start hook in this package already exports this by default.

**Per-repo collections (optional):** for repos where you've adopted in-repo L1 (`.claude-docs/`), add them too:
```bash
qmd collection add /path/to/repo/.claude-docs --name repo-myproject
```

The session-start hook automatically refreshes the qmd index in background once every 6 hours (debounced). Force refresh with `/memory refresh`.

### 2. `universal-ctags` — symbol map for the current repo (Phase 3)

Used by `/codemap` slash command. Single binary, no Python deps.

```bash
winget install UniversalCtags.Ctags   # Windows
# brew install universal-ctags        # macOS
# apt install universal-ctags         # Linux (or 'snap install universal-ctags')
```

The `codemap.sh` script in `bin/` self-locates ctags across all standard install paths.

### 3. Slash commands (Phase 1+2+3 + protocol controls)

Drop `commands/*.md` into `~/.claude/commands/`:

```bash
cp <pkg>/commands/recall.md   ~/.claude/commands/recall.md
cp <pkg>/commands/codemap.md  ~/.claude/commands/codemap.md
cp <pkg>/commands/memory.md   ~/.claude/commands/memory.md
mkdir -p ~/.claude/bin
cp <pkg>/bin/codemap.sh       ~/.claude/bin/codemap.sh
chmod +x ~/.claude/bin/codemap.sh
```

You get:
- **`/recall <query>`** — hybrid search across all memory layers (qmd-backed)
- **`/codemap def|callers|callees|outline <symbol>`** — on-demand symbol queries in cwd repo (ctags+ripgrep)
- **`/memory status | auto on|off | refresh`** — protocol controls; `/memory auto on` flips this session into auto-capture mode (model writes observations without waiting for explicit "запомни")
- **`/memstat [--watch]`** — "task manager" for the memory subsystem: running qmd/ctags processes, index progress (vectors vs pending), refresh schedule, and a stall/health check. Use when `node.exe` is eating CPU and you want to see what it's doing.

## Growing the knowledge store (flat + tags + prefixes)

When a project's L1b (`<repo>/.claude-docs/`) or L1-fallback (`~/.claude/projects/<slug>/memory/`) grows beyond a handful of files, follow this convention (codified in `CLAUDE.md` under "Knowledge store organization"):

- **Flat directory.** No nesting. Obsidian's tag panel makes hierarchical tags into a tree visually — you don't need nested folders to get hierarchy.
- **Filename prefixes for grouping.** `protocol_<name>.md`, `format_<name>.md`, `handoff_<topic>.md`, `recipe_<task>.md`. Underscore separator, lowercase. Alphabetical sort clusters them in `ls`.
- **`index.md` is the routing source.** Always update it when adding a new doc.
- **Frontmatter tags carry semantic.** `tags: [memory/repo, protocol]` etc. — hierarchical first segment for the layer, semantic terms for the topic.
- **Raw data dumps in `raw/` subdir.** Non-markdown only. Markdown notes stay flat.

This scales well — a real reverse-engineering project in this workflow accumulated 60+ files this way and stays navigable via tags + filename prefixes alone, no folder nesting.

## Key design choices

- **In-repo L1, not account-local.** The fundamental fix vs typical "Claude memory" patterns: codebase knowledge lives **with** the codebase. Single source of truth, version-controlled, travels with clones, teammates see it, server agents see it.
- **Thin entry + thick lazy index.** `<repo>/CLAUDE.md` is auto-loaded — bloated content there eats context across every session. Thick docs go in `.claude-docs/*.md` and are read by the model only when the doc index in CLAUDE.md routes a task to them.
- **No journal/archive layer.** Sessions are about different tasks; carrying them forward is noise. Layer = decay rate, period.
- **Promotion is explicit.** No auto-archival. The user, not the model, decides what crosses session boundaries.
- **Gotchas in L1b are the highest-leverage memory.** Every project accumulates non-obvious foot-guns. A one-paragraph warning in `gotchas.md` saves the next agent (or your future self) hours of debugging.
- **Project slug rule:** `C:\dev\foo` → `C--dev-foo` (drive uppercase + `--` + remaining path with `/`→`-`). Matches Claude Code's existing `~/.claude/projects/` directory naming.
- **`last_updated` lives in YAML frontmatter** (parseable by hook, Obsidian, eyes). Legacy HTML-comment format still works.
- **Pure bash hooks**, no Python (Python is often missing on Windows).
- **Recent turns kept verbatim.** The compact summarizer paraphrases away texture; verbatim quotes preserve it.

## Workflow patterns the model should follow

These are documented in `CLAUDE.md` but worth knowing as the user too:

- **Pre-compact ritual.** Say "теперь можно компакт" / "compact me" → model produces `PRE-COMPACT CHECKPOINT` summary (HEAD hash, what's pushed, where to start reading next) BEFORE the compact runs.
- **Post-compact recovery.** Model's first action is reading IDENTITY/SESSION/project.md — answers come second.
- **Bootstrapping in-repo L1.** Substantive work in a repo with no CLAUDE.md → model proposes setting one up rather than silently working without project context.
- **Multi-session handoff.** Working in a side worktree or another chat? Model leaves a `<!-- NOTE: ... -->` block in SESSION.md describing what state the OTHER session expects.
- **Ad-hoc sections in SESSION.md** are encouraged for long arcs — "Прогон 2026-05-07", "Design session 2026-05-06", etc. Template is a floor, not a ceiling.
- **Decision tagging:** `[HH:MM]` for short same-day work, `[<phase-tag>]` like `[BA day]`, `[LLM E2E]`, `[WEB FIX <hash>]` for multi-day arcs.

## Obsidian (optional but free)

Memory files use YAML frontmatter and standard markdown — works as an [Obsidian](https://obsidian.md/) vault out of the box.

**Two vault options:**
- **`~/.claude/` as vault** — cross-project graph: L0 + every L2 session + L1-fallback project.md files. Useful for "what was I doing last week?".
- **`<repo>/` as vault** — single-project deep-dive: `CLAUDE.md` + `.claude-docs/*` + your code. Useful for "show me the gotchas + architecture for this codebase".

What you get:
- Graph view across files
- Filter by tag: `tag:memory/l0` (identity), `tag:memory/l1` / `memory/repo` (project), `tag:memory/l2` (session), `tag:gotchas` (just the foot-guns)
- Full-text search
- Backlinks from cross-references

Setup: in Obsidian, "Open folder as vault" → pick the folder. Obsidian creates its own `.obsidian/` config; doesn't interfere.

Conventions kept compatible:
- Frontmatter is YAML, not HTML comments — Obsidian parses it natively, the model still reads files normally, the staleness hook still extracts `last_updated:` via regex.
- Standard markdown links `[text](path)` — work in Obsidian AND in Claude. Wikilinks `[[note]]` would break for Claude, so they're avoided in templates.
- Hierarchical tags (`memory/l0`) for clean nesting in Obsidian's tag panel.

## Troubleshooting

- **`node: not found` (nvm users).** Claude Code's `Bash` tool runs a non-interactive shell that does not source `~/.bashrc`, so nvm's PATH injection is invisible even though `node --version` works in your terminal. Fix: create stable symlinks in a directory unconditionally on PATH:
  ```bash
  ln -sf "$NVM_BIN/node" ~/.local/bin/node
  ln -sf "$NVM_BIN/npm"  ~/.local/bin/npm
  ln -sf "$NVM_BIN/npx"  ~/.local/bin/npx
  ```
  Or install Node system-wide via [NodeSource](https://github.com/nodesource/distributions) to avoid the issue entirely. See the note in the `qmd` install section above.
- **Hooks don't fire.** Check `~/.claude/debug/hook-trace.log` after starting a session. Empty? `settings.json` malformed (`python -m json.tool < ~/.claude/settings.json`) or path wrong. Use `~/` not `$HOME` in the JSON — Claude Code expands tilde.
- **macOS: `date: illegal option -- d`.** You're using BSD `date`. `brew install coreutils` and either prepend its bin to PATH or replace `date -d` with `gdate -d` in `session-start.sh`.
- **Slug looks wrong.** The hook computes it from `$PWD` in unix form (`/c/dev/foo`). On Windows, Git Bash gives this naturally. If you see `C--dev--foo` (double dash mid-path) you're running an older draft — the line should read `slug="${drive}--${rest//\//-}"` (single dash inside the path).
- **Staleness warning never fires.** Model didn't refresh `last_updated` on previous writes. The "no marker" branch will fire instead, which is the intended fallback.
- **Model ignores the staleness warning.** Paste rule 5 from CLAUDE.md back at it. The hook injects the warning text but the model has to act on it.
- **Model didn't auto-load `<repo>/CLAUDE.md`.** That's Claude Code's built-in behaviour, not the hook's job. Make sure cwd is inside the repo (not a sibling), and that `<repo>/CLAUDE.md` exists at the repo root (not in a subdir).

## Customizing

- **Change staleness threshold.** Edit `session-start.sh`, replace `86400` (seconds = 24h) with whatever you want.
- **Different `CLAUDE_HOME`.** Set the env var; both hooks honor it.
- **Different L1b dir name.** If you don't like `.claude-docs/`, pick another (e.g. `docs/agents/`, `.claude/docs/`). Update the doc index in `<repo>/CLAUDE.md` accordingly. The hooks don't care — they only touch account-local memory.
- **Add more hooks.** PreCompact and SessionStart cover the critical points; you can add UserPromptSubmit, etc., using the same JSON shape.

## Files in this archive

- `CLAUDE.md` — the protocol spec (replaces default Anthropic memory instructions; goes to `~/.claude/CLAUDE.md`)
- `memory/IDENTITY.md` — L0 template with placeholders (goes to `~/.claude/memory/IDENTITY.md`)
- `templates/repo/CLAUDE.md` — L1a template (thin entry point for a project repo)
- `templates/repo/.claude-docs/{index,gotchas,architecture,conventions}.md` — L1b templates
- `templates/project.md.fallback.template` — L1-fallback template (account-local project memory)
- `hooks/session-start.sh` — staleness check + protocol injection (portable, uses `$HOME`/`CLAUDE_HOME`)
- `hooks/pre-compact.sh` — flush reminder
- `settings.snippet.json` — hooks block to merge into `~/.claude/settings.json`
- `INSTALL.md` — this file
