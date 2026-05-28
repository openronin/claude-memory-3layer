# /recall — Hybrid search over Claude memory

Search across L0 identity, L1-fallback project notes, and L2 session memory using qmd (BM25 + GGUF embeddings + LLM rerank, all local).

## Usage

`/recall <query>` — full-text BM25 search across all memory collections. **Default mode** — fast, always works, no model loading.

`/recall --hybrid <query>` — full hybrid: BM25 + vector + LLM rerank. Requires `qmd embed` to be complete; loads ~2GB of GGUF models on first call of the session. Use when BM25 misses something obviously relevant.

Optional flags:
- `--here` — scope to current project's memory only (derive slug from cwd)
- `-c <collection>` — scope to one collection (`claude-l0` or `claude-projects`)
- `-k <N>` — top-N hits (default 5)

## How to execute

1. Run via Bash.

2. **BM25 default** (no `--hybrid` flag):
   ```bash
   qmd search "<USER_QUERY>" --md -k 5
   ```

3. **Hybrid mode** (with `--hybrid`):
   ```bash
   qmd query "<USER_QUERY>" --rerank --md -k 5
   ```
   First call of the session takes 10-60s to load embedding/reranker/query-expansion models. Subsequent calls are fast.

4. Scoping:
   - `--here`: derive slug from cwd (`C--dev-...`), add `--filter "qmd://claude-projects/<slug>/**"`
   - `-c <name>` / `-k <N>`: pass through to qmd

5. Display qmd's markdown output verbatim. Do NOT paraphrase paths/snippets. After hits, add one short orientation line (e.g. "looks like the relevant note is in `air/SESSION.md`").

6. **If hybrid mode fails** (`Error loading model` / `ErrorExtensionNotPresent`): silently fall back to `qmd search`, mention it once. Common cause: Vulkan/CUDA prebuilt mismatch on Windows.

## Examples

- `/recall MongoDB legacy driver` — BM25, finds mpcmf projects with `\MongoClient` legacy adapter
- `/recall --hybrid гочи WSL DNS` — hybrid, finds `CURLOPT_IPRESOLVE_V4` semantic-similar even without exact phrase match
- `/recall --here armenia weekly window` — scope to current project

## Collections available

- `claude-l0` — `~/.claude/memory/IDENTITY.md` (env-wide creds, OS, prefs)
- `claude-projects` — all `~/.claude/projects/*/memory/*.md` (project.md, SESSION.md, gotchas, topic files)

## When BM25 vs hybrid

- **BM25 default is enough 80% of the time** — your memory files contain the exact terminology you're searching for ("MongoDB", "Vulkan", "Kubernetes ingress"). BM25 wins on speed + zero loading cost.
- **Use `--hybrid`** for semantic queries where you don't remember the exact words ("that thing about DNS resolution failures", "the gotcha with timezone handling").

## Windows-only troubleshooting

If `qmd` is not on PATH (Git Bash / Windows), prepend:
```bash
export PATH="/c/Program Files/nodejs:/c/Users/$USERNAME/AppData/Roaming/npm:$PATH"
export QMD_LLAMA_GPU=none   # Vulkan default crashes on some AMD/Intel GPUs
```
