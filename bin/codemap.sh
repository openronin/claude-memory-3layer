#!/usr/bin/env bash
# codemap.sh — on-demand AST-ish symbol map via universal-ctags + ripgrep.
# No daemon, no background watcher. Re-scans only if tags file is stale.
#
# Usage:
#   codemap.sh def <symbol>           → where defined (file:line, kind, signature)
#   codemap.sh callers <symbol>       → who calls / references it
#   codemap.sh callees <symbol>       → what does it call (best-effort grep inside def)
#   codemap.sh outline                → top-level symbol map of cwd repo
#   codemap.sh refresh                → force tags rebuild
#
# Cwd is treated as the search root. If cwd is inside a git repo, the repo
# root is used. Tags file: <root>/.codemap.tags (gitignore-friendly).

set -u

find_ctags() {
  for c in ctags \
           /usr/local/bin/ctags \
           "/c/Program Files/Universal Ctags/ctags.exe"; do
    if command -v "$c" >/dev/null 2>&1 || [ -x "$c" ]; then echo "$c"; return 0; fi
  done
  return 1
}
ctags_bin=$(find_ctags) || { echo "ctags not found"; exit 2; }

find_rg() {
  # Resolve a REAL rg binary (not Claude Code's shell function wrapper).
  for c in /usr/local/bin/rg /opt/homebrew/bin/rg /usr/bin/rg \
           "/c/Program Files/ripgrep/rg.exe"; do
    [ -x "$c" ] && { echo "$c"; return 0; }
  done
  local p
  p=$(find "${LOCALAPPDATA:-$HOME/AppData/Local}/Microsoft/WinGet/Packages" -maxdepth 5 -name 'rg.exe' -type f 2>/dev/null | head -1)
  [ -n "$p" ] && { echo "$p"; return 0; }
  # Last resort: rely on PATH (may be the function in interactive shells)
  command -v rg >/dev/null 2>&1 && { echo "rg"; return 0; }
  return 1
}
rg_bin=$(find_rg) || { echo "rg (ripgrep) not found — install via 'winget install BurntSushi.ripgrep.MSVC' (Windows), 'brew install ripgrep' (mac), 'apt install ripgrep' (Linux)"; exit 2; }

resolve_root() {
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || root="$PWD"
  echo "$root"
}

build_tags() {
  local root="$1"
  local tags_file="$root/.codemap.tags"
  # Exclude common heavy dirs
  "$ctags_bin" -R \
    --exclude=node_modules --exclude=.git --exclude=.idea --exclude=.vscode \
    --exclude=dist --exclude=build --exclude=.next --exclude=.nuxt \
    --exclude=vendor --exclude=__pycache__ --exclude=*.min.js \
    --exclude=examples --exclude=raw \
    --fields=+ne --extras=+q --languages=-JSON,Make,Markdown \
    -f "$tags_file" "$root" 2>/dev/null
  echo "$tags_file"
}

ensure_tags() {
  local root="$1"
  local tags_file="$root/.codemap.tags"
  local force="${2:-0}"
  if [ "$force" = "1" ] || [ ! -f "$tags_file" ]; then
    build_tags "$root" >/dev/null
    return
  fi
  # Stale if any source file newer than tags
  local newer
  newer=$(find "$root" -type f \( -name "*.py" -o -name "*.php" -o -name "*.js" -o -name "*.ts" -o -name "*.tsx" -o -name "*.go" -o -name "*.rs" -o -name "*.java" -o -name "*.c" -o -name "*.cpp" -o -name "*.h" -o -name "*.cs" -o -name "*.rb" \) \
    -newer "$tags_file" -not -path "*/node_modules/*" -not -path "*/.git/*" -print -quit 2>/dev/null)
  if [ -n "$newer" ]; then
    build_tags "$root" >/dev/null
  fi
}

cmd="${1:-}"
arg="${2:-}"

case "$cmd" in
  def)
    [ -z "$arg" ] && { echo "Usage: codemap.sh def <symbol>"; exit 1; }
    root=$(resolve_root); ensure_tags "$root"
    grep "^${arg}	" "$root/.codemap.tags" 2>/dev/null \
      | awk -F'\t' '{
          file=$2; rest=$3;
          for(i=4;i<=NF;i++) rest=rest "\t" $i;
          printf "%s\n  %s\n  %s\n\n", file, rest, $0;
        }' \
      | head -60
    ;;
  callers)
    [ -z "$arg" ] && { echo "Usage: codemap.sh callers <symbol>"; exit 1; }
    root=$(resolve_root); ensure_tags "$root"
    # References: any line mentioning the symbol followed by `(` or `::`, excluding the definition line.
    "$rg_bin" -g '*.py' -g '*.php' -g '*.js' -g '*.ts' -g '*.tsx' -g '*.go' -g '*.rs' -g '*.java' -g '*.c' -g '*.cpp' -g '*.h' -g '*.cs' -g '*.rb' \
       -n --no-heading -e "\\b${arg}\\b" "$root" 2>/dev/null \
       | grep -vE "^[^:]+:[0-9]+:.*\b(class|function|def|interface|trait)\s+${arg}\b" \
       | head -50
    ;;
  callees)
    [ -z "$arg" ] && { echo "Usage: codemap.sh callees <symbol>"; exit 1; }
    root=$(resolve_root); ensure_tags "$root"
    # Find def location, then grep callable patterns inside the body (heuristic: next 100 lines).
    def_line=$(grep "^${arg}	" "$root/.codemap.tags" 2>/dev/null | head -1)
    [ -z "$def_line" ] && { echo "(no definition found for ${arg})"; exit 0; }
    file=$(echo "$def_line" | awk -F'\t' '{print $2}')
    lineno=$(echo "$def_line" | grep -oE 'line:[0-9]+' | head -1 | cut -d: -f2)
    if [ -z "$lineno" ] || [ -z "$file" ]; then
      echo "(could not resolve def location)"; exit 0
    fi
    awk -v start="$lineno" -v end="$((lineno + 200))" 'NR>=start && NR<=end' "$file" 2>/dev/null \
      | grep -oE '\b[A-Za-z_][A-Za-z0-9_]+\s*\(' \
      | sed 's/[[:space:]]*($//' \
      | sort -u | head -40
    ;;
  outline)
    root=$(resolve_root); ensure_tags "$root"
    awk -F'\t' '{
      kind=$4;
      if (kind=="c" || kind=="f" || kind=="m" || kind=="class" || kind=="function" || kind=="method")
        printf "%-10s %-50s %s\n", kind, $1, $2;
    }' "$root/.codemap.tags" 2>/dev/null | sort -u | head -80
    ;;
  refresh)
    root=$(resolve_root); build_tags "$root" >/dev/null
    count=$(wc -l < "$root/.codemap.tags")
    echo "Rebuilt: $root/.codemap.tags ($count tags)"
    ;;
  ""|--help|-h|help)
    grep '^#' "$0" | sed 's/^# \{0,1\}//' | head -20
    ;;
  *)
    echo "Unknown command: $cmd"; echo "Try: def | callers | callees | outline | refresh"; exit 1
    ;;
esac
