#!/usr/bin/env bash
# setup-machine.sh — sets up an Arch / EndeavourOS machine from scratch.
#
# Assumes the dotfiles are already cloned: the script installs the packages,
# enables the services and applies the symlinks with stow.
#
# The lists live in scripts/packages/*.txt, one per group. Languages have no
# pinned versions: the repos always ship the latest stable release.
#
# The IDE is not in any list: if you select a dev-* group, the script asks
# which one to install from the IDES list below.
#
# Usage:
#   ./scripts/setup-machine.sh              # asks group by group
#   ./scripts/setup-machine.sh --yes        # installs everything without asking
#   ./scripts/setup-machine.sh --only niri-noctalia,dev-php
#   ./scripts/setup-machine.sh --ide cursor # IDE for the dev-* groups, no prompt
#                                           # (more than one separated by commas, none = no IDE)
#   ./scripts/setup-machine.sh --dry-run    # shows what it would do
#   ./scripts/setup-machine.sh --list       # lists the groups and the IDEs

set -euo pipefail

RED="\033[1;31m"; GREEN="\033[1;32m"; YELLOW="\033[1;33m"
BLUE="\033[1;34m"; CYAN="\033[1;36m"; DIM="\033[2m"; RESET="\033[0m"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_DIR="$REPO_DIR/scripts/packages"
REMOVE_LIST="$REPO_DIR/scripts/remove.txt"

ASSUME_YES=0
DRY_RUN=0
DO_STOW=1
DO_SERVICES=1
ONLY=""
IDE_CHOICE=""   # from --ide: comma-separated keys, or "none"
IDE_PKGS=()

# IDEs to choose from when installing a dev-* group: "key|label|packages".
# The first one is used with --yes. To add one, just add a line.
IDES=(
  "code|Visual Studio Code (Code - OSS)|code"
  "cursor|Cursor|cursor-bin"
)

# System and user services to re-enable.
# Those that do not exist on this machine (package not installed) are skipped
# without a word: the unit is checked first and only then enabled, and a
# missing one is the normal case for a list that covers several machines.
# earlyoom: kills the biggest process before the kernel OOM killer does, so a
# runaway job (parallel test workers) cannot take the whole niri session down.
# forticlient: without its service the FortiClient GUI does not show its window.
# The login manager (greetd) is not here: configure_login_manager handles it,
# because it must never run alongside another display manager.
SERVICES_SYSTEM=(NetworkManager firewalld avahi-daemon lm_sensors
                 power-profiles-daemon fstrim.timer paccache.timer
                 forticlient earlyoom)
# ssh-agent.socket: the systemd SSH agent; SSH_AUTH_SOCK is set by the stow
# package ssh (~/.config/environment.d/ssh-agent.conf).
# arch-updater-recheck.path: tells the noctalia update widget to re-check when
# pacman changes packages (unit in the noctalia stow package).
# noctalia-plugin-patches.path: re-applies scripts/patch-plugins when noctalia
# updates a community plugin.
SERVICES_USER=(ssh-agent.socket arch-updater-recheck.path noctalia-plugin-patches.path cursor-agent-reaper.timer)

# Stow packages to apply (every repo folder that is not scripts/).
# easyeffects: db/ is per-machine state (home vs office); we will pick it up later.
STOW_SKIP="scripts easyeffects"

section() { echo -e "\n${CYAN}==>${RESET} ${BLUE}$1${RESET}"; }
info()    { echo -e "    $*"; }
ok()      { echo -e "    ${GREEN}ok${RESET} $*"; }
warn()    { echo -e "    ${YELLOW}warning${RESET} $*"; }
die()     { echo -e "${RED}error:${RESET} $*" >&2; exit 1; }

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
    base)           echo "Base: shell, CLI, git, pacman maintenance" ;;
    desktop-gtk)    echo "GTK applications: files, documents, images, disks, network" ;;
    niri-noctalia)  echo "niri session with the noctalia shell" ;;
    nvidia)         echo "Prebuilt NVIDIA drivers and PRIME" ;;
    apps)           echo "Graphical applications" ;;
    dev-php)        echo "PHP and Laravel (latest stable from the repos)" ;;
    dev-node)       echo "Node, npm, pnpm" ;;
    dev-python)     echo "Python with uv" ;;
    dev-rust)       echo "Rust and cargo" ;;
    dev-go)         echo "Go" ;;
    dev-java)       echo "OpenJDK" ;;
    *)              echo "$1" ;;
  esac
}

packages_of() {
  grep -vE '^\s*#|^\s*$' "$1"
}

# Packages in the list that are not installed yet (checked with pacman -Qq).
missing_of() {
  local pkg
  while IFS= read -r pkg; do
    pacman -Qq "$pkg" >/dev/null 2>&1 || printf '%s\n' "$pkg"
  done < <(packages_of "$1")
}

# "3 to install (12 already present)" or "all present (12)".
pkg_summary() {
  local total missing
  total=$(packages_of "$1" | wc -l)
  missing=$(missing_of "$1" | wc -l)
  if [ "$missing" -eq 0 ]; then
    printf 'all present (%s)' "$total"
  else
    printf '%s to install (%s already present)' "$missing" "$((total - missing))"
  fi
}

