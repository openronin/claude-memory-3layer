# /memory — Memory mode controls

Manage memory protocol behaviour. Default is **explicit-promotion** mode (user must say "запомни"/"remember" to persist cross-session). This command can flip to **auto-capture** for the current session, OR show status.

## Sub-commands

`/memory` (no args, or `/memory status`) — show current mode + collection health + last index times.

`/memory auto on` — enable **auto-capture** for the rest of THIS session. While on, append surprising/non-obvious findings to SESSION.md `# Decisions` and (if codebase-related) `<repo>/.claude-docs/gotchas.md` continuously, without waiting for explicit "запомни". Decisions stay rationale-tagged. Recent turns still verbatim.

`/memory auto off` — disable auto-capture (return to explicit-promotion). This is the default at every session start.

`/memory refresh` — force `qmd update && qmd embed` for all collections NOW (use if hooks didn't fire).

## How to execute

1. For **status**: run `qmd status` and `qmd collection list` via Bash, plus read the auto-capture flag from `~/.claude/.memory-auto` (presence = on, absence = off). Report concisely.

2. For **`auto on`**: `touch ~/.claude/.memory-auto`. Then explicitly tell the user: *"Auto-capture: ON for this session. I'll start writing observations to SESSION.md/gotchas without waiting for 'запомни'. Use `/memory auto off` to stop."*

3. For **`auto off`**: `rm -f ~/.claude/.memory-auto`. Confirm: *"Auto-capture: OFF. Back to explicit-promotion."*

4. For **`refresh`**: `qmd update && qmd embed`. Report counts (`N new, M updated`).

## Behaviour when auto-capture is ON (model must follow)

- After any non-trivial decision: write 1-line entry to SESSION.md `# Decisions` with rationale.
- After any discovery of a non-obvious project gotcha: append to the relevant `gotchas.md` (in-repo `<repo>/.claude-docs/gotchas.md` if L1a exists, else `<project>/memory/gotchas.md` if it exists, else the project's `project.md` under `## Known gotchas`).
- Do NOT auto-promote to IDENTITY.md (L0 stays sacred even in auto-mode).
- Do NOT auto-modify `<repo>/CLAUDE.md` (in-repo L1a is thin by design).
- Still refresh `last_updated` on every SESSION.md write.

## Check-this rule

At the start of EVERY response, check `~/.claude/.memory-auto`. If present, follow auto-capture behaviour. If absent, follow default (explicit-promotion). This check is cheap (one stat call) and ensures the toggle takes effect immediately within the session.

## Windows-only troubleshooting

If `qmd` is not on PATH (Git Bash / Windows), prepend to qmd commands:
```bash
export PATH="/c/Program Files/nodejs:/c/Users/$USERNAME/AppData/Roaming/npm:$PATH"
```
