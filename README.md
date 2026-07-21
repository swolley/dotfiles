# Dotfiles

Personal configuration files managed with [GNU Stow](https://www.gnu.org/software/stow/).

Each top-level directory is a **stow package**. Stow creates symlinks from that package into `$HOME`, mirroring the directory tree inside the package.

## Structure

```text
.dotfiles/
├── gitmux/          → ~/.gitmux.conf
├── kitty/           → ~/.config/kitty/
├── niri/            → ~/.config/niri/, ~/.config/xdg-desktop-portal/
├── nvim/            → ~/.config/nvim/
├── starship/        → ~/.config/starship.toml
├── tmux/            → ~/.tmux.conf, ~/.tmux/
├── zshrc/           → ~/.zshrc, ~/.zshrc_customs.zsh
└── install-niri.sh  → Niri + Noctalia package installer (stow-safe)
```

## Prerequisites

```bash
# Arch / EndeavourOS
sudo pacman -S stow

# Debian / Ubuntu
sudo apt install stow
```

## Quick start

From this repository root (`~/.dotfiles`):

```bash
cd ~/.dotfiles

# Link a single package
stow zshrc

# Link multiple packages
stow nvim tmux starship gitmux zshrc

# Link everything (all packages in this repo)
stow */
```

Stow defaults to targeting `$HOME` when run from `~/.dotfiles`, so no `-t` flag is required in the usual setup.

## Common commands

| Action | Command |
| --- | --- |
| Link a package | `stow <package>` |
| Unlink a package | `stow -D <package>` |
| Restow (unlink + link) | `stow -R <package>` |
| Dry-run (preview only) | `stow -n -v <package>` |
| Verbose output | `stow -v <package>` |

Examples:

```bash
cd ~/.dotfiles

# Preview what nvim would link
stow -n -v nvim

# Remove zshrc symlinks
stow -D zshrc

# Relink after moving or editing package layout
stow -R tmux
```

## Adding a new config

1. Create a package directory named after the tool.
2. Mirror the path relative to `$HOME` inside that package.
3. Stow it.

Examples:

```bash
# File that lives at ~/.config/foo/config.toml
mkdir -p ~/.dotfiles/foo/.config/foo
mv ~/.config/foo/config.toml ~/.dotfiles/foo/.config/foo/
cd ~/.dotfiles && stow foo

# File that lives at ~/.barrc
mkdir -p ~/.dotfiles/bar
mv ~/.barrc ~/.dotfiles/bar/
cd ~/.dotfiles && stow bar
```

## Conflicts

If a real file already exists where Stow wants to create a symlink, Stow refuses to overwrite it.

Options:

```bash
# Move the existing file aside, then stow
mv ~/.zshrc ~/.zshrc.bak
stow zshrc

# Or adopt the existing file into the package, then restow
stow --adopt zshrc
stow -R zshrc
```

`--adopt` moves the conflicting file from `$HOME` into the package. Review the diff carefully before committing.

## Packages in this repo

| Package | Linked paths |
| --- | --- |
| `gitmux` | `~/.gitmux.conf` |
| `kitty` | `~/.config/kitty/` |
| `niri` | `~/.config/niri/`, `~/.config/xdg-desktop-portal/niri-portals.conf` |
| `nvim` | `~/.config/nvim/` |
| `starship` | `~/.config/starship.toml` |
| `tmux` | `~/.tmux.conf`, `~/.tmux/` |
| `zshrc` | `~/.zshrc`, `~/.zshrc_customs.zsh` |

## Theme notes

Prompt, tmux status, gitmux, kitty and Neovim share a **noctalia green** palette
(`#8fbf98` accent, `#1c1c1e` background). Rounded prompt / status segments use
Nerd Font glyphs; Neovim loads it via `base16-nvim` as `noctalia-green`.

## Kitty notes

`kitty.conf` sets `hide_window_decorations yes`, so on GNOME you get no title bar and no
minimize/maximize/close buttons (Mutter does not draw them). That is intentional for a
tiling compositor look. To restore the normal GNOME window chrome while testing on GNOME,
set `hide_window_decorations no` (or remove the line) and restart kitty. On niri you will
usually want decorations hidden again.

## Inspiration

Niri + Noctalia direction (and the soft green accent idea) was inspired by:

- [prasangeet/endeavouros-niri](https://github.com/prasangeet/endeavouros-niri)

This repo is **not** a fork: shell stack stays zsh/tmux/starship, configs are managed with
GNU Stow, and package/UI choices differ (e.g. Nautilus instead of Dolphin for now).

## Niri installer

Stow-safe helper for Arch / EndeavourOS (does **not** wipe `~/.config`, does **not**
replace GNOME):

```bash
cd ~/.dotfiles
./install-niri.sh           # also runs pacman -Syu
./install-niri.sh --no-update
```

What it installs:
- pacman: `niri`, `xwayland-satellite`, portals, swaybg/swayidle, grim/slurp,
  pipewire stack, `kitty`, `polkit-gnome`, …
- AUR (via `yay`): `quickshell`, `noctalia-shell`
- stow: `kitty` and `niri` (config + portals)

What it deliberately skips:
- Dolphin, Ark, Breeze / KDE Qt stack, Bibata cursors, JetBrains Mono, fish
- Blind copy of third-party nvim/fish configs
- Replacing GNOME **Qogir** cursor / **Qogir-Dark** icons (kept as-is)

## Niri notes (future)

- Cursor / icons: keep GNOME **Qogir** + **Qogir-Dark** for now (`config.kdl` sets
  `xcursor-theme "Qogir"`). Noctalia bar/dock icons can be pointed at the same theme
  later from noctalia settings (`Mod+S`) if needed.
- For now keep **Nautilus** + **File Roller** (GNOME). Do **not** install Dolphin or Ark
  with the first niri setup; `config.kdl` binds `Mod+E` to `nautilus`.
- Later optional trial: **Dolphin** + **Ark** (+ Breeze) as a more power-user file manager /
  archive stack. Worth trying if split panes, folder filters, or richer context actions are
  missing from Nautilus — then switch the niri bind from Nautilus to Dolphin.
- Stow package `niri/` is ready (pre-install). Run `./install-niri.sh` when you want packages,
  then `stow niri` (the installer does this), log into Niri, and tune monitor/wallpaper.