# True if there is an NVIDIA graphics controller (vendor 10de).
has_nvidia_gpu() {
  lspci -nn 2>/dev/null | grep -qiE 'NVIDIA.*(VGA|3D controller|Display controller)'
}

ask() {  # ask "question" -> 0 if yes (default: no)
  [ "$ASSUME_YES" -eq 1 ] && return 0
  local reply
  read -rp "    $1 [y/N] " reply </dev/tty || return 1
  case "${reply,,}" in s|si|y|yes) return 0 ;; *) return 1 ;; esac
}

ide_field() {  # ide_field "line" N -> field N (1 key, 2 label, 3 packages)
  printf '%s' "$1" | cut -d'|' -f"$2"
}

ide_by_key() {  # prints the IDES line with that key, otherwise fails
  local line
  for line in "${IDES[@]}"; do
    if [ "$(ide_field "$line" 1)" = "$1" ]; then
      printf '%s' "$line"
      return 0
    fi
  done
  return 1
}

ide_installed() {  # true if all the IDE's packages are already present
  local pkgs p
  read -ra pkgs <<<"$(ide_field "$1" 3)"
  for p in "${pkgs[@]}"; do
    pacman -Qq "$p" >/dev/null 2>&1 || return 1
  done
}

# If one of the selected groups is a dev-* group, decides which IDE to install
# (one, several or none) and puts the packages in IDE_PKGS. Without dev-*
# groups it does nothing and asks nothing.
select_ide() {
  local f has_dev=0 line key tag reply n pkgs
  local picked=() keys=() nums=()

  for f in "${selected[@]}"; do
    case "$(group_name "$f")" in dev-*) has_dev=1; break ;; esac
  done
  [ "$has_dev" -eq 1 ] || return 0

  section "IDE"
  # If they are all already installed, there is nothing to choose or install.
  local all_installed=1
  for line in "${IDES[@]}"; do
    ide_installed "$line" || { all_installed=0; break; }
  done
  if [ "$all_installed" -eq 1 ]; then
    ok "all IDEs are already installed"
    return 0
  fi

  if [ -n "$IDE_CHOICE" ]; then
    if [ "$IDE_CHOICE" != none ]; then
      IFS=, read -ra keys <<<"$IDE_CHOICE"
      for key in "${keys[@]}"; do picked+=("$(ide_by_key "$key")"); done
    fi
  elif [ "$ASSUME_YES" -eq 1 ]; then
    picked=("${IDES[0]}")
  else
    info "Which IDE to install? (numbers separated by commas or spaces)"
    n=1
    for line in "${IDES[@]}"; do
      tag=""
      ide_installed "$line" && tag=" (installed)"
      printf '      %d) %-8s %s%s\n' "$n" "$(ide_field "$line" 1)" "$(ide_field "$line" 2)" "$tag"
      n=$((n+1))
    done
    printf '      0) none\n'
    read -rp "    Choice [enter = 0] " reply </dev/tty || reply=""
    IFS=', ' read -ra nums <<<"$reply"
    for n in "${nums[@]}"; do
      case "$n" in
        0) picked=(); break ;;
        ''|*[!0-9]*) warn "invalid choice: $n"; continue ;;
      esac
      if [ "$n" -ge 1 ] && [ "$n" -le "${#IDES[@]}" ]; then
        picked+=("${IDES[$((n-1))]}")
      else
        warn "out of range: $n"
      fi
    done
  fi

  if [ ${#picked[@]} -eq 0 ]; then
    info "no IDE to install"
    return 0
  fi
  for line in "${picked[@]}"; do
    read -ra pkgs <<<"$(ide_field "$line" 3)"
    IDE_PKGS+=("${pkgs[@]}")
    ok "IDE: $(ide_field "$line" 2)"
  done
}

# Make + name from the DRM connector's EDID (e.g. "ACR XB270HU").
monitor_edid_label() {
  local edid="$1/edid" out make name model
  [ -r "$edid" ] || { printf 'unknown'; return; }
  [ "$(wc -c < "$edid" 2>/dev/null || echo 0)" -ge 128 ] || { printf 'unknown'; return; }

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

  # Fallback without edid-decode: PNP manufacturer + 0xFC descriptor.
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$edid" <<'PY' 2>/dev/null && return
import sys
b = open(sys.argv[1], "rb").read(128)
if len(b) < 128:
    print("unknown"); raise SystemExit
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
  printf 'EDID present'
}

detect_monitors() {  # prints "CONNECTOR<TAB>make name"
  local st dir conn desc
  # Prefer /sys+EDID: it also works outside niri and shows readable make/model
  # (ARZOPA, XB270HU…), not just DP-1 / DP-6.
  for st in /sys/class/drm/card*-*/status; do
    [ -r "$st" ] || continue
    [ "$(cat "$st")" = connected ] || continue
    dir=$(dirname "$st")
    conn=$(basename "$dir" | sed -E 's/^card[0-9]+-//')
    desc=$(monitor_edid_label "$dir")
    case "$conn" in
      eDP-*) desc="$desc (internal panel)" ;;
    esac
    printf '%s\t%s\n' "$conn" "$desc"
  done
}

# Already configured primary: the connector in [notification] of the file this
# script generates. Prints nothing if the file is missing or does not contain it.
current_primary() {  # current_primary FILE
  [ -r "$1" ] || return 0
  sed -n '/^\[notification\]/,/^\[/s/^monitors = \[ *"\([^"]*\)".*/\1/p' "$1" | head -1
}

