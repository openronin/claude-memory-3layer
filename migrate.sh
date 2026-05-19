#!/usr/bin/env bash
# migrate.sh — mechanical format migrations for claude-memory-3layer.
#
# Handles automatically:
#   (B) HTML-comment `<!-- last_updated: ISO -->` on line 1
#       → YAML frontmatter with `last_updated:` + `tags:` derived from filename.
#       Backup of original written as <file>.bak-<timestamp>.
#
# Detects but DOES NOT auto-fix (requires AI synthesis):
#   (A) Pre-2026-04-30 legacy: MEMORY.md + feedback_*.md + project_*.md +
#       reference_*.md in <slug>/memory/  →  single new-format project.md
#       For this case, run the Claude Code slash-command /migrate-legacy-memory
#       in any session (it uses an Agent to read + synthesize properly).
#
# Usage:
#   ./migrate.sh             # apply
#   ./migrate.sh --dry-run   # preview, no writes

set -e
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
TS=$(date +%Y%m%d-%H%M%S)
DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

say() { printf '%s\n' "$*"; }

derive_tags() {
  local base="$1"
  case "$base" in
    IDENTITY.md)                         echo "[memory/l0, identity]" ;;
    SESSION.md)                          echo "[memory/l2, session]" ;;
    project.md)                          echo "[memory/l1, project]" ;;
    gotchas.md|gotchas_*.md|gotcha_*.md) echo "[memory/l1, gotcha]" ;;
    protocol_*.md)                       echo "[memory/l1, protocol]" ;;
    format_*.md|*_format.md|*_layout.md) echo "[memory/l1, format]" ;;
    handoff_*.md|HANDOFF_*.md)           echo "[memory/l1, handoff]" ;;
    *)                                   echo "[memory/l1]" ;;
  esac
}

migrate_html_marker() {
  local f="$1"
  local first
  first=$(head -n1 "$f" 2>/dev/null)
  # Only handle line-1 HTML-comment form: <!-- last_updated: ISO -->
  if [[ ! "$first" =~ ^\<!--[[:space:]]*last_updated:[[:space:]]*([0-9T:.Z+-]+)[[:space:]]*--\>[[:space:]]*$ ]]; then
    return 0
  fi
  local iso="${BASH_REMATCH[1]}"
  local base
  base=$(basename "$f")
  local tags
  tags=$(derive_tags "$base")

  if [[ $DRY_RUN -eq 1 ]]; then
    say "  [dry] $f  →  last_updated: $iso, tags: $tags"
    return 0
  fi

  cp "$f" "$f.bak-$TS"
  {
    printf -- '---\nlast_updated: %s\ntags: %s\n---\n' "$iso" "$tags"
    tail -n +2 "$f"
  } > "$f.tmp" && mv "$f.tmp" "$f"
  say "  ~ $f  →  YAML frontmatter (backup: $f.bak-$TS)"
}

say "=== claude-memory-3layer mechanical migration ==="
say "CLAUDE_HOME: $CLAUDE_HOME"
[[ $DRY_RUN -eq 1 ]] && say "[DRY RUN — no writes]"
say ""

# --- Migration B: HTML-comment markers → YAML frontmatter ---

say "Pass B — HTML-comment markers → YAML frontmatter:"
count_b=0
shopt -s nullglob
for f in "$CLAUDE_HOME/memory"/*.md "$CLAUDE_HOME/projects"/*/memory/*.md; do
  [[ -f "$f" ]] || continue
  first=$(head -n1 "$f" 2>/dev/null)
  if [[ "$first" =~ ^\<!--[[:space:]]*last_updated: ]]; then
    migrate_html_marker "$f"
    count_b=$((count_b + 1))
  fi
done
[[ $count_b -eq 0 ]] && say "  (no HTML-comment markers found — already on YAML frontmatter or no files)"
say ""

# --- Detect Migration A: legacy files ---

legacy_dirs=()
for d in "$CLAUDE_HOME/projects"/*/memory; do
  [[ -d "$d" ]] || continue
  # Check for any legacy file (MEMORY.md OR typed-prefix files)
  legacy_count=$(ls "$d"/MEMORY.md "$d"/feedback_*.md "$d"/project_*.md "$d"/reference_*.md 2>/dev/null | wc -l)
  if [[ $legacy_count -gt 0 ]]; then
    # Skip if already migrated (legacy/ subdir already exists)
    if [[ -d "$d/legacy" ]]; then
      continue
    fi
    legacy_dirs+=("$d")
  fi
done

if [[ ${#legacy_dirs[@]} -gt 0 ]]; then
  say "Pass A — legacy MEMORY.md / feedback_* / project_* / reference_* detected:"
  for d in "${legacy_dirs[@]}"; do
    n=$(ls "$d"/MEMORY.md "$d"/feedback_*.md "$d"/project_*.md "$d"/reference_*.md 2>/dev/null | wc -l)
    say "  - $d ($n legacy file(s))"
  done
  say ""
  say "These files contain accumulated knowledge in the pre-2026-04-30 format."
  say "Mechanical conversion would lose nuance — synthesis is needed:"
  say ""
  say "  → Run in any Claude Code session:    /migrate-legacy-memory"
  say ""
  say "The slash-command spawns an Agent that reads each legacy directory,"
  say "synthesizes a single new-format project.md per project (preserving"
  say "verbatim technical details and reviewer quotes), and moves originals"
  say "into <slug>/memory/legacy/ as backup."
else
  say "Pass A — no legacy MEMORY.md/feedback_*/project_*/reference_* detected. ✓"
fi
say ""

say "=== Done ==="
[[ $count_b -gt 0 ]] && say "Migrated $count_b file(s) to YAML frontmatter."
[[ ${#legacy_dirs[@]} -gt 0 ]] && say "Manual step pending: /migrate-legacy-memory for ${#legacy_dirs[@]} project(s)."
say ""
say "Rollback (Pass B):"
say "  for f in $CLAUDE_HOME/**/*.bak-$TS; do mv \"\$f\" \"\${f%.bak-$TS}\"; done"
