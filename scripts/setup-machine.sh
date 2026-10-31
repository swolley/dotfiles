#!/usr/bin/env bash
# setup-machine.sh — prepara una macchina Arch / EndeavourOS da zero.
#
# Presuppone che i dotfiles siano gia' clonati: lo script installa i pacchetti,
# abilita i servizi e applica i symlink con stow.
#
# Le liste stanno in scripts/packages/*.txt, una per gruppo. I linguaggi non
# hanno versioni fissate: i repo portano sempre l'ultima stabile.
#
# Uso:
#   ./scripts/setup-machine.sh              # chiede gruppo per gruppo
#   ./scripts/setup-machine.sh --yes        # installa tutto senza chiedere
#   ./scripts/setup-machine.sh --only niri-noctalia,dev-php
#   ./scripts/setup-machine.sh --dry-run    # mostra cosa farebbe
#   ./scripts/setup-machine.sh --list       # elenca i gruppi

set -euo pipefail

RED="\033[1;31m"; GREEN="\033[1;32m"; YELLOW="\033[1;33m"
BLUE="\033[1;34m"; CYAN="\033[1;36m"; DIM="\033[2m"; RESET="\033[0m"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_DIR="$REPO_DIR/scripts/packages"

ASSUME_YES=0
DRY_RUN=0
DO_STOW=1
DO_SERVICES=1
ONLY=""

# Servizi di sistema e utente da riabilitare.
SERVICES_SYSTEM=(NetworkManager firewalld gdm avahi-daemon lm_sensors
                 power-profiles-daemon fstrim.timer paccache.timer)
SERVICES_USER=()

# Pacchetti stow da applicare (tutte le cartelle del repo che non sono scripts/).
STOW_SKIP="scripts"

section() { echo -e "\n${CYAN}==>${RESET} ${BLUE}$1${RESET}"; }
info()    { echo -e "    $*"; }
ok()      { echo -e "    ${GREEN}ok${RESET} $*"; }
warn()    { echo -e "    ${YELLOW}attenzione${RESET} $*"; }
die()     { echo -e "${RED}errore:${RESET} $*" >&2; exit 1; }

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo -e "    ${DIM}\$ $*${RESET}"
  else
    "$@"
  fi
}

group_name() {  # 20-niri-noctalia.txt -> niri-noctalia
  basename "$1" .txt | sed -E 's/^[0-9]+-//'
}

group_label() {
  case "$1" in
    base)           echo "Base: shell, CLI, git, manutenzione pacman" ;;
    desktop-gnome)  echo "Desktop GNOME con estensioni e app di sistema" ;;
    niri-noctalia)  echo "Sessione niri con shell noctalia" ;;
    nvidia)         echo "Driver NVIDIA precompilati e PRIME" ;;
    apps)           echo "Applicazioni grafiche" ;;
    dev-php)        echo "PHP e Laravel (ultima stabile dai repo)" ;;
    dev-node)       echo "Node, npm, pnpm" ;;
    dev-python)     echo "Python con uv" ;;
    dev-rust)       echo "Rust e cargo" ;;
    dev-go)         echo "Go" ;;
    dev-java)       echo "OpenJDK" ;;
    *)              echo "$1" ;;
  esac
}

packages_of() {
  grep -vE '^\s*#|^\s*$' "$1"
}

ask() {  # ask "domanda" -> 0 se si'
  [ "$ASSUME_YES" -eq 1 ] && return 0
  local reply
  read -rp "    $1 [S/n] " reply </dev/tty || return 1
  case "${reply,,}" in n|no) return 1 ;; *) return 0 ;; esac
}

detect_monitors() {  # stampa "CONNETTORE<TAB>descrizione"
  if command -v niri >/dev/null 2>&1 && niri msg --json outputs >/dev/null 2>&1; then
    niri msg --json outputs | jq -r 'to_entries[] | "\(.key)\t\(.value.make) \(.value.model)"'
  else
    for st in /sys/class/drm/card*-*/status; do
      [ -r "$st" ] || continue
      [ "$(cat "$st")" = connected ] || continue
      n=$(basename "$(dirname "$st")")
      printf '%s\t%s\n' "${n#card*-}" "rilevato da /sys"
    done
  fi
}

