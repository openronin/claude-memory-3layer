# /recall — Hybrid search over Claude memory

Search across L0 identity, L1-fallback project notes, and L2 session memory using qmd (BM25 + GGUF embeddings + LLM rerank, all local).

## Usage

`/recall <query>` — natural-language query, hybrid search across all memory collections.

Optional flags (append to query line):
- `--here` — scope to current project's memory only (derive slug from cwd)
- `-c <collection>` — scope to one collection (`claude-l0` or `claude-projects`)
- `-k <N>` — top-N hits (default 5)

## How to execute

1. Run via Bash:
   ```bash
   qmd query "<USER_QUERY>" --rerank --md -k 5
   ```
   If user passed `--here`: derive slug from cwd (`C--dev-...`), add `--filter "qmd://claude-projects/<slug>/**"`.
   If user passed `-c <name>` or `-k <N>`: pass through.

2. **If qmd is not on PATH** (new shell, missing user PATH update): prepend
   `export PATH="/c/Program Files/nodejs:/c/Users/greev/AppData/Roaming/npm:$PATH" &&` before `qmd`.

3. **If embed index is stale** (qmd warns `N docs missing vectors`): silently run `qmd update && qmd embed` first, then re-query.

4. Display the top results to the user as-is (qmd's markdown output is already nicely formatted: rank, path, context, score). Do NOT paraphrase — preserve verbatim file paths and snippets.

5. After the hits, add a one-line tip: which file looked most relevant, or "хочешь полный текст файла X?" if a hit is obviously the answer.

## Examples

- `/recall MongoDB legacy driver` → finds the `mpcmf` projects with `\MongoClient` legacy adapter notes
- `/recall гочи WSL DNS` → finds `CURLOPT_IPRESOLVE_V4` gotcha
- `/recall --here armenia weekly window` → restricts to current project

## Collections available

- `claude-l0` — `~/.claude/memory/IDENTITY.md` (env-wide creds, OS, prefs)
- `claude-projects` — all `~/.claude/projects/*/memory/*.md` (project.md, SESSION.md, gotchas, topic files)
