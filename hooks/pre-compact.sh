#!/usr/bin/env bash
# PreCompact hook — reminds model to flush SESSION.md before compaction.
# NOTE: PreCompact schema does NOT accept hookSpecificOutput.additionalContext
# (unlike SessionStart/UserPromptSubmit). Use top-level `systemMessage` instead.

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
mkdir -p "$CLAUDE_HOME/debug" 2>/dev/null
echo "[$(date -Iseconds)] PreCompact fired (cwd=$PWD)" >> "$CLAUDE_HOME/debug/hook-trace.log"

cat <<'EOF'
{"systemMessage":"PRE-COMPACT FLUSH REQUIRED. Before compaction, update <project>/memory/SESSION.md: Goal, State (branch/last/next), Decisions with rationale, File map, Open questions, Blockers, and **Recent turns** (last ~5 user turns VERBATIM + 1-line 'I did:' each). SESSION.md is the only artifact that survives compaction with full fidelity. After compact, re-read it first."}
EOF
