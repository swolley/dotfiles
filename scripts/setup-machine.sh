#!/usr/bin/env bash
# setup-machine.sh — prepara una macchina Arch / EndeavourOS da zero.
#
# Presuppone che i dotfiles siano gia' clonati: lo script installa i pacchetti,
# abilita i servizi e applica i symlink con stow.
#
# Le liste stanno in scripts/packages/*.txt, una per gruppo. I linguaggi non
# hanno versioni fissate: i repo portano sempre l'ultima stabile.
#
# L'IDE non sta in nessuna lista: se selezioni un gruppo dev-*, lo script chiede
# quale installare tra quelli dell'elenco IDES qui sotto.
#
# Uso:
#   ./scripts/setup-machine.sh              # chiede gruppo per gruppo
#   ./scripts/setup-machine.sh --yes        # installa tutto senza chiedere
#   ./scripts/setup-machine.sh --only niri-noctalia,dev-php
#   ./scripts/setup-machine.sh --ide cursor # IDE dei gruppi dev-* senza chiedere
#                                           # (piu' d'uno separati da virgola, none = nessuno)
#   ./scripts/setup-machine.sh --dry-run    # mostra cosa farebbe
#   ./scripts/setup-machine.sh --list       # elenca i gruppi e gli IDE

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
IDE_CHOICE=""   # da --ide: chiavi separate da virgola, oppure "none"
IDE_PKGS=()

# IDE tra cui scegliere quando si installa un gruppo dev-*: "chiave|etichetta|pacchetti".
# Il primo e' quello usato con --yes. Per aggiungerne uno basta una riga.
IDES=(
  "code|Visual Studio Code (Code - OSS)|code"
  "cursor|Cursor|cursor-bin"
)

# Servizi di sistema e utente da riabilitare.
SERVICES_SYSTEM=(NetworkManager firewalld gdm avahi-daemon lm_sensors
                 power-profiles-daemon fstrim.timer paccache.timer)
SERVICES_USER=()

# Pacchetti stow da applicare (tutte le cartelle del repo che non sono scripts/).
# easyeffects: db/ e' stato macchina (casa vs ufficio); lo riprendiamo dopo.
STOW_SKIP="scripts easyeffects"

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

# Pacchetti della lista non ancora installati (verifica con pacman -Qq).
missing_of() {
  local pkg
  while IFS= read -r pkg; do
    pacman -Qq "$pkg" >/dev/null 2>&1 || printf '%s\n' "$pkg"
  done < <(packages_of "$1")
}

# "3 da installare (12 gia' presenti)" oppure "tutti presenti (12)".
pkg_summary() {
  local total missing
  total=$(packages_of "$1" | wc -l)
  missing=$(missing_of "$1" | wc -l)
  if [ "$missing" -eq 0 ]; then
    printf 'tutti presenti (%s)' "$total"
  else
    printf '%s da installare (%s gia'\'' presenti)' "$missing" "$((total - missing))"
  fi
}

# True se c'e' un controller grafico NVIDIA (vendor 10de).
has_nvidia_gpu() {
  lspci -nn 2>/dev/null | grep -qiE 'NVIDIA.*(VGA|3D controller|Display controller)'
}

ask() {  # ask "domanda" -> 0 se si' (default: no)
  [ "$ASSUME_YES" -eq 1 ] && return 0
  local reply
  read -rp "    $1 [s/N] " reply </dev/tty || return 1
  case "${reply,,}" in s|si|y|yes) return 0 ;; *) return 1 ;; esac
}

ide_field() {  # ide_field "riga" N -> campo N (1 chiave, 2 etichetta, 3 pacchetti)
  printf '%s' "$1" | cut -d'|' -f"$2"
}

ide_by_key() {  # stampa la riga di IDES con quella chiave, altrimenti fallisce
  local line
  for line in "${IDES[@]}"; do
    if [ "$(ide_field "$line" 1)" = "$1" ]; then
      printf '%s' "$line"
      return 0
    fi
  done
  return 1
}

ide_installed() {  # true se tutti i pacchetti dell'IDE sono gia' presenti
  local pkgs p
  read -ra pkgs <<<"$(ide_field "$1" 3)"
  for p in "${pkgs[@]}"; do
    pacman -Qq "$p" >/dev/null 2>&1 || return 1
  done
}