# Area of a screen, to pick the largest. "cm": physical area from EDID
# (bytes 21 and 22, in cm); "px": pixel area of the preferred mode. 0 if unknown.
monitor_area() {  # monitor_area cm|px CONNECTOR
  local d dir="" w=0 h=0 mode
  for d in /sys/class/drm/card*-"$2"; do
    [ -e "$d" ] && dir=$d
    break
  done
  [ -n "$dir" ] || { echo 0; return; }
  if [ "$1" = cm ]; then
    if [ -r "$dir/edid" ] && [ "$(wc -c < "$dir/edid")" -ge 128 ]; then
      w=$(od -An -tu1 -j21 -N1 "$dir/edid" | tr -d ' ')
      h=$(od -An -tu1 -j22 -N1 "$dir/edid" | tr -d ' ')
    fi
  else
    mode=$(head -1 "$dir/modes" 2>/dev/null || true)
    case "$mode" in
      *x*) w=${mode%%x*}; h=${mode#*x}; h=${h%%[!0-9]*} ;;
    esac
  fi
  echo $(( ${w:-0} * ${h:-0} ))
}

# Index (from 1) of the largest monitor in mons: by physical area if all of
# them report it in the EDID, otherwise by pixels. On a tie the first wins.
largest_monitor() {
  local kind=cm m a i=1 best=1 best_area=-1
  for m in "${mons[@]}"; do
    [ "$(monitor_area cm "${m%%$'\t'*}")" -gt 0 ] || kind=px
  done
  for m in "${mons[@]}"; do
    a=$(monitor_area "$kind" "${m%%$'\t'*}")
    if [ "$a" -gt "$best_area" ]; then best=$i; best_area=$a; fi
    i=$((i+1))
  done
  echo "$best"
}