configure_monitors() {
  local target="$HOME/.config/noctalia/90-monitors.local.toml"
  mapfile -t mons < <(detect_monitors)
  if [ ${#mons[@]} -eq 0 ]; then
    warn "nessun monitor rilevato, salto la configurazione della barra"
    return
  fi

  info "Monitor rilevati:"
  local i=1
  for m in "${mons[@]}"; do
    printf '      %d) %-10s %s\n' "$i" "${m%%$'\t'*}" "${m#*$'\t'}"
    i=$((i+1))
  done

  local scelta=1
  if [ "$ASSUME_YES" -eq 0 ]; then
    read -rp "    Quale e' il monitor principale? [1-${#mons[@]}, invio = 1] " scelta </dev/tty || scelta=1
    [ -n "$scelta" ] || scelta=1
  fi
  case "$scelta" in
    ''|*[!0-9]*) warn "scelta non valida, uso il primo"; scelta=1 ;;
  esac
  [ "$scelta" -ge 1 ] && [ "$scelta" -le ${#mons[@]} ] || { warn "fuori intervallo, uso il primo"; scelta=1; }

  local primario
  primario="${mons[$((scelta-1))]%%$'\t'*}"
  ok "principale: $primario (barra fissa; sugli altri a scomparsa)"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo -e "    ${DIM}\$ scrive $target${RESET}"
    return
  fi

  mkdir -p "$(dirname "$target")"
  {
    echo "# Generato da setup-machine.sh: dipende dai monitor di QUESTA macchina."
    echo "# Non e' nei dotfiles. Rilancia lo script per rigenerarlo."
    echo
    echo "[notification]"
    echo "monitors = [ \"$primario\" ]"
    echo
    echo "[osd]"
    echo "monitors = [ \"$primario\" ]"
    echo
    echo "[dock.monitor.$primario]"
    echo "enabled = true"
    for m in "${mons[@]}"; do
      local conn="${m%%$'\t'*}"
      [ "$conn" = "$primario" ] && continue
      echo
      echo "[bar.default.monitor.$(echo "$conn" | tr -cd '[:alnum:]' | tr 'A-Z' 'a-z')]"
      echo "match = \"$conn\""
      echo "auto_hide = true"
      echo "reserve_space = false"
    done
  } > "$target"
  ok "scritto $target"

  if command -v noctalia >/dev/null 2>&1; then
    noctalia config validate >/dev/null 2>&1 && ok "configurazione noctalia valida" \
      || warn "noctalia segnala problemi: controlla con 'noctalia config validate'"
  fi
}

setup_shell() {
  local zsh=/usr/bin/zsh
  [ -x "$zsh" ] || { warn "zsh non installato, salto"; return; }
  if [ "$(getent passwd "$USER" | cut -d: -f7)" = "$zsh" ]; then
    ok "zsh e' gia' la shell di default"
    return
  fi
  info "imposto zsh come shell di default"
  run sudo chsh -s "$zsh" "$USER"
}

usage() {
  sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y)     ASSUME_YES=1 ;;
    --dry-run|-n) DRY_RUN=1 ;;
    --no-stow)    DO_STOW=0 ;;
    --no-services) DO_SERVICES=0 ;;
    --only)       ONLY="${2:-}"; shift ;;
    --list)
      for f in "$PKG_DIR"/*.txt; do
        g=$(group_name "$f")
        printf '  %-16s %s (%s pacchetti)\n' "$g" "$(group_label "$g")" "$(packages_of "$f" | wc -l)"
      done
      exit 0 ;;
    --help|-h)    usage ;;
    *)            die "opzione sconosciuta: $1 (--help per l'uso)" ;;
  esac
  shift
done

[ -d "$PKG_DIR" ] || die "cartella delle liste non trovata: $PKG_DIR"
command -v pacman >/dev/null || die "questo script funziona su Arch / EndeavourOS"
[ "$(id -u)" -ne 0 ] || die "non lanciarlo come root: usa il tuo utente, chiedera' sudo quando serve"

section "Helper AUR"
if command -v paru >/dev/null; then
  HELPER=paru
  ok "paru presente"
elif command -v yay >/dev/null; then
  HELPER=yay
  ok "yay presente"
else
  info "nessun helper AUR: compilo paru da sorgente"
  run sudo pacman -S --needed --noconfirm base-devel git
  tmp=$(mktemp -d)
  run git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
  run bash -c "cd '$tmp/paru-bin' && makepkg -si --noconfirm"
  run rm -rf "$tmp"
  HELPER=paru
fi

section "Pacchetti"
selected=()
for f in "$PKG_DIR"/*.txt; do
  g=$(group_name "$f")
  if [ -n "$ONLY" ]; then
    case ",$ONLY," in *",$g,"*) selected+=("$f") ;; esac
    continue
  fi
  if [ "$g" = base ]; then
    selected+=("$f")
    continue
  fi
  n=$(packages_of "$f" | wc -l)
  if ask "$(group_label "$g") — $n pacchetti. Installare?"; then
    selected+=("$f")
  fi
done

[ ${#selected[@]} -gt 0 ] || die "nessun gruppo selezionato"

for f in "${selected[@]}"; do
  g=$(group_name "$f")
  mapfile -t pkgs < <(packages_of "$f")
  info "${BLUE}$g${RESET}: ${#pkgs[@]} pacchetti"
  run "$HELPER" -S --needed --noconfirm "${pkgs[@]}"
done

if [ "$DO_SERVICES" -eq 1 ]; then
  section "Servizi"
  for s in "${SERVICES_SYSTEM[@]}"; do
    if systemctl list-unit-files "$s"* >/dev/null 2>&1; then
      run sudo systemctl enable "$s"
    else
      warn "$s non installato, salto"
    fi
  done
  for s in "${SERVICES_USER[@]}"; do
    run systemctl --user enable "$s"
  done
fi

if [ "$DO_STOW" -eq 1 ]; then
  section "Dotfiles (stow)"
  command -v stow >/dev/null || die "stow non installato: lancia prima il gruppo base"
  cd "$REPO_DIR"
  for d in */; do
    p="${d%/}"
    case " $STOW_SKIP " in *" $p "*) continue ;; esac
    [ -d "$p" ] || continue
    info "stow $p"
    run stow --restow "$p"
  done
fi

section "Shell"
setup_shell

section "Monitor e barra"
configure_monitors

section "Fatto"
cat <<'EOF'
    Restano da fare a mano, perche' dipendono da scelte o da segreti:

      - sessione grafica:   scegli GNOME o Niri nella schermata di login
      - NVIDIA Optimus:     envycontrol -s integrated|hybrid|nvidia (poi riavvia)
      - posizione monitor:  nwg-displays (la barra l'ha gia' configurata lo script)
      - noctalia:           le impostazioni legate a questa macchina (monitor,
                            schermata di blocco, sfondi) stanno in
                            ~/.local/state/noctalia/settings.toml e non sono nel repo
      - chiavi SSH e GPG:   vanno ripristinate dal tuo backup
EOF
