#!/usr/bin/env bash
# install.sh — claude-memory-3layer installer.
#
# Idempotent and upgrade-safe:
# - First install: lays out everything cleanly
# - Upgrade: backs up changed files with .bak-<timestamp>, NEVER overwrites
#   your IDENTITY.md (L0 user data) or projects/ tree (L1-fallback + L2)
# - Detects existing settings.json and prints merge instructions instead of
#   blindly overwriting hook config
#
# Usage:
#   ./install.sh            # installs to ~/.claude (or $CLAUDE_HOME if set)
#   ./install.sh --dry-run  # show what would change, write nothing

set -e

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
TS=$(date +%Y%m%d-%H%M%S)
SRC=$(cd "$(dirname "$0")" && pwd)
DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

# --- Helpers ---

say() { printf '%s\n' "$*"; }
do_or_dry() { if [[ $DRY_RUN -eq 1 ]]; then say "  [dry] $*"; else eval "$@"; fi; }

backup_and_install() {
  local src="$1" dst="$2"
  if [[ -f "$dst" ]]; then
    if cmp -s "$src" "$dst"; then
      say "  = $dst (unchanged)"
      return 0
    fi
    do_or_dry "cp '$dst' '$dst.bak-$TS'"
    say "  ~ $dst (backed up -> $dst.bak-$TS)"
  else
    say "  + $dst (new)"
  fi
  do_or_dry "mkdir -p '$(dirname "$dst")'"
  do_or_dry "cp '$src' '$dst'"
}

# --- Detect mode ---

mode="first-install"
[[ -f "$CLAUDE_HOME/CLAUDE.md" ]] && mode="upgrade"

say "=== claude-memory-3layer installer ==="
say "Source:      $SRC"
say "Destination: $CLAUDE_HOME"
say "Mode:        $mode"
[[ $DRY_RUN -eq 1 ]] && say "[DRY RUN — no changes will be written]"
say ""

# --- Layout ---

if [[ $DRY_RUN -eq 0 ]]; then
  mkdir -p "$CLAUDE_HOME/hooks" "$CLAUDE_HOME/memory" "$CLAUDE_HOME/commands" \
           "$CLAUDE_HOME/bin"   "$CLAUDE_HOME/debug"  "$CLAUDE_HOME/logs"
fi

# --- Protocol + tooling (safe to overwrite, backup if differs) ---

say "Protocol + tools:"
backup_and_install "$SRC/CLAUDE.md"                "$CLAUDE_HOME/CLAUDE.md"
for f in "$SRC/hooks/"*.sh;     do backup_and_install "$f" "$CLAUDE_HOME/hooks/$(basename "$f")";    done
for f in "$SRC/commands/"*.md;  do backup_and_install "$f" "$CLAUDE_HOME/commands/$(basename "$f")"; done
for f in "$SRC/bin/"*.sh;       do backup_and_install "$f" "$CLAUDE_HOME/bin/$(basename "$f")";      done

if [[ $DRY_RUN -eq 0 ]]; then
  chmod +x "$CLAUDE_HOME/hooks/"*.sh "$CLAUDE_HOME/bin/"*.sh 2>/dev/null || true
fi
say ""

# --- IDENTITY.md (L0 — USER DATA, NEVER overwrite) ---

say "L0 identity:"
if [[ ! -f "$CLAUDE_HOME/memory/IDENTITY.md" ]]; then
  do_or_dry "cp '$SRC/memory/IDENTITY.md' '$CLAUDE_HOME/memory/IDENTITY.md'"
  say "  + $CLAUDE_HOME/memory/IDENTITY.md (template, please edit)"
  say "  ★ EDIT THIS FILE (hard cap 25 lines: who you are, OS, prefs, env creds)"
else
  do_or_dry "cp '$SRC/memory/IDENTITY.md' '$CLAUDE_HOME/memory/IDENTITY.template.md'"
  say "  = $CLAUDE_HOME/memory/IDENTITY.md (preserved — your data)"
  say "    reference template available at: $CLAUDE_HOME/memory/IDENTITY.template.md"
fi
say ""

# --- settings.json (NEVER auto-merge, just guide) ---

say "settings.json:"
if [[ ! -f "$CLAUDE_HOME/settings.json" ]]; then
  do_or_dry "cp '$SRC/settings.snippet.json' '$CLAUDE_HOME/settings.json'"
  say "  + $CLAUDE_HOME/settings.json (fresh, with hooks)"
else
  if grep -q '"SessionStart"' "$CLAUDE_HOME/settings.json" 2>/dev/null && \
     grep -q '"PreCompact"'   "$CLAUDE_HOME/settings.json" 2>/dev/null; then
    say "  = $CLAUDE_HOME/settings.json (already has SessionStart + PreCompact hooks)"
  else
    say "  ⚠ $CLAUDE_HOME/settings.json exists but is missing one or both hooks"
    say "    Merge the 'hooks' block from $SRC/settings.snippet.json manually."
    say "    Do NOT duplicate the top-level 'hooks' key — merge into existing one."
  fi
fi
say ""

# --- L1-fallback + L2 (NEVER touch) ---

say "L1-fallback + L2 sessions:"
say "  = $CLAUDE_HOME/projects/ (untouched — your project + session memory)"
say ""

# --- Backup summary ---

backups=$(find "$CLAUDE_HOME" -name "*.bak-$TS" 2>/dev/null | sort)
if [[ -n "$backups" ]]; then
  say "Backups created (timestamp $TS):"
  while IFS= read -r b; do say "  - $b"; done <<< "$backups"
  say ""
fi

# --- Next steps ---

say "=== Done ($mode) ==="
say ""
say "Next steps:"
if [[ ! -f "$CLAUDE_HOME/memory/IDENTITY.md" ]] || \
   grep -q "<your name" "$CLAUDE_HOME/memory/IDENTITY.md" 2>/dev/null; then
  say "  1. Edit $CLAUDE_HOME/memory/IDENTITY.md (≤25 lines)"
fi
say "  2. Optional: install retrieval tools (qmd, ctags, ripgrep) — see INSTALL.md"
say "  3. Start a new Claude Code session — hooks fire automatically"
say ""
say "To rollback to backed-up versions:"
say "  for f in $CLAUDE_HOME/**/*.bak-$TS; do mv \"\$f\" \"\${f%.bak-$TS}\"; done"