configure_monitors() {
  local target="$HOME/.config/noctalia/90-monitors.local.toml"
  mapfile -t mons < <(detect_monitors)
  if [ ${#mons[@]} -eq 0 ]; then
    warn "no monitor detected, skipping the bar configuration"
    return
  fi

  # Default on enter: the already configured primary, if it is still connected;
  # otherwise the largest monitor.
  local current default=0 from_current=0 i=1 note
  current=$(current_primary "$target")
  if [ -n "$current" ]; then
    for m in "${mons[@]}"; do
      [ "${m%%$'\t'*}" = "$current" ] && default=$i
      i=$((i+1))
    done
    if [ "$default" -gt 0 ]; then
      from_current=1
    else
      warn "the saved primary ($current) is not connected"
    fi
  fi
  [ "$default" -gt 0 ] || default=$(largest_monitor)

  info "Detected monitors:"
  i=1
  for m in "${mons[@]}"; do
    note=""
    if [ "$i" -eq "$default" ]; then
      if [ "$from_current" -eq 1 ]; then note=" (current primary)"; else note=" (the largest)"; fi
    fi
    printf '      %d) %-12s %s%s\n' "$i" "${m%%$'\t'*}" "${m#*$'\t'}" "$note"
    i=$((i+1))
  done

  local choice=$default
  if [ "$ASSUME_YES" -eq 0 ]; then
    read -rp "    Which is the main monitor? [1-${#mons[@]}, enter = $default] " choice </dev/tty || choice=$default
    [ -n "$choice" ] || choice=$default
  fi
  case "$choice" in
    ''|*[!0-9]*) warn "invalid choice, using $default"; choice=$default ;;
  esac
  [ "$choice" -ge 1 ] && [ "$choice" -le ${#mons[@]} ] || { warn "out of range, using $default"; choice=$default; }

  local primary
  primary="${mons[$((choice-1))]%%$'\t'*}"
  ok "main: $primary (fixed bar; auto-hide on the others)"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo -e "    ${DIM}\$ writing $target${RESET}"
    return
  fi

  mkdir -p "$(dirname "$target")"
  {
    echo "# Generated by setup-machine.sh: depends on the monitors of THIS machine."
    echo "# Not in the dotfiles. Re-run the script to regenerate it."
    echo
    echo "[notification]"
    echo "monitors = [ \"$primary\" ]"
    echo
    echo "[osd]"
    echo "monitors = [ \"$primary\" ]"
    echo
    echo "[dock.monitor.$primary]"
    echo "enabled = true"
    for m in "${mons[@]}"; do
      local conn="${m%%$'\t'*}"
      [ "$conn" = "$primary" ] && continue
      echo
      # Dock on the other screens: hidden until you move the pointer to the
      # edge (no "smart" mode, which would show it on every empty screen).
      echo "[dock.monitor.$conn]"
      echo "enabled = true"
      echo "auto_hide = true"
      echo "smart_auto_hide = false"
      echo
      # Key = connector name, as the noctalia UI does: with a different key
      # + match, the settings show every monitor twice.
      echo "[bar.default.monitor.$conn]"
      echo "auto_hide = true"
      echo "reserve_space = false"
    done
  } > "$target"
  ok "wrote $target"

  if command -v noctalia >/dev/null 2>&1; then
    noctalia config validate >/dev/null 2>&1 && ok "noctalia configuration valid" \
      || warn "noctalia reports problems: check with 'noctalia config validate'"
  fi
}

# Personal noctalia settings that hold absolute paths (the single terminal for
# the updates widget, optionally avatar and wallpaper): they depend on the home
# of whoever runs this, so they live in a local file outside the repo.
configure_user_settings() {
  local target="$HOME/.config/noctalia/91-user.local.toml"
  if [ -e "$target" ]; then
    return
  fi
  info "creating $target"
  if [ "$DRY_RUN" -eq 1 ]; then
    return
  fi
  cat > "$target" <<EOF2
# Personal settings of this user/machine. Not in the dotfiles: the paths
# depend on the home. See 91-user.local.toml.example for what else can go here.

[plugin_settings."yuuto/arch-updater"]
terminal = "$HOME/.config/niri/terminal.sh run"
EOF2
}

configure_nautilus_terminal() {
  local schema=com.github.stunkymonkey.nautilus-open-any-terminal
  local cmd="$HOME/.config/niri/terminal.sh cwd"
  if ! gsettings list-schemas 2>/dev/null | grep -qx "$schema"; then
    warn "nautilus-open-any-terminal not installed, skipping"
    return
  fi
  info "linking \"Open in Terminal\" to the single-terminal script"
  run gsettings set "$schema" terminal custom
  run gsettings set "$schema" custom-local-command "$cmd"
  run gsettings set "$schema" new-tab false
}

install_qogir() {
  # The icon and cursor theme that configure_gtk_interface then selects. It is
  # not in a package list because the name depends on the distribution:
  # EndeavourOS has eos-qogir-icons in its own repo, plain Arch only the AUR
  # build. They install the same paths, so whichever is already there wins and
  # nothing else is touched.
  if [ -d /usr/share/icons/Qogir-Dark ]; then
    ok "Qogir already installed"
    return
  fi
  local pkg=qogir-icon-theme
  if pacman -Si eos-qogir-icons >/dev/null 2>&1; then
    pkg=eos-qogir-icons
  fi
  info "icon and cursor theme: $pkg"
  run "$HELPER" -S --needed --noconfirm "$pkg"
}

configure_php_extensions() {
  local src="$REPO_DIR/scripts/php-conf.d"
  local dst=/etc/php/conf.d
  command -v php >/dev/null || { info "php not installed, skipping"; return; }
  [ -d "$src" ] || { warn "$src missing, skipping"; return; }
  # The extensions Arch builds into the php package do not switch themselves
  # on: the package ships the module but not the file that loads it. Without a
  # line in conf.d they stay off, and a fresh machine would install the whole
  # php group and find itself without gd, intl, pdo_pgsql and the rest.
  #
  # Only the ones nobody owns: imagick, redis, yaml, igbinary, xdebug, ibm_db2
  # and oci8 carry their own file in their package.
  local f name
  for f in "$src"/*.ini; do
    [ -e "$f" ] || continue
    name=$(basename "$f")
    if cmp -s "$f" "$dst/$name"; then
      continue
    fi
    info "enabling ${name%.ini}"
    run sudo install -Dm644 "$f" "$dst/$name"
  done
}

configure_tidal() {
  local src="$REPO_DIR/scripts/tidal-hifi/config.json"
  local dst="$HOME/.config/tidal-hifi/config.json"
  [ -f "$src" ] || { warn "$src missing, skipping"; return; }
  # These settings cannot be stowed: tidal-hifi saves through electron-store,
  # which writes a temporary file and renames it over the target, and a rename
  # replaces a symlink with a real file. The link would break at the first
  # settings change, silently. So the template is copied, and only onto a
  # machine that has none: an existing file is the user's own and stays.
  if [ -e "$dst" ]; then
    ok "tidal-hifi already configured"
    return
  fi
  info "tidal-hifi settings"
  run install -Dm644 "$src" "$dst"
}

configure_corne_usb_rescan() {
  local dir="$REPO_DIR/scripts/corne-usb-rescan"
  local xhci=0000:00:14.0
  [ -d "$dir" ] || { warn "$dir missing, skipping"; return; }
  # Only on the machine that has that controller: elsewhere the service would
  # be dead weight. See the README next to the script for the why.
  if [ ! -e "/sys/bus/pci/devices/$xhci" ]; then
    return
  fi
  if ! cmp -s "$dir/corne-usb-rescan.sh" /usr/local/bin/corne-usb-rescan; then
    info "keyboard rescan script"
    run sudo install -Dm755 "$dir/corne-usb-rescan.sh" /usr/local/bin/corne-usb-rescan
  fi
  if ! cmp -s "$dir/corne-usb-rescan.service" /etc/systemd/system/corne-usb-rescan.service; then
    info "keyboard rescan unit"
    run sudo install -Dm644 "$dir/corne-usb-rescan.service" /etc/systemd/system/corne-usb-rescan.service
    run sudo systemctl daemon-reload
  fi
  if systemctl is-enabled --quiet corne-usb-rescan.service 2>/dev/null; then
    ok "corne-usb-rescan already enabled"
  else
    run sudo systemctl enable corne-usb-rescan.service
  fi
}

configure_gtk_interface() {
  local schema=org.gnome.desktop.interface
  if ! gsettings list-schemas 2>/dev/null | grep -qx "$schema"; then
    warn "schema $schema missing, skipping"
    return
  fi
  # Nothing here sets these: on this machine they survive from the GNOME
  # session, and a fresh install would not get them. Verified that noctalia
  # does not fill the gap: with sync_color_scheme = true and the theme
  # reapplied, color-scheme stayed on "default".
  #
  # It matters beyond GTK. The Qt and KDE palettes in the qt/ stow package
  # name Adwaita Sans and Qogir-Dark outright, so without these the Qt
  # windows would be the only ones with the right font.
  #
  # Qogir is not a given: icons and cursors come from eos-qogir-icons, which
  # lives in the endeavouros repo and on plain Arch does not exist. Where it
  # is missing, fall back to Adwaita rather than naming a theme that is not
  # there, which would leave the applications with no icons at all.
  local icons=Qogir-Dark cursors=Qogir
  [ -d /usr/share/icons/Qogir-Dark ] || { icons=Adwaita; warn "Qogir missing (eos-qogir-icons), icons stay on Adwaita"; }
  [ -d /usr/share/icons/Qogir ] || cursors=Adwaita
  info "dark theme, fonts and icons for the GTK applications"
  run gsettings set "$schema" color-scheme prefer-dark
  run gsettings set "$schema" gtk-theme Adwaita
  run gsettings set "$schema" icon-theme "$icons"
  run gsettings set "$schema" cursor-theme "$cursors"
  run gsettings set "$schema" cursor-size 24
  run gsettings set "$schema" font-name "Adwaita Sans 9"
  run gsettings set "$schema" document-font-name "Adwaita Sans 9"
  run gsettings set "$schema" monospace-font-name "AdwaitaMono Nerd Font 8"
}

# Turtle keeps its settings in dconf, not in a file, so they cannot live in
# the dotfiles: they are applied here. Only the values that differ from the
# defaults.
configure_turtle() {
  local schema=de.philippun1.turtle
  if ! gsettings list-schemas 2>/dev/null | grep -qx "$schema"; then
    warn "turtle not installed, skipping"
    return
  fi
  info "turtle: git menu and emblems only inside repos, status emblem on"
  run gsettings set "$schema" enable-everywhere false
  run gsettings set "$schema" restrict-to-home false
  run gsettings set "$schema" show-compare false
  run gsettings set "$schema" show-status-emblem true
  run gsettings set "$schema" show-turtle-emblem false
  run gsettings set "$schema" commit-show-ignored true
}

configure_nm_applet() {
  local schema=org.gnome.nm-applet
  if ! gsettings list-schemas 2>/dev/null | grep -qx "$schema"; then
    warn "nm-applet not installed, skipping"
    return
  fi
  # nm-applet stays because it acts as the agent for wifi and vpn passwords,
  # but its connected and disconnected notifications are noise: the noctalia
  # bar already shows the state, and those would pile up in the notification
  # drawer. The vpn ones are kept, since those are useful.
  info "silencing nm-applet on connected and disconnected"
  run gsettings set "$schema" disable-connected-notifications true
  run gsettings set "$schema" disable-disconnected-notifications true
}

# Name of the display manager enabled right now (gdm, sddm, greetd...), empty
# if there is none: it is the target of the display-manager.service alias.
current_display_manager() {
  local target
  target=$(readlink /etc/systemd/system/display-manager.service 2>/dev/null) || return 0
  target=${target##*/}
  printf '%s' "${target%.service}"
}

# greetd does not unlock the gnome-keyring by itself: without these two PAM
# lines the keyring asks for its password again after every login. Idempotent;
# the file is backed up before the first change.
configure_greetd_keyring() {
  local pam=/etc/pam.d/greetd
  [ -f "$pam" ] || return
  if [ ! -e /usr/lib/security/pam_gnome_keyring.so ]; then
    warn "pam_gnome_keyring.so missing (install gnome-keyring), skipping keyring unlock"
    return
  fi
  grep -q pam_gnome_keyring "$pam" && { info "greetd already unlocks the keyring"; return; }
  info "unlocking the gnome-keyring at login (greetd PAM)"
  run sudo cp -n "$pam" "$pam.bak-setup"
  run sudo sed -i '/^auth .*include.*system-local-login/a auth       optional     pam_gnome_keyring.so' "$pam"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] append session line to $pam"
  else
    echo 'session    optional     pam_gnome_keyring.so auto_start' | sudo tee -a "$pam" >/dev/null
  fi
}

# Disable the faillock lockout (default: 3 failed attempts lock the account
# for 10 minutes, even for the right password). Chosen on purpose: deny = 0.
configure_faillock() {
  local conf=/etc/security/faillock.conf
  [ -f "$conf" ] || return
  grep -qE '^deny\s*=\s*0\s*$' "$conf" && { info "faillock lockout already disabled"; return; }
  info "disabling the faillock lockout (deny = 0)"
  run sudo cp -n "$conf" "$conf.bak-setup"
  run sudo sed -i -E 's/^#?\s*deny\s*=.*/deny = 0/' "$conf"
}

# earlyoom: never kill the desktop itself, prefer the usual memory hogs.
# Without this the kernel killed app-niri-sh.scope (niri, noctalia and every
# app in the session) when RAM and swap ran out.
configure_earlyoom() {
  local conf=/etc/default/earlyoom
  command -v earlyoom >/dev/null || { info "earlyoom not installed, skipping"; return; }
  grep -q noctalia "$conf" 2>/dev/null && { info "earlyoom already configured"; return; }
  info "configuring earlyoom (protect niri/noctalia, prefer php/electron)"
  [ -f "$conf" ] && run sudo cp -n "$conf" "$conf.bak-setup"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] write $conf"
  else
    printf '%s\n' "EARLYOOM_ARGS=\"-r 3600 --avoid '(^|/)(niri|noctalia|xwayland-satellite|greetd|systemd)\$' --prefer '(^|/)(php|electron|node)\$'\"" | sudo tee "$conf" >/dev/null
  fi
}

