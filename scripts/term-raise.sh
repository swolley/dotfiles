#!/usr/bin/env bash
# ~/.dotfiles/scripts/term-raise.sh
S=${TERM_RAISE_SESSION:-default}

# --- 1. compositor ---------------------------------------------------------
if   [ -n "$NIRI_SOCKET" ];                    then WM=niri
elif [ -n "$SWAYSOCK" ];                       then WM=sway
elif [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ];    then WM=hyprland
elif [[ "$XDG_CURRENT_DESKTOP" == *GNOME* ]];  then WM=gnome
elif [ -n "$DISPLAY" ];                        then WM=x11
else WM=unknown; fi

# --- 2. terminale: preferenze per desktop, primo installato vince ----------
case $WM in
    gnome) prefs="gnome-terminal kgx kitty foot alacritty wezterm ghostty xterm" ;;
    *)     prefs="kitty foot alacritty wezterm ghostty gnome-terminal kgx xterm" ;;
esac
TERMINAL=${TERM_RAISE_TERMINAL:-}
if [ -z "$TERMINAL" ]; then
    for t in $prefs; do command -v "$t" >/dev/null && { TERMINAL=$t; break; }; done
fi
[ -z "$TERMINAL" ] && { echo "term-raise: nessun terminale trovato" >&2; exit 1; }

# --- 3. app_id / WM_CLASS e comando di avvio per terminale -----------------
case $TERMINAL in
    kitty)          APP=kitty;                  launch() { kitty tmux "$@"; } ;;
    foot)           APP=foot;                   launch() { foot tmux "$@"; } ;;
    alacritty)      APP=Alacritty;              launch() { alacritty -e tmux "$@"; } ;;
    wezterm)        APP=org.wezfurlong.wezterm; launch() { wezterm start -- tmux "$@"; } ;;
    ghostty)        APP=com.mitchellh.ghostty;  launch() { ghostty -e tmux "$@"; } ;;
    gnome-terminal) APP=gnome-terminal-server;  launch() { gnome-terminal -- tmux "$@"; } ;;
    kgx)            APP=org.gnome.Console;      launch() { kgx -e "tmux $*"; } ;;
    *)              APP=$TERMINAL;              launch() { "$TERMINAL" -e tmux "$@"; } ;;
esac

# --- 4. focus per compositor -----------------------------------------------
raise() {
    case $WM in
        niri)
            id=$(niri msg -j windows | jq -r --arg a "$APP" '[.[]|select(.app_id==$a)][0].id // empty')
            [ -n "$id" ] && niri msg action focus-window --id "$id" ;;
        sway)     swaymsg "[app_id=\"$APP\"] focus" >/dev/null ;;
        hyprland) hyprctl dispatch focuswindow "class:^($APP)$" >/dev/null ;;
        gnome)
            gdbus call --session --dest org.gnome.Shell \
                --object-path /de/lucaswerkmeister/ActivateWindowByTitle \
                --method de.lucaswerkmeister.ActivateWindowByTitle.activateByWmClass \
                "$APP" >/dev/null 2>&1 ;;
        x11)      wmctrl -xa "$APP" 2>/dev/null ;;
    esac || true
}

# --- 5. logica principale --------------------------------------------------
if tmux list-clients -t "$S" 2>/dev/null | grep -q .; then
    tmux new-window -t "$S"
    raise
else
    launch new-session -A -s "$S"
fi
