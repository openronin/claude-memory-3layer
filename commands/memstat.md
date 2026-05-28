# /memstat — Memory subsystem dispatcher ("task manager" for memory)

Shows what the memory subsystem is doing right now: running processes (qmd embed/update, codemap/ctags), index progress (vectors embedded vs pending), refresh schedule, recent activity logs, and a health/stall check.

Use when: you see `node.exe` eating CPU and want to know what it's doing, whether it's progressing, or whether it hung.

## Usage

`/memstat` — one-shot snapshot
`/memstat --watch` — live view, refresh every 3s (Ctrl-C to exit)
`/memstat --watch 5` — live view, custom interval

## How to execute

Run via Bash:
```bash
bash ~/.claude/bin/memstat.sh
```
For watch mode, append `--watch [seconds]`. (In a non-interactive context, prefer the one-shot form — watch never returns.)

Pass the output through verbatim — it's already formatted as a dashboard (ANSI colors, sections). Then add a one-line plain-English read of the HEALTH section for the user.

## What it reports

- **PROCESSES** — live qmd/ctags processes with PID, RAM, how long they've been running. Yellow if a process has run >30min.
- **INDEX** — vectors embedded / pending, % coverage, per-collection file counts.
- **REFRESH** — when the SessionStart hook last refreshed the index, whether the next auto-refresh is due (>6h).
- **ACTIVITY** — last line + age of each qmd log (`qmd-refresh.log`, `qmd-embed.log`, `qmd-embed-retry.log`).
- **HEALTH** — if a process is running, samples the vector count over 3s to confirm forward progress; flags possible stall if an embed has run >2min with zero vector delta. If idle, confirms index state.

## Interpreting common states

- `○ idle — no memory processes running` + high coverage → normal, nothing to worry about. The CPU spike you saw was a finished embed.
- `● embed running … ✓ progressing: +N vectors in 3s` → working fine, just slow on CPU. Let it finish.
- `⚠ no vector progress in 3s and embed running 15m` → possible stall. If it persists >10min with zero delta, kill it: `powershell "Stop-Process -Id <PID>"`. Pending chunks will be retried on next refresh.

## Why embed is CPU-heavy

The retrieval index uses local GGUF models (embeddinggemma-300M) via node-llama-cpp. On this machine the Vulkan GPU path crashes (AMD Radeon 780M missing extensions), so embedding runs on CPU — ~1-3s per chunk. A full re-embed of all memory files takes ~30min. It's launched in the background by the SessionStart hook, debounced to once per 6h, so it shouldn't run more than that.