# Se tra i gruppi scelti c'e' un dev-*, decide quale IDE installare (uno, piu'
# d'uno o nessuno) e mette i pacchetti in IDE_PKGS. Senza gruppi dev-* non fa
# nulla e non chiede niente.
select_ide() {
  local f has_dev=0 line key tag reply n pkgs
  local picked=() keys=() nums=()

  for f in "${selected[@]}"; do
    case "$(group_name "$f")" in dev-*) has_dev=1; break ;; esac
  done
  [ "$has_dev" -eq 1 ] || return 0

  section "IDE"
  if [ -n "$IDE_CHOICE" ]; then
    if [ "$IDE_CHOICE" != none ]; then
      IFS=, read -ra keys <<<"$IDE_CHOICE"
      for key in "${keys[@]}"; do picked+=("$(ide_by_key "$key")"); done
    fi
  elif [ "$ASSUME_YES" -eq 1 ]; then
    picked=("${IDES[0]}")
  else
    info "Quale IDE installare? (numeri separati da virgola o spazio)"
    n=1
    for line in "${IDES[@]}"; do
      tag=""
      ide_installed "$line" && tag=" (gia' installato)"
      printf '      %d) %-8s %s%s\n' "$n" "$(ide_field "$line" 1)" "$(ide_field "$line" 2)" "$tag"
      n=$((n+1))
    done
    printf '      0) nessuno\n'
    read -rp "    Scelta [invio = 0] " reply </dev/tty || reply=""
    IFS=', ' read -ra nums <<<"$reply"
    for n in "${nums[@]}"; do
      case "$n" in
        0) picked=(); break ;;
        ''|*[!0-9]*) warn "scelta non valida: $n"; continue ;;
      esac
      if [ "$n" -ge 1 ] && [ "$n" -le "${#IDES[@]}" ]; then
        picked+=("${IDES[$((n-1))]}")
      else
        warn "fuori intervallo: $n"
      fi
    done
  fi

  if [ ${#picked[@]} -eq 0 ]; then
    info "nessun IDE da installare"
    return 0
  fi
  for line in "${picked[@]}"; do
    read -ra pkgs <<<"$(ide_field "$line" 3)"
    IDE_PKGS+=("${pkgs[@]}")
    ok "IDE: $(ide_field "$line" 2)"
  done
}

# Marca + nome da EDID del connettore DRM (es. "ACR XB270HU").
monitor_edid_label() {
  local edid="$1/edid" out make name model
  [ -r "$edid" ] || { printf 'sconosciuto'; return; }
  [ "$(wc -c < "$edid" 2>/dev/null || echo 0)" -ge 128 ] || { printf 'sconosciuto'; return; }

  if command -v edid-decode >/dev/null 2>&1; then
    out=$(edid-decode "$edid" 2>/dev/null) || out=
    make=$(printf '%s\n' "$out" | sed -n 's/^[[:space:]]*Manufacturer:[[:space:]]*//p' | head -1)
    name=$(printf '%s\n' "$out" | sed -n "s/^[[:space:]]*Display Product Name:[[:space:]]*'\\(.*\\)'\$/\\1/p" | head -1)
    name=$(printf '%s' "$name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    model=$(printf '%s\n' "$out" | sed -n 's/^[[:space:]]*Model:[[:space:]]*//p' | head -1)
    if [ -n "$make" ] && [ -n "$name" ]; then
      printf '%s %s' "$make" "$name"
      return
    fi
    if [ -n "$make" ]; then
      printf '%s (model %s)' "$make" "${model:-?}"
      return
    fi
  fi

  # Fallback senza edid-decode: manufacturer PNP + descriptor 0xFC.
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$edid" <<'PY' 2>/dev/null && return
import sys
b = open(sys.argv[1], "rb").read(128)
if len(b) < 128:
    print("sconosciuto"); raise SystemExit
mid = (b[8] << 8) | b[9]
make = "".join(
    chr(((mid >> 10) & 0x1F) + 64)
    + chr(((mid >> 5) & 0x1F) + 64)
    + chr((mid & 0x1F) + 64)
)
name = ""
for off in (54, 72, 90, 108):
    if b[off] == 0 and b[off + 1] == 0 and b[off + 3] == 0xFC:
        name = b[off + 5 : off + 18].split(b"\n", 1)[0].decode("ascii", "ignore").strip()
        break
model = (b[11] << 8) | b[10]
print(f"{make} {name}" if name else f"{make} (model {model})")
PY
  fi
  printf 'EDID presente'
}

detect_monitors() {  # stampa "CONNETTORE<TAB>marca nome"
  local st dir conn desc
  # Preferisci /sys+EDID: funziona anche fuori da niri e mostra marca/modello
  # leggibili (ARZOPA, XB270HU…), non solo DP-1 / DP-6.
  for st in /sys/class/drm/card*-*/status; do
    [ -r "$st" ] || continue
    [ "$(cat "$st")" = connected ] || continue
    dir=$(dirname "$st")
    conn=$(basename "$dir" | sed -E 's/^card[0-9]+-//')
    desc=$(monitor_edid_label "$dir")
    case "$conn" in
      eDP-*) desc="$desc (pannello interno)" ;;
    esac
    printf '%s\t%s\n' "$conn" "$desc"
  done
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
    printf '      %d) %-12s %s\n' "$i" "${m%%$'\t'*}" "${m#*$'\t'}"
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

configure_nautilus_terminal() {
  local schema=com.github.stunkymonkey.nautilus-open-any-terminal
  local cmd="$HOME/.config/niri/terminal.sh cwd"
  if ! gsettings list-schemas 2>/dev/null | grep -qx "$schema"; then
    warn "nautilus-open-any-terminal non installato, salto"
    return
  fi
  info "collego \"Apri nel terminale\" allo script del terminale unico"
  run gsettings set "$schema" terminal custom
  run gsettings set "$schema" custom-local-command "$cmd"
  run gsettings set "$schema" new-tab false
  if pacman -Qq gnome-terminal >/dev/null 2>&1; then
    warn "gnome-terminal e' installato: il menu mostrera' due voci \"Apri nel terminale\""
    warn "rimuovilo con: sudo pacman -Rns gnome-terminal"
  fi
}

configure_firefox_theme() {
  if ! command -v noctalia >/dev/null 2>&1; then
    warn "noctalia non installato, salto il tema di Firefox"
    return
  fi
  # Firefox non legge i colori da GTK: con il tema di sistema usa l'accento del
  # portale desktop, che accetta solo i preset di libadwaita. L'unico modo di
  # avere l'accento di noctalia e' il percorso Pywalfox, di cui noctalia stesso
  # fa da host nativo.
  info "installo l'host nativo Pywalfox e applico i template"
  run noctalia firefox-theme install
  run noctalia msg templates-apply
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
  sed -n '2,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y)     ASSUME_YES=1 ;;
    --dry-run|-n) DRY_RUN=1 ;;
    --no-stow)    DO_STOW=0 ;;
    --no-services) DO_SERVICES=0 ;;
    --only)       ONLY="${2:-}"; shift ;;
    --ide)        IDE_CHOICE="${2:-}"; shift ;;
    --list)
      for f in "$PKG_DIR"/*.txt; do
        g=$(group_name "$f")
        printf '  %-16s %s — %s\n' "$g" "$(group_label "$g")" "$(pkg_summary "$f")"
      done
      printf '\n  IDE (si scelgono con i gruppi dev-*, o con --ide):\n'
      for line in "${IDES[@]}"; do
        printf '  %-16s %s — %s\n' "$(ide_field "$line" 1)" "$(ide_field "$line" 2)" "$(ide_field "$line" 3)"
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

if [ -n "$IDE_CHOICE" ] && [ "$IDE_CHOICE" != none ]; then
  IFS=, read -ra _keys <<<"$IDE_CHOICE"
  for _k in "${_keys[@]}"; do
    ide_by_key "$_k" >/dev/null || die "IDE sconosciuto: '$_k' (disponibili: $(for _l in "${IDES[@]}"; do printf '%s ' "$(ide_field "$_l" 1)"; done)o none)"
  done
fi

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
  # NVIDIA: chiedi/installa solo se c'e' la scheda (anche con --yes/--only).
  if [ "$g" = nvidia ] && ! has_nvidia_gpu; then
    ok "nvidia: nessuna GPU NVIDIA rilevata, salto"
    continue
  fi
  if [ -n "$ONLY" ]; then
    case ",$ONLY," in *",$g,"*) selected+=("$f") ;; esac
    continue
  fi
  if [ "$g" = base ]; then
    selected+=("$f")
    continue
  fi
  if [ "$(missing_of "$f" | wc -l)" -eq 0 ]; then
    ok "$(group_label "$g") — $(pkg_summary "$f")"
    continue
  fi
  if ask "$(group_label "$g") — $(pkg_summary "$f"). Installare?"; then
    selected+=("$f")
  fi
done

[ ${#selected[@]} -gt 0 ] || die "nessun gruppo selezionato"

select_ide

for f in "${selected[@]}"; do
  g=$(group_name "$f")
  mapfile -t pkgs < <(missing_of "$f")
  if [ ${#pkgs[@]} -eq 0 ]; then
    ok "$g: niente da installare ($(pkg_summary "$f"))"
    continue
  fi
  info "${BLUE}$g${RESET}: ${#pkgs[@]} da installare"
  run "$HELPER" -S --needed --noconfirm "${pkgs[@]}"
done

if [ ${#IDE_PKGS[@]} -gt 0 ]; then
  info "${BLUE}ide${RESET}: ${#IDE_PKGS[@]} pacchetti (quelli gia' presenti vengono saltati)"
  run "$HELPER" -S --needed --noconfirm "${IDE_PKGS[@]}"
fi

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
    # set -e interromperebbe tutto lo script: un conflitto su un pacchetto
    # non deve annullare gli stow successivi ne' le sezioni dopo (shell, monitor…).
    # "All operations aborted" di stow riguarda solo quel pacchetto, non i precedenti.
    if [ "$DRY_RUN" -eq 1 ]; then
      run stow --restow "$p"
    elif stow --restow "$p"; then
      :
    else
      warn "stow $p fallito (conflitti o file gia' presenti): continuo con gli altri"
    fi
  done
fi

section "Shell"
setup_shell

section "Monitor e barra"
configure_monitors

section "Nautilus"
configure_nautilus_terminal

section "Tema di Firefox"
configure_firefox_theme

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
      - Firefox:            installa l'estensione Pywalfox da addons.mozilla.org
                            e premi una volta "Fetch pywal colors"
EOF
