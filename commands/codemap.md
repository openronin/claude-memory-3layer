# /codemap — On-demand symbol map for the current repo

Tree-sitter-ish symbol queries (definitions, callers, callees, outline) via universal-ctags + ripgrep. No daemon, no persistent DB outside the repo. Re-scans automatically if source files are newer than the cached `.codemap.tags`.

## Usage

`/codemap def <symbol>` — where is `<symbol>` defined? (file, line, kind, signature)
`/codemap callers <symbol>` — every file/line that mentions `<symbol>` (best-effort textual)
`/codemap callees <symbol>` — heuristic list of identifiers called from inside `<symbol>`'s definition
`/codemap outline` — top-level classes/functions/methods across the cwd repo
`/codemap refresh` — force tags rebuild (use after large refactors)

## How to execute

Run via Bash from the user's current cwd (do NOT cd):

```bash
bash ~/.claude/bin/codemap.sh <subcmd> [arg]
```

Output is plain text — pass through verbatim, then add one short orientation line ("found 3 callers across `<repo>/src/`", or "definition is in `<file>:<line>`, want me to read it?").

If output is empty for `callers`/`callees`/`def`, say so explicitly — don't fabricate.

## Conventions / tag cache

- Cache file: `<repo-root-or-cwd>/.codemap.tags` (gitignore-able)
- Languages indexed: Python, PHP, JS/TS/TSX, Go, Rust, Java, C/C++/H, C#, Ruby
- Excluded dirs: `node_modules`, `.git`, `vendor`, `dist`, `build`, `__pycache__`, etc.
- Stale-detection: any source file newer than tags → auto-rebuild on next invocation

## When to use vs `/recall`

- `/codemap` — code structure questions: "where is X defined", "who calls Y", "what does Z do"
- `/recall` — knowledge/memory questions: "what was the MongoDB gotcha", "did we already see this error"

They're complementary. `/codemap` reads code; `/recall` reads notes about code.
