#!/usr/bin/env bash
# Stow-safe Niri + Noctalia installer for Arch / EndeavourOS.
# Does NOT wipe ~/.config and does NOT replace GNOME.
#
# Usage (from repo root):
#   ./install-niri.sh
#   ./install-niri.sh --no-update

set -euo pipefail

RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
RESET="\033[0m"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DO_UPDATE=1

section() {
  echo -e "\n${CYAN}================================${RESET}"
  echo -e "${BLUE}$1${RESET}"
  echo -e "${CYAN}================================${RESET}\n"
}

info() { echo -e "${BLUE}➜${RESET} $1"; }
success() { echo -e "${GREEN}✔${RESET} $1"; }
warn() { echo -e "${YELLOW}⚠${RESET} $1"; }
error() { echo -e "${RED}✖${RESET} $1"; }

usage() {
  cat <<'EOF'
Usage: ./install-niri.sh [--no-update] [--help]

  --no-update   Skip pacman -Syu
  --help        Show this help
EOF
}

for arg in "$@"; do
  case "$arg" in
    --no-update) DO_UPDATE=0 ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      error "Unknown argument: $arg"
      usage
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
section "Niri + Noctalia installer (stow-safe)"

echo -e "${YELLOW}"
cat <<'EOF'
This installer will:
  • update the system (unless --no-update)
  • install Niri / Wayland / portal / utility packages
  • install AUR packages: noctalia-qs, noctalia-shell
  • remove upstream quickshell / quickshell-git if present
    (they conflict with noctalia-qs — Noctalia's required fork)
  • stow kitty (and niri if that package exists in this repo)

This installer will NOT:
  • remove or replace GNOME
  • rm -rf ~/.config or overwrite stowed configs blindly
  • install Dolphin, Ark, Breeze, Bibata, JetBrains Mono, or fish
  • replace your Neovim / zsh / tmux / starship setup
  • replace your GNOME icon/cursor themes (keep Qogir / Qogir-Dark)
  • install official Arch quickshell (incompatible with Noctalia ≥ 4.6)

File manager in Niri should stay Nautilus for now.
EOF
echo -e "${RESET}"

read -r -p "Continue? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Aborted."
  exit 1
fi

if [[ ! -f /etc/arch-release ]] && ! grep -qi 'arch\|endeavouros' /etc/os-release 2>/dev/null; then
  warn "This script targets Arch / EndeavourOS. Continuing anyway..."
fi

if ! command -v pacman >/dev/null 2>&1; then
  error "pacman not found"
  exit 1
fi

if ! command -v stow >/dev/null 2>&1; then
  error "stow not found. Install with: sudo pacman -S stow"
  exit 1
fi

# ---------------------------------------------------------------------------
if (( DO_UPDATE == 1 )); then
  section "Updating system"
  sudo pacman -Syu --noconfirm
  success "System updated"
else
  warn "Skipping system update (--no-update)"
fi

# ---------------------------------------------------------------------------
section "Installing pacman packages"

# Intentionally excluded: dolphin, ark, breeze*, kde-cli-tools, polkit-kde-agent,
# bibata-cursor-theme, ttf-jetbrains-mono, fish, neovim overwrite, qt KDE stack.
# Cursor/icons: keep the existing GNOME setup (Qogir / Qogir-Dark).
PACMAN_PKGS=(
  niri
  xwayland-satellite
  wl-clipboard
  xdg-desktop-portal
  xdg-desktop-portal-gtk
  xdg-desktop-portal-wlr
  swaybg
  swayidle
  brightnessctl
  grim
  slurp
  jq
  pipewire
  pipewire-alsa
  pipewire-pulse
  pipewire-jack
  wireplumber
  kitty
  polkit
  polkit-gnome
)

sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
success "Pacman packages installed (or already present)"

# ---------------------------------------------------------------------------
section "Checking AUR helper"

AUR_HELPER=""
if command -v paru >/dev/null 2>&1; then
  AUR_HELPER="paru"
  success "Using paru"
elif command -v yay >/dev/null 2>&1; then
  AUR_HELPER="yay"
  success "Using yay (paru not found)"
else
  warn "No AUR helper found. Installing yay from AUR as fallback..."
  tmp_dir="$(mktemp -d)"
  git clone https://aur.archlinux.org/yay.git "$tmp_dir/yay"
  (
    cd "$tmp_dir/yay"
    makepkg -si --noconfirm
  )
  rm -rf "$tmp_dir"
  AUR_HELPER="yay"
  success "yay installed"
fi

# ---------------------------------------------------------------------------
section "Resolving Quickshell / Noctalia conflicts"

# Noctalia ≥ 4.6 requires noctalia-qs (fork). Official quickshell packages
# conflict with it and must not be installed alongside noctalia-shell.
remove_conflicting_quickshell() {
  local pkg="$1"
  # pacman -Q matches Provides, so noctalia-qs answers as "quickshell".
  # Only remove when the real installed package name matches.
  local installed
  installed="$(pacman -Qq "$pkg" 2>/dev/null || true)"
  if [[ "$installed" != "$pkg" ]]; then
    return 0
  fi
  warn "Removing conflicting package: $pkg"
  sudo pacman -Rdd --noconfirm "$pkg"
  success "Removed $pkg"
}

remove_conflicting_quickshell quickshell
remove_conflicting_quickshell quickshell-git

# ---------------------------------------------------------------------------
section "Installing AUR packages"

# noctalia-shell pulls noctalia-qs; list both explicitly for clarity.
# Never install Arch extra/quickshell here.
"$AUR_HELPER" -S --needed --noconfirm noctalia-qs noctalia-shell
success "AUR packages installed via $AUR_HELPER (or already present)"

if ! pacman -Q noctalia-qs >/dev/null 2>&1; then
  error "noctalia-qs is not installed — Noctalia cannot run without it"
  exit 1
fi
if [[ "$(pacman -Qq quickshell 2>/dev/null || true)" == "quickshell" ]] \
  || [[ "$(pacman -Qq quickshell-git 2>/dev/null || true)" == "quickshell-git" ]]; then
  error "Upstream quickshell is still present and conflicts with noctalia-qs"
  exit 1
fi
if ! command -v qs >/dev/null 2>&1; then
  error "qs binary not found after installing noctalia-qs"
  exit 1
fi
success "Runtime OK: noctalia-qs provides qs ($(pacman -Q noctalia-qs))"

# ---------------------------------------------------------------------------
section "Stowing configs from this repo"

cd "$REPO_DIR"

stow_if_present() {
  local pkg="$1"
  if [[ -d "$REPO_DIR/$pkg" ]]; then
    info "stow -R $pkg"
    stow -R "$pkg"
    success "Stowed $pkg"
  else
    warn "Package '$pkg' not in repo yet — skipped"
  fi
}

# Shell stack is assumed already stowed; only ensure session-related packages.
stow_if_present kitty
stow_if_present niri

# ---------------------------------------------------------------------------
section "Installation complete"

echo -e "${GREEN}✔ Packages are ready.${RESET}\n"

echo -e "${CYAN}Next steps:${RESET}"
cat <<'EOF'
1. Log out of GNOME.
2. At the login screen, choose the Niri session (keep GNOME as fallback).
3. On first login, expect a minimal compositor until noctalia starts.
4. Edit ~/.config/niri/config.kdl after first login:
   - wallpaper (default: ~/Immagini/Firefox_wallpaper.png or solid #1c1c1e)
   - monitor: uncomment output after \`niri msg outputs\`
   - Mod+Return → kitty, Mod+E → nautilus
5. Intel GPU only: NVIDIA env vars are already omitted from this config.

Optional later:
  - Try Dolphin + Ark (+ Breeze) instead of Nautilus / File Roller
  - See README.md → "Niri notes (future)" and "Kitty notes"
EOF

echo -e "\n${BLUE}Inspiration:${RESET} https://github.com/prasangeet/endeavouros-niri"
echo -e "${GREEN}Done.${RESET}"
