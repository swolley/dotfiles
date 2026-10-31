# Dotfiles

Personal configuration files managed with [GNU Stow](https://www.gnu.org/software/stow/).

Each top-level directory is a **stow package**. Stow creates symlinks from that package into `$HOME`, mirroring the directory tree inside the package.

## Structure

```text
.dotfiles/
├── gitmux/          → ~/.gitmux.conf
├── easyeffects/     → ~/.config/easyeffects/db/, ~/.local/share/easyeffects/
├── kitty/           → ~/.config/kitty/
├── niri/            → ~/.config/niri/, ~/.config/xdg-desktop-portal/
├── noctalia/        → ~/.config/noctalia/
├── nvim/            → ~/.config/nvim/
├── starship/        → ~/.config/starship.toml
├── tmux/            → ~/.tmux.conf, ~/.tmux/
├── zshrc/           → ~/.zshrc, ~/.zshrc_customs.zsh
└── scripts/         → setup-machine.sh, install-niri.sh, pkg, aur-wrap
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

## Nuova macchina

Dopo aver clonato il repo, `scripts/setup-machine.sh` installa i pacchetti,
abilita i servizi e applica gli stow. Chiede gruppo per gruppo, tranne `base`
che installa sempre.

```bash
./scripts/setup-machine.sh            # interattivo
./scripts/setup-machine.sh --list     # elenca i gruppi
./scripts/setup-machine.sh --dry-run  # mostra i comandi senza eseguirli
./scripts/setup-machine.sh --yes --only base,niri-noctalia,dev-php
```

Le liste stanno in `scripts/packages/*.txt`, una per gruppo, un pacchetto per
riga. I linguaggi non hanno versioni fissate: i repo portano sempre l'ultima
stabile. Per aggiungere software, modifica il file del gruppo giusto.

Restano fuori, perche' dipendono dalla macchina o da segreti: shell di default,
chiavi SSH e GPG, disposizione dei monitor, modalita' NVIDIA e gli override di
noctalia in `~/.local/state/noctalia/settings.toml`.

## Packages in this repo

| Package | Linked paths |
| --- | --- |
| `gitmux` | `~/.gitmux.conf` |
| `easyeffects` | `~/.config/easyeffects/db/`, `~/.local/share/easyeffects/` (preset, impulsi, autoload), autostart |
| `kitty` | `~/.config/kitty/` |
| `niri` | `~/.config/niri/`, `~/.config/xdg-desktop-portal/niri-portals.conf` |
| `noctalia` | `~/.config/noctalia/config.toml`, `~/.config/noctalia/palettes/`, autostart |
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

## Niri installer

Stow-safe helper for Arch / EndeavourOS (does **not** wipe `~/.config`, does **not**
replace GNOME):

```bash
cd ~/.dotfiles
./scripts/install-niri.sh           # also runs pacman -Syu
./scripts/install-niri.sh --no-update
```

What it installs:
- pacman: `niri`, `noctalia` (v5 from `extra/`), `xwayland-satellite`, portals,
  swaybg/swayidle, grim/slurp, pipewire stack, `kitty`, `polkit-gnome`, …
- stow: `kitty` and `niri` (config + portals)
- optionally removes leftover Noctalia v4 AUR packages (`noctalia-shell`,
  `noctalia-qs`, `quickshell`, `quickshell-git`)

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
- Stow package `niri/` is ready. Run `./scripts/install-niri.sh` when you want
  packages, then `stow niri` (the installer does this), log into Niri, and tune
  monitor/wallpaper (wallpaper is owned by Noctalia v5, not swaybg).
- Kitty starts with the Niri session (`spawn-at-startup`); also `Ctrl+Alt+T` and
  `Super+Return`.

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

Shared `config.kdl` must not hardcode one machine’s layout. Use
`niri/.config/niri/outputs.local.kdl` after `niri msg outputs` (see
`outputs.local.kdl.example`). Leave it empty for auto-placement. Keep host-specific
edits uncommitted, or add `hosts/<hostname>.kdl` and:

```bash
cd ~/.config/niri   # or the stow package dir
ln -sfn "hosts/$(hostname -s).kdl" outputs.local.kdl
```

### Kitty has no GNOME title bar

See **Kitty notes** above (`hide_window_decorations yes`).
