#!/bin/sh
# Un solo terminale. Mod+Return gli da' il focus invece di aprirne un altro;
# Mod+Shift+Return crea una nuova sessione tmux dentro la stessa finestra.
#   terminal.sh focus  -> focus alla kitty esistente, o la apre su tmux
#   terminal.sh new    -> nuova sessione tmux, e focus alla finestra
SESSION=main

kitty_id() {
  niri msg --json windows 2>/dev/null \
    | jq -r 'map(select(.app_id == "kitty")) | sort_by(.id) | .[0].id // empty'
}

last_client() {  # il client tmux usato piu' di recente
  tmux list-clients -F '#{client_activity} #{client_name}' 2>/dev/null \
    | sort -rn | head -1 | cut -d' ' -f2-
}

open_kitty() {   # si aggancia a una sessione esistente, altrimenti la crea
  target=$(tmux ls -F '#{session_last_attached} #{session_name}' 2>/dev/null \
    | sort -rn | head -1 | cut -d' ' -f2-)
  [ -n "$target" ] || target=$SESSION
  setsid kitty -- tmux new-session -A -s "$target" >/dev/null 2>&1 &
}

id=$(kitty_id)

case "${1:-focus}" in
  focus)
    if [ -n "$id" ]; then
      niri msg action focus-window --id "$id"
    else
      open_kitty
    fi
    ;;
  new)
    if [ -n "$id" ] && tmux has-session 2>/dev/null; then
      name=$(tmux new-session -d -P -F '#{session_name}' -c "$HOME")
      client=$(last_client)
      [ -n "$client" ] && tmux switch-client -c "$client" -t "$name"
      niri msg action focus-window --id "$id"
    else
      open_kitty
    fi
    ;;
  *)
    echo "uso: $0 {focus|new}" >&2; exit 1 ;;
esac