# Login screen: greetd with noctalia-greeter. Changing display manager can
# leave the machine without a graphical login, so:
#  - nothing happens unless greetd and the greeter are installed;
#  - another display manager (gdm...) is replaced only after an explicit
#    confirmation, never with --yes, and only from the next boot (no --now);
#  - /etc/greetd/config.toml is backed up before being touched.
configure_login_manager() {
  local session=${GREETER_SESSION:-/usr/bin/noctalia-greeter-session}
  local conf=/etc/greetd/config.toml
  if ! pacman -Qq greetd >/dev/null 2>&1 || [ ! -x "$session" ]; then
    warn "greetd / noctalia-greeter not installed, skipping the login screen"
    return
  fi

  local current
  current=$(current_display_manager)
  if [ -n "$current" ] && [ "$current" != greetd ]; then
    if [ "$ASSUME_YES" -eq 1 ]; then
      warn "$current is the login manager: not replaced with --yes"
      warn "rerun without --yes, keeping a TTY open, to switch to greetd"
      return
    fi
    info "$current is the current login manager; greetd would replace it at the next boot"
    info "if greetd fails to start there is no graphical login: keep a TTY (Ctrl+Alt+F3) available"
    ask "Switch the login manager from $current to greetd?" || { warn "login manager left as it is"; return; }
  fi

  info "pointing greetd at noctalia-greeter-session"
  if [ -f "$conf" ] && ! grep -q "^command = \"$session\"" "$conf"; then
    run sudo cp -n "$conf" "$conf.bak-setup"
  fi
  if [ ! -f "$conf" ]; then
    run sudo install -d /etc/greetd
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "  [dry-run] write $conf"
    else
      printf '[terminal]\nvt = 1\n\n[default_session]\ncommand = "%s"\nuser = "greeter"\n' "$session" \
        | sudo tee "$conf" >/dev/null
    fi
  else
    # only the command line of [default_session]: the rest stays untouched
    run sudo sed -i "/^\[default_session\]/,/^\[/ s|^command = .*|command = \"$session\"|" "$conf"
  fi
  run sudo noctalia-greeter-apply-appearance --setup-system
  configure_greetd_keyring

  if [ -n "$current" ] && [ "$current" != greetd ]; then
    run sudo systemctl disable "$current.service"
  fi
  if systemctl is-enabled --quiet greetd 2>/dev/null; then
    info "greetd already enabled"
  else
    run sudo systemctl enable greetd.service
  fi
}

