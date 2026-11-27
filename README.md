# Dotfiles

Personal configuration files managed with [GNU Stow](https://www.gnu.org/software/stow/).

To use this on your own machine, read [docs/ADAPTING.md](docs/ADAPTING.md) first: it lists what is personal, what is generated per machine and what to change. Licensed under the [MIT license](LICENSE).

Each top-level directory is a **stow package**. Stow creates symlinks from that package into `$HOME`, mirroring the directory tree inside the package.

## Structure

```text
.dotfiles/
├── gitmux/          → ~/.gitmux.conf
├── code/            → ~/.config/code-flags.conf
├── cursor/          → ~/.config/systemd/user/cursor-agent-reaper.{service,timer}
├── easyeffects/     → ~/.config/easyeffects/db/, ~/.local/share/easyeffects/
├── kitty/           → ~/.config/kitty/
├── niri/            → ~/.config/niri/, ~/.config/xdg-desktop-portal/, ~/.config/xdg-terminals.list, ~/.config/autostart/easyeffects.desktop
├── noctalia/        → ~/.config/noctalia/
├── nvim/            → ~/.config/nvim/
├── ssh/             → ~/.config/environment.d/ssh-agent.conf
├── starship/        → ~/.config/starship/ (structure.toml + default palette; ~/.config/starship.toml is built from them)
├── tmux/            → ~/.tmux.conf, ~/.tmux/
├── zshrc/           → ~/.zshrc, ~/.zshrc_customs.zsh
└── scripts/         → setup-machine.sh, install-niri.sh, pkg, aur-wrap, dotfiles-updates
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

## New machine

After cloning the repo, `scripts/setup-machine.sh` installs the packages,
enables the services and applies the stows. It asks group by group, except
`base`, which it always installs.

```bash
./scripts/setup-machine.sh            # interactive
./scripts/setup-machine.sh --list     # list the groups and the IDEs
./scripts/setup-machine.sh --dry-run  # show the commands without running them
./scripts/setup-machine.sh --yes --only base,niri-noctalia,dev-php
./scripts/setup-machine.sh --yes --only dev-php --ide cursor
```

The lists live in `scripts/packages/*.txt`, one per group, one package per
line. Languages have no pinned versions: the repos always carry the latest
stable. To add software, edit the file of the right group.

The opposite exists too: `scripts/remove.txt` lists what EndeavourOS
preinstalls and what is not needed here (the GNOME session beyond the minimal
fallback, its welcome tools, Xorg). The "Cleanup" phase reads it and removes
only the packages that are actually present, with `pacman -Rns`, asking for
confirmation first.

The IDE is not in any list: if you select a `dev-*` group, the script asks
which one to install (none, one or several). `--ide code,cursor` skips the
question, `--ide none` installs nothing; with `--yes` and no `--ide` it uses
the first one. The list is the `IDES` array in `scripts/setup-machine.sh`: to
add an IDE, one `key|label|packages` line is enough.

Left out, because they depend on the machine or on secrets: default shell,
SSH and GPG keys, monitor layout, NVIDIA mode and the noctalia overrides in
`~/.local/state/noctalia/settings.toml`.

## Packages in this repo

| Package | Linked paths |
| --- | --- |
| `applications` | `~/.local/share/applications/` (hidden or fixed menu entries) |
| `bat` | `~/.config/bat/config` (theme generated by noctalia) |
| `gitmux` | `~/.gitmux.conf` |
| `code` | `~/.config/code-flags.conf` (keyring under niri) |
| `cursor` | `~/.config/systemd/user/cursor-agent-reaper.{service,timer}` (hourly kill of cursor-agent workers orphaned by closed windows) |
| `easyeffects` | `~/.config/easyeffects/db/`, `~/.local/share/easyeffects/` (presets, impulses, autoload) |
| `kitty` | `~/.config/kitty/` |
| `lazygit` | `~/.config/lazygit/config.yml` |
| `niri` | `~/.config/niri/`, `~/.config/xdg-desktop-portal/niri-portals.conf`, `~/.config/xdg-terminals.list`, `~/.local/share/applications/terminal-single.desktop`, autostart |
| `noctalia` | `~/.config/noctalia/config.toml`, `~/.config/noctalia/palettes/`, autostart |
| `nvim` | `~/.config/nvim/` |
| `ssh` | `~/.config/environment.d/ssh-agent.conf` (`SSH_AUTH_SOCK` for the systemd agent) |
| `starship` | `~/.config/starship/` (`~/.config/starship.toml` is generated by `starship-build.sh`) |
| `gtk` | `~/.config/gtk-3.0/settings.ini`, `~/.config/gtk-4.0/settings.ini` (dark preference for GTK programs) |
| `tmux` | `~/.tmux.conf`, `~/.tmux/` |
| `zshrc` | `~/.zshrc`, `~/.zshrc_customs.zsh` |

## Theme notes

Prompt, tmux status, gitmux, kitty and Neovim share a **noctalia green** palette
(`#8fbf98` accent, `#1c1c1e` background). Rounded prompt / status segments use
Nerd Font glyphs; Neovim loads it via `base16-nvim` as `noctalia-green`.

noctalia's palette is the source: its templates regenerate GTK, Qt, niri, bat,
fzf, lazygit and the others. For hand-written files there are user templates
in the repo (`noctalia/.config/noctalia/templates/`): **tmux**, **gitmux**,
**starship**, **kitty** and **Neovim** take their colors from the palette (the
soft tones live in `[theme.templates.custom_colors]` in `config.toml`: anyone
reusing these dotfiles changes them there). The files kitty.conf, .tmux.conf,
.gitmux.conf, palette.lua (nvim) and palette-default.toml keep the same values
as a fallback, and `scripts/accent-sync` keeps them aligned (accent).

```bash
accent-sync --check     # exits 1 if anything is out of sync
accent-sync --dry-run   # show what would change
accent-sync             # apply the palette accent
```

## Kitty notes

`kitty.conf` sets `hide_window_decorations yes`, so on GNOME you get no title bar and no
minimize/maximize/close buttons (Mutter does not draw them). That is intentional for a
tiling compositor look. To restore the normal GNOME window chrome while testing on GNOME,
set `hide_window_decorations no` (or remove the line) and restart kitty. On niri you will
usually want decorations hidden again.

## Tmux: grab text from dense logs

Two TPM plugins help when you scroll long logs and need to copy paths, URLs, hashes, etc.:

| Shortcut | Plugin | What it does |
| --- | --- | --- |
| `Prefix` (`Ctrl+s`) then `F` | [tmux-fingers](https://github.com/Morantron/tmux-fingers) | Highlights matches on screen; press the hint letter to copy |
| `Alt+f` | tmux-fingers | Same, without prefix |
| `Prefix` then `J` | tmux-fingers | Jump cursor to a match |
| `Prefix` then `Tab` | [extrakto](https://github.com/laktak/extrakto) | Fuzzy-find tokens from scrollback (`fzf`); Enter copies |
| `Alt+e` | extrakto | Same, without prefix |

Requires **fzf** (`pacman -S fzf`). After pulling these plugins, in tmux run `Prefix` then `I` (TPM install), then `Prefix` then `r` to reload.

## Inspiration

Niri + Noctalia direction (and the soft green accent idea) was inspired by:

- [prasangeet/endeavouros-niri](https://github.com/prasangeet/endeavouros-niri)

This repo is **not** a fork: shell stack stays zsh/tmux/starship, configs are managed with
GNU Stow, and package/UI choices differ (e.g. Nautilus instead of Dolphin for now).

## Installers

`scripts/setup-machine.sh` is the full installer for a new Arch / EndeavourOS
machine (packages by group, stow, per-machine files, login manager, cleanup). See
[docs/ADAPTING.md](docs/ADAPTING.md) before running it.

`scripts/install-niri.sh` is the older, minimal helper: it only installs the niri
packages and stows `kitty` and `niri`. It does **not** wipe `~/.config` and does
**not** replace GNOME.

```bash
cd ~/.dotfiles
./scripts/install-niri.sh           # also runs pacman -Syu
./scripts/install-niri.sh --no-update
```

It installs `niri`, `noctalia` (v5 from `extra/`), `xwayland-satellite`, portals,
the pipewire stack, `kitty`, grim/slurp, and optionally removes leftover Noctalia v4
AUR packages (`noctalia-shell`, `noctalia-qs`, `quickshell`, `quickshell-git`).

## Defaults worth knowing

- **Cursor / icons**: GNOME **Qogir** + **Qogir-Dark** (`config.kdl` sets
  `xcursor-theme "Qogir"`). Change it there if you prefer another theme.
- **File manager**: Nautilus + File Roller (`Mod+E` runs `nautilus`). Dolphin and Ark
  are not installed; switch the bind in `config.kdl` if you want them.
- **Terminal**: kitty with tmux, started with the niri session (`spawn-at-startup`);
  also `Ctrl+Alt+T` and `Super+Return`.
- **Wallpaper** is owned by Noctalia v5, not swaybg.

## Troubleshooting

### Blank gray desktop, mouse only, no bar / no shortcuts feel “dead”

1. **Noctalia did not start** — from a TTY or GNOME check:
   ```bash
   pacman -Q noctalia
   command -v noctalia
   noctalia --daemon
   ```
   Needs `extra/noctalia` (v5). Keybinds use `noctalia msg …` (not the old
   `qs -c noctalia-shell`). Then re-login to Niri.
2. **Wrong GPU env** — do not force `MESA_LOADER_DRIVER_OVERRIDE=iris` /
   `GBM_BACKEND=iris` on non-Intel machines (kept out of shared `config.kdl`).
3. **Right-click on empty desktop** does nothing by design (no GNOME desktop menu).
4. **Mod key is Super (Windows key)** for most binds. Terminal: `Ctrl+Alt+T` or
   `Super+Return`. If kitty autostart is on, a terminal should already be open.

### Monitors differ between PCs

Shared `config.kdl` must not hardcode one machine's layout. Two ignored files hold it:

- `niri/.config/niri/monitor.kdl`: mode, scale, position, rotation. Written by
  `nwg-displays` (or by hand). `setup-machine.sh` creates it empty.
- `niri/.config/niri/outputs.local.kdl`: hand-written tweaks that `nwg-displays`
  cannot write (such as `focus-at-startup`). See `outputs.local.kdl.example`.

Find the output names with `niri msg outputs`. niri accepts the connector (`DP-1`) or
the `"Make Model Serial"` string, which survives a change of port.

### Kitty has no GNOME title bar

See **Kitty notes** above (`hide_window_decorations yes`).
