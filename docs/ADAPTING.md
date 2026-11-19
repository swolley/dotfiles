# Adapting these dotfiles to your machine

These dotfiles are the author's own setup (Arch/EndeavourOS, niri + noctalia),
shared as a starting point. This guide lists what is personal, what is
generated per machine, and what to change before using them.

Packages are managed with [GNU stow](https://www.gnu.org/software/stow/): each
top-level directory is a package that mirrors `$HOME`. The repo is expected at
`~/.dotfiles` (a few units and binds refer to that path).

## 1. Run the installer

```bash
git clone <this repo> ~/.dotfiles
cd ~/.dotfiles
./scripts/setup-machine.sh --help
./scripts/setup-machine.sh            # interactive; asks before anything risky
```

It installs the package groups in `scripts/packages/`, stows the packages,
asks which monitor is the main one, and creates the per-machine files below.
Read `scripts/packages/*.txt` and `scripts/remove.txt` first: the removal list
is the author's choice (GNOME shell, gdm...) and is only applied after asking.

## 2. Per-machine files (never committed)

These depend on the hardware or the user and are git-ignored. The installer
creates the first two; the others you create or let the tools write.

| File | What it holds | How it is made |
|---|---|---|
| `~/.config/noctalia/90-monitors.local.toml` | which monitor shows bars, OSD, notifications | `setup-machine.sh` |
| `~/.config/noctalia/91-user.local.toml` | terminal command, avatar, wallpaper (absolute paths) | `setup-machine.sh`; see `91-user.local.toml.example` |
| `~/.config/niri/monitor.kdl` | monitor layout (mode, scale, position, rotation) | `nwg-displays`, or by hand; empty file on a new machine |
| `~/.config/niri/outputs.local.kdl` | hand-written monitor tweaks (`focus-at-startup`...) | empty from `setup-machine.sh`; edit, see `outputs.local.kdl.example` |

niri merges `output` blocks with the same name, so `outputs.local.kdl` only
needs the keys `nwg-displays` cannot write. Connector names (`DP-1`...) change
with the port you use; niri also accepts the `"Make Model Serial"` string.

## 3. Personal choices to review

These are the author's preferences, marked with a comment in the files as
"kept temporarily, final decision deferred". Change or delete them:

- `niri/.config/niri/config.kdl`: `XF86Mail` (Outlook), `XF86Tools` (Tidal),
  the Firefox window rule (opens maximized on `eDP-1`), `xcursor-theme "Qogir"`.
- `noctalia/.config/noctalia/config.toml`: notification filters (Claude,
  Laravel Mix), `lang = "it"`, the plugin and community template lists, the
  polkit agent note about FortiClient.
- `zshrc/.zshrc_customs.zsh`: the `html` helper and `HTML_BASE_PATH` (the
  author's project folders).
- `scripts/remove.txt` and `scripts/packages/`: which packages to install and
  remove, and the dev stacks. `30-nvidia.txt` is only installed when an NVIDIA GPU is
  detected (`lspci`), so it needs no editing.
- `easyeffects/`: presets, impulse responses and EQ curves for the author's
  headphones and microphone (HIFIMAN Sundara, MEE Audio M6 Pro, RODE NTH-100,
  Monolith M565C). Useless for other hardware; the decision on how to split it
  out is deferred. Do not stow this package unless you have the same devices.
- Noctalia plugins in `[plugins] enabled`: `phone-connect` (KDE Connect),
  `headroom` (Claude usage), `vpn-manager`, `arch-updater`, `screen-toolkit`.
  Keep what you use; the shared list is deferred like the items above.
- Keyboard layout: `niri/.config/niri/config.kdl` `input { keyboard { xkb } }`
  is left empty (system default).

## 4. Assumptions in the setup

- Single terminal: `niri/.config/niri/terminal.sh` keeps one kitty window and
  opens tmux sessions inside it. `zshrc/.zshrc` auto-attaches tmux (session
  `default`) in real terminals only, not in editors or the Claude desktop panel.
- Colors come from noctalia: `[theme.templates.user.*]` in `config.toml`
  render tmux, kitty, starship, gitmux and nvim colors into the cache, with
  fallback palettes in the repo. `scripts/noctalia-sync` and
  `scripts/accent-sync` keep the shared palette in step.
- Noctalia plugins are materialized from upstream; local fixes to them live in
  `scripts/patch-plugins` and are re-applied by `noctalia-plugin-patches.path`.
- `scripts/dotfiles-updates` (started by niri) notifies when the repo has
  commits to pull.

## 5. What is not portable yet

- The installer targets Arch (pacman/AUR); other distributions are not
  supported.
- niri + noctalia is the only supported desktop.
