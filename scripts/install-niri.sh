#!/usr/bin/env bash
# Stow-safe Niri + Noctalia installer for Arch / EndeavourOS.
# Does NOT wipe ~/.config and does NOT replace GNOME.
#
# Usage (from repo root):
#   ./scripts/install-niri.sh
#   ./scripts/install-niri.sh --no-update

set -euo pipefail

RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
RESET="\033[0m"

# Script lives in scripts/; stow packages are at the repo root.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
Usage: ./scripts/install-niri.sh [--no-update] [--help]

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
  • install Noctalia v5 from extra/noctalia (pacman, no AUR)
  • optionally remove leftover Noctalia v4 AUR packages
    (noctalia-shell, noctalia-qs, quickshell, quickshell-git)
  • stow kitty (and niri if that package exists in this repo)

This installer will NOT:
  • remove or replace GNOME
  • rm -rf ~/.config or overwrite stowed configs blindly
  • install Dolphin, Ark, Breeze, Bibata, JetBrains Mono, or fish
  • replace your Neovim / zsh / tmux / starship setup
  • replace your GNOME icon/cursor themes (keep Qogir / Qogir-Dark)
  • migrate Noctalia v4 settings automatically (v5 config is separate)

File manager in Niri should stay Nautilus for now.

This repo's niri config already targets v5 (noctalia --daemon / noctalia msg).
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
  noctalia
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
section "Cleaning leftover Noctalia v4 packages (optional)"

# v5 (extra/noctalia) is a separate native shell; v4 AUR packages are unused.
# Remove only exact package names (pacman -Q matches Provides).
remove_pkg_if_exact() {
  local pkg="$1"
  local installed
  installed="$(pacman -Qq "$pkg" 2>/dev/null || true)"
  if [[ "$installed" != "$pkg" ]]; then
    return 0
  fi
  warn "Removing leftover v4 package: $pkg"
  sudo pacman -Rdd --noconfirm "$pkg"
  success "Removed $pkg"
}

LEGACY_V4_PKGS=()
for pkg in noctalia-shell noctalia-qs quickshell quickshell-git; do
  if [[ "$(pacman -Qq "$pkg" 2>/dev/null || true)" == "$pkg" ]]; then
    LEGACY_V4_PKGS+=("$pkg")
  fi
done

if ((${#LEGACY_V4_PKGS[@]} > 0)); then
  warn "Found Noctalia v4 leftovers: ${LEGACY_V4_PKGS[*]}"
  read -r -p "Remove them? (y/N): " remove_legacy
  if [[ "$remove_legacy" == "y" || "$remove_legacy" == "Y" ]]; then
    for pkg in "${LEGACY_V4_PKGS[@]}"; do
      remove_pkg_if_exact "$pkg"
    done
  else
    warn "Keeping v4 packages (v4 and v5 can coexist; update keybinds to use one)"
  fi
else
  success "No Noctalia v4 leftovers found"
fi

# ---------------------------------------------------------------------------
section "Verifying Noctalia v5"

if ! pacman -Q noctalia >/dev/null 2>&1; then
  error "extra/noctalia is not installed"
  exit 1
fi
if ! command -v noctalia >/dev/null 2>&1; then
  error "noctalia binary not found after installing extra/noctalia"
  exit 1
fi
success "Runtime OK: $(pacman -Q noctalia) → $(command -v noctalia)"

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
3. Noctalia should autostart via noctalia --daemon (stowed niri config).
   IPC reference: https://docs.noctalia.dev/noctalia/ipc/
4. After first login, tune ~/.config/niri/config.kdl:
   - wallpaper via Noctalia settings (Mod+S) or panel Mod+Ctrl+T
   - monitor: edit outputs.local.kdl after \`niri msg outputs\`
   - Mod+Return → kitty, Mod+E → nautilus, Mod+D → launcher
5. Intel GPU only: NVIDIA env vars are already omitted from this config.

Optional later:
  - Try Dolphin + Ark (+ Breeze) instead of Nautilus / File Roller
  - See README.md → "Niri notes (future)" and "Kitty notes"
EOF

echo -e "\n${BLUE}Inspiration:${RESET} https://github.com/prasangeet/endeavouros-niri"
echo -e "${GREEN}Done.${RESET}"
