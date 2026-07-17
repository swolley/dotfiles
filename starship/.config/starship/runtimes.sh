#!/usr/bin/env bash
# Alternating gray powerline segments for project runtimes.
# Prints raw ANSI so carets always match the adjacent block colors.
# Last caret transitions into surface2 (Starship time module).

set -euo pipefail

surface2_r=58 surface2_g=59 surface2_b=62   # #3a3b3e
surface_r=42  surface_g=43  surface_b=46    # #2a2b2e
text_r=216    text_g=221    text_b=217      # #d8ddd9

fg() { printf '\e[38;2;%s;%s;%sm' "$1" "$2" "$3"; }
bg() { printf '\e[48;2;%s;%s;%sm' "$1" "$2" "$3"; }
reset=$'\e[0m'
caret=''

set_pair() {
  # $1 = 0 → surface2, 1 → surface
  if [[ "$1" == "0" ]]; then
    R=$surface2_r G=$surface2_g B=$surface2_b
  else
    R=$surface_r G=$surface_g B=$surface_b
  fi
}

segments=()

add() {
  local sym="$1" ver="$2"
  [[ -n "${ver}" ]] || return 0
  segments+=("${sym}|${ver}")
}

# Detect like Starship (project files), not merely "binary exists"
if [[ -f package.json || -f .nvmrc || -f .node-version || -d node_modules ]]; then
  if command -v node >/dev/null 2>&1; then
    add "" "$(node -v 2>/dev/null | tr -d 'v')"
  fi
fi

if [[ -f composer.json || -f .php-version || -f artisan ]]; then
  if command -v php >/dev/null 2>&1; then
    add "" "$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION.".".PHP_RELEASE_VERSION;' 2>/dev/null)"
  fi
fi

if [[ -f requirements.txt || -f pyproject.toml || -f setup.py || -f Pipfile || -f .python-version ]]; then
  py=python3
  command -v python3 >/dev/null 2>&1 || py=python
  if command -v "$py" >/dev/null 2>&1; then
    add "" "$($py -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])' 2>/dev/null)"
  fi
fi

if [[ -f Cargo.toml || -f Cargo.lock ]]; then
  if command -v rustc >/dev/null 2>&1; then
    add "" "$(rustc -V 2>/dev/null | awk '{print $2}')"
  fi
fi

if [[ -f go.mod || -f go.sum ]]; then
  if command -v go >/dev/null 2>&1; then
    add "" "$(go env GOVERSION 2>/dev/null | tr -d 'go')"
  fi
fi

n=${#segments[@]}
(( n == 0 )) && exit 0

out=""
for i in "${!segments[@]}"; do
  IFS='|' read -r sym ver <<<"${segments[$i]}"
  slot=$(( i % 2 ))
  set_pair "$slot"
  cr=$R cg=$G cb=$B

  out+="$(fg "$text_r" "$text_g" "$text_b")$(bg "$cr" "$cg" "$cb") ${sym} ${ver} ${reset}"

  # Caret into next segment, or into time (always surface2)
  if (( i < n - 1 )); then
    next=$(( (i + 1) % 2 ))
    set_pair "$next"
    nr=$R ng=$G nb=$B
  else
    nr=$surface2_r ng=$surface2_g nb=$surface2_b
  fi
  out+="$(fg "$cr" "$cg" "$cb")$(bg "$nr" "$ng" "$nb")${caret}${reset}"
done

printf '%s' "$out"