# Packages preinstalled by EndeavourOS that are not needed under niri. Listed
# in scripts/remove.txt; here only those actually present are removed.
remove_packages() {
  [ -f "$REMOVE_LIST" ] || { info "no removal list"; return; }
  local to_remove=()
  local pkg
  local dm
  dm=$(current_display_manager)
  while IFS= read -r pkg; do
    pacman -Qq "$pkg" >/dev/null 2>&1 || continue
    # never remove the display manager still in use: without a replacement
    # there would be no graphical login at the next boot
    if [ -n "$dm" ] && [ "$pkg" = "$dm" ]; then
      warn "keeping $pkg: it is still the login manager (switch to greetd first)"
      continue
    fi
    # gdm needs gnome-shell: removing it alone would abort the whole transaction
    if [ "$dm" = gdm ] && [ "$pkg" = gnome-shell ]; then
      warn "keeping gnome-shell: gdm still depends on it"
      continue
    fi
    to_remove+=("$pkg")
  done < <(packages_of "$REMOVE_LIST")

  if [ ${#to_remove[@]} -eq 0 ]; then
    ok "nothing to remove"
    return
  fi

  info "to remove: ${to_remove[*]}"
  if ! ask "Remove them?"; then
    warn "skipping the removal"
    return
  fi
  # -Rns also removes dependencies left orphaned. --noconfirm only because
  # we already asked the question ourselves above.
  run sudo pacman -Rns --noconfirm "${to_remove[@]}"
}

configure_wifi_powersave() {
  if ! command -v NetworkManager >/dev/null 2>&1; then
    info "NetworkManager not installed, skipping"
    return
  fi
  # Wifi power saving puts the radio to sleep between packets: erratic
  # latency, ssh sessions that hang, crackling calls. On a laptop that is
  # always plugged in it is not needed. 2 = disabled (0 is the driver
  # default, 3 enables it).
  info "disabling wifi power saving"
  run sudo mkdir -p /etc/NetworkManager/conf.d
  if [ "$DRY_RUN" -eq 1 ]; then
    echo -e "    ${DIM}\$ writing /etc/NetworkManager/conf.d/wifi-powersave.conf${RESET}"
  else
    sudo tee /etc/NetworkManager/conf.d/wifi-powersave.conf >/dev/null <<'NMCONF'
[connection]
wifi.powersave = 2
NMCONF
  fi
  run sudo systemctl reload NetworkManager
}

configure_root_theme() {
  # Graphical programs that elevate to root read the preferences in /root,
  # not yours: with nothing in there GTK falls back to the stock light theme.
  # Two lines are enough to give root a dark theme of its own.
  info "dark theme for programs launched as root"
  run sudo mkdir -p /root/.config/gtk-3.0
  if [ "$DRY_RUN" -eq 1 ]; then
    echo -e "    ${DIM}\$ writing /root/.config/gtk-3.0/settings.ini${RESET}"
  else
    sudo tee /root/.config/gtk-3.0/settings.ini >/dev/null <<'GTK'
[Settings]
gtk-theme-name=Adwaita
gtk-application-prefer-dark-theme=1
GTK
  fi
}

configure_firefox_theme() {
  if ! command -v noctalia >/dev/null 2>&1; then
    warn "noctalia not installed, skipping the Firefox theme"
    return
  fi
  # Firefox does not read colors from GTK: with the system theme it uses the
  # desktop portal accent, which only accepts the libadwaita presets. The only
  # way to get the noctalia accent is the Pywalfox route, for which noctalia
  # itself acts as the native host.
  info "installing the Pywalfox native host and applying the templates"
  run noctalia firefox-theme install
  run noctalia msg templates-apply
}

setup_shell() {
  local zsh=/usr/bin/zsh
  [ -x "$zsh" ] || { warn "zsh not installed, skipping"; return; }
  if [ "$(getent passwd "$USER" | cut -d: -f7)" = "$zsh" ]; then
    ok "zsh is already the default shell"
    return
  fi
  info "setting zsh as the default shell"
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
      printf '\n  IDE (chosen with the dev-* groups, or with --ide):\n'
      for line in "${IDES[@]}"; do
        printf '  %-16s %s — %s\n' "$(ide_field "$line" 1)" "$(ide_field "$line" 2)" "$(ide_field "$line" 3)"
      done
      exit 0 ;;
    --help|-h)    usage ;;
    *)            die "unknown option: $1 (--help for usage)" ;;
  esac
  shift
done

[ -d "$PKG_DIR" ] || die "lists folder not found: $PKG_DIR"
command -v pacman >/dev/null || die "this script works on Arch / EndeavourOS"
[ "$(id -u)" -ne 0 ] || die "do not run it as root: use your own user, it will ask for sudo when needed"

if [ -n "$IDE_CHOICE" ] && [ "$IDE_CHOICE" != none ]; then
  IFS=, read -ra _keys <<<"$IDE_CHOICE"
  for _k in "${_keys[@]}"; do
    ide_by_key "$_k" >/dev/null || die "unknown IDE: '$_k' (available: $(for _l in "${IDES[@]}"; do printf '%s ' "$(ide_field "$_l" 1)"; done)or none)"
  done
fi

section "AUR helper"
if command -v paru >/dev/null; then
  HELPER=paru
  ok "paru found"
elif command -v yay >/dev/null; then
  HELPER=yay
  ok "yay found"
else
  info "no AUR helper: building paru from source"
  run sudo pacman -S --needed --noconfirm base-devel git
  tmp=$(mktemp -d)
  run git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
  run bash -c "cd '$tmp/paru-bin' && makepkg -si --noconfirm"
  run rm -rf "$tmp"
  HELPER=paru
fi

section "Packages"
selected=()
for f in "$PKG_DIR"/*.txt; do
  g=$(group_name "$f")
  # NVIDIA: ask/install only if the card is present (even with --yes/--only).
  if [ "$g" = nvidia ] && ! has_nvidia_gpu; then
    ok "nvidia: no NVIDIA GPU detected, skipping"
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
  if ask "$(group_label "$g") — $(pkg_summary "$f"). Install?"; then
    selected+=("$f")
  fi
done

[ ${#selected[@]} -gt 0 ] || die "no group selected"

select_ide

for f in "${selected[@]}"; do
  g=$(group_name "$f")
  mapfile -t pkgs < <(missing_of "$f")
  if [ ${#pkgs[@]} -eq 0 ]; then
    ok "$g: nothing to install ($(pkg_summary "$f"))"
    continue
  fi
  info "${BLUE}$g${RESET}: ${#pkgs[@]} to install"
  run "$HELPER" -S --needed --noconfirm "${pkgs[@]}"
done

if [ ${#IDE_PKGS[@]} -gt 0 ]; then
  info "${BLUE}ide${RESET}: ${#IDE_PKGS[@]} packages (those already present are skipped)"
  run "$HELPER" -S --needed --noconfirm "${IDE_PKGS[@]}"
fi

section "Memory"
configure_earlyoom

if [ "$DO_SERVICES" -eq 1 ]; then
  section "Services"
  for s in "${SERVICES_SYSTEM[@]}"; do
    if ! systemctl cat "$s" >/dev/null 2>&1; then
      # no unit, no package: an expected case, not worth a line of output
      :
    elif systemctl is-enabled --quiet "$s" 2>/dev/null; then
      info "$s already enabled"
    else
      run sudo systemctl enable "$s"
    fi
  done
  for s in "${SERVICES_USER[@]}"; do
    if ! systemctl --user cat "$s" >/dev/null 2>&1; then
      :
    elif systemctl --user is-enabled --quiet "$s" 2>/dev/null; then
      info "$s (user) already enabled"
    else
      run systemctl --user enable "$s"
    fi
  done
fi

if [ "$DO_STOW" -eq 1 ]; then
  section "Dotfiles (stow)"
  command -v stow >/dev/null || die "stow not installed: run the base group first"
  cd "$REPO_DIR"
  for d in */; do
    p="${d%/}"
    case " $STOW_SKIP " in *" $p "*) continue ;; esac
    [ -d "$p" ] || continue
    # cursor/ only holds the orphaned cursor-agent reaper: pointless without
    # Cursor. Not stowed means no unit, so the Services loop skips the timer too.
    if [ "$p" = cursor ] && ! command -v cursor >/dev/null; then
      info "Cursor not installed: skipping stow cursor"
      continue
    fi
    info "stow $p"
    # set -e would stop the whole script: a conflict on one package must not
    # cancel the following stows nor the later sections (shell, monitors…).
    # Stow's "All operations aborted" only concerns that package, not the previous ones.
    if [ "$DRY_RUN" -eq 1 ]; then
      run stow --restow "$p"
    elif stow --restow "$p"; then
      :
    else
      warn "stow $p failed (conflicts or files already present): continuing with the others"
    fi
  done

  # config.kdl includes monitor.kdl, which nwg-displays writes and the repo
  # ignores because it depends on this machine's screens. Without the file the
  # include fails and niri refuses the whole config, so create an empty one.
  mon="$REPO_DIR/niri/.config/niri/monitor.kdl"
  if [ ! -f "$mon" ]; then
    info "creating an empty monitor.kdl (nwg-displays will fill it)"
    if [ "$DRY_RUN" -eq 0 ]; then
      printf '%s\n' "// Layout written by nwg-displays. Empty: niri auto-places the outputs." > "$mon"
      stow --restow niri >/dev/null 2>&1 || true
    fi
  fi

  # config.kdl also includes outputs.local.kdl (hand-written tweaks, ignored by
  # git, see outputs.local.kdl.example): same reason, create an empty one.
  loc="$REPO_DIR/niri/.config/niri/outputs.local.kdl"
  if [ ! -f "$loc" ]; then
    info "creating an empty outputs.local.kdl"
    if [ "$DRY_RUN" -eq 0 ]; then
      printf '%s\n' "// Hand-written monitor tweaks of this machine. See outputs.local.kdl.example." > "$loc"
      stow --restow niri >/dev/null 2>&1 || true
    fi
  fi

  # qt6ct wants an absolute path to the color file and expands neither ~ nor
  # $HOME: the one in the repo is written for this machine. Realign it to the
  # home of whoever is running, so the Qt apps are not left without a palette.
  qtc="$REPO_DIR/qt/.config/qt6ct/qt6ct.conf"
  if [ -f "$qtc" ] && ! grep -q "^color_scheme_path=$HOME/" "$qtc"; then
    info "pointing qt6ct.conf at $HOME"
    run sed -i "s|^color_scheme_path=.*/\.config/qt6ct/|color_scheme_path=$HOME/.config/qt6ct/|" "$qtc"
  fi

  # starship reads a single file: ~/.config/starship.toml is built from the
  # prompt structure (stowed) plus a palette (generated by noctalia when it
  # runs, otherwise the default one in the dotfiles).
  builder="$REPO_DIR/noctalia/.config/noctalia/templates/starship-build.sh"
  if [ -x "$builder" ] && [ -f "$REPO_DIR/starship/.config/starship/structure.toml" ]; then
    info "building ~/.config/starship.toml"
    run sh "$builder"
  fi

  # Menu entries to hide: runtimes, qt tools, gnome panels that control
  # nothing under niri. Stow only puts in place the files the script has
  # already generated; re-running it covers entries that appeared in the
  # meantime and those that have a different name on this machine.
  hide_apps="$HOME/.local/share/applications/.hide-apps.sh"
  if [ -x "$hide_apps" ]; then
    info "hiding the useless menu entries"
    run "$hide_apps"
    run update-desktop-database "$HOME/.local/share/applications"
  fi
fi

section "Shell"
setup_shell

section "Monitors and bar"
configure_monitors
configure_user_settings

section "Nautilus"
configure_nautilus_terminal
configure_turtle

section "PHP extensions"
configure_php_extensions

section "Tidal"
configure_tidal

section "Keyboard"
configure_corne_usb_rescan

section "GTK appearance"
install_qogir
configure_gtk_interface

section "Network notifications"
configure_nm_applet

section "Login screen"
configure_login_manager
configure_faillock

section "Cleanup"
remove_packages

section "Wifi"
configure_wifi_powersave

section "Root theme"
configure_root_theme

section "Firefox theme"
configure_firefox_theme

section "Done"
cat <<'EOF'
    Still to do by hand, because they depend on choices or secrets:

      - NVIDIA Optimus:     envycontrol -s integrated|hybrid|nvidia (then reboot)
      - monitor layout:     nwg-displays (the script has already configured the bar)
      - noctalia:           the settings tied to this machine (monitors,
                            lock screen, wallpapers) live in
                            ~/.local/state/noctalia/settings.toml and are not in the repo
      - SSH and GPG keys:   restore them from your backup
      - Firefox:            install the Pywalfox extension from addons.mozilla.org
                            and press "Fetch pywal colors" once
EOF
