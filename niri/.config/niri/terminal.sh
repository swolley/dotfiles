#!/bin/sh
# Un solo terminale. Mod+Return gli da' il focus invece di aprirne un altro;
# Mod+Shift+Return crea una nuova sessione tmux dentro la stessa finestra.
#   terminal.sh focus      -> focus alla kitty esistente, o la apre su tmux
#   terminal.sh new        -> nuova sessione tmux, e focus alla finestra
#   terminal.sh cwd [dir]  -> come new, ma nella cartella indicata (default: $PWD);
#                             la usa Nautilus per "Apri nel terminale"
#   terminal.sh run <cmd>  -> esegue il comando in una nuova sessione tmux
#                             dentro la finestra esistente. Lo usano i
#                             programmi che vogliono "aprire un terminale",
#                             come il plugin arch-updater: accetta anche il
#                             separatore -e che molti passano per abitudine.
SESSION=main

kitty_id() {
  niri msg --json windows 2>/dev/null \
    | jq -r 'map(select(.app_id == "kitty")) | sort_by(.id) | .[0].id // empty'
}

last_client() {  # il client tmux usato piu' di recente
  tmux list-clients -F '#{client_activity} #{client_name}' 2>/dev/null \
    | sort -rn | head -1 | cut -d' ' -f2-
}

open_kitty() {   # $1 = cartella iniziale (facoltativa)
                 # si aggancia a una sessione esistente, altrimenti la crea
  target=$(tmux ls -F '#{session_last_attached} #{session_name}' 2>/dev/null \
    | sort -rn | head -1 | cut -d' ' -f2-)
  [ -n "$target" ] || target=$SESSION
  if [ -n "${1:-}" ]; then
    # con una cartella serve una sessione nuova: "new-session -A" su una
    # sessione esistente la riaggancia e ignora -c, e si finirebbe altrove
    name=$(tmux new-session -d -P -F '#{session_name}' -c "$1" 2>/dev/null)
    if [ -n "$name" ]; then
      setsid kitty -- tmux attach-session -t "$name" >/dev/null 2>&1 &
    else
      setsid kitty -- tmux new-session -A -s "$target" -c "$1" >/dev/null 2>&1 &
    fi
  else
    setsid kitty -- tmux new-session -A -s "$target" >/dev/null 2>&1 &
  fi
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
  new|cwd)
    if [ "$1" = cwd ]; then
      dir="${2:-$PWD}"
    else
      dir="$HOME"
    fi
    [ -d "$dir" ] || dir="$HOME"
    if [ -n "$id" ] && tmux has-session 2>/dev/null; then
      name=$(tmux new-session -d -P -F '#{session_name}' -c "$dir")
      client=$(last_client)
      [ -n "$client" ] && tmux switch-client -c "$client" -t "$name"
      niri msg action focus-window --id "$id"
    else
      open_kitty "$dir"
    fi
    ;;
  run)
    shift
    [ "${1:-}" = "-e" ] && shift
    [ $# -gt 0 ] || { echo "uso: $0 run [-e] <comando...>" >&2; exit 1; }
    if [ -n "$id" ] && tmux has-session 2>/dev/null; then
      name=$(tmux new-session -d -P -F '#{session_name}' "$@")
      # il pannello resta visibile dopo la fine del comando: senza questo un
      # errore sparirebbe prima che tu possa leggerlo
      tmux set-option -t "$name" remain-on-exit on
      client=$(last_client)
      [ -n "$client" ] && tmux switch-client -c "$client" -t "$name"
      niri msg action focus-window --id "$id"
    else
      setsid kitty -- tmux new-session "$@" >/dev/null 2>&1 &
    fi
    ;;
  *)
    echo "uso: $0 {focus|new|cwd [dir]|run <comando>}" >&2; exit 1 ;;
esac
