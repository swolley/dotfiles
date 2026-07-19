# Dotfiles

Personal configuration files managed with [GNU Stow](https://www.gnu.org/software/stow/).

Each top-level directory is a **stow package**. Stow creates symlinks from that package into `$HOME`, mirroring the directory tree inside the package.

## Structure

```text
.dotfiles/
├── gitmux/          → ~/.gitmux.conf
├── kitty/           → ~/.config/kitty/
├── nvim/            → ~/.config/nvim/
├── starship/        → ~/.config/starship.toml
├── tmux/            → ~/.tmux.conf, ~/.tmux/
└── zshrc/           → ~/.zshrc, ~/.zshrc_customs.zsh
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
| `nvim` | `~/.config/nvim/` |
| `starship` | `~/.config/starship.toml` |
| `tmux` | `~/.tmux.conf`, `~/.tmux/` |
| `zshrc` | `~/.zshrc`, `~/.zshrc_customs.zsh` |

## Theme notes

Prompt, tmux status, gitmux, kitty and Neovim share a **noctalia green** palette
(`#8fbf98` accent, `#1c1c1e` background). Rounded prompt / status segments use
Nerd Font glyphs; Neovim loads it via `base16-nvim` as `noctalia-green`.
