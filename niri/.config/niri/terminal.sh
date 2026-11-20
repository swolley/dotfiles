#!/bin/sh
# A single terminal. Mod+Return focuses it instead of opening another one;
# Mod+Shift+Return creates a new tmux session inside the same window.
#   terminal.sh focus      -> focus the existing kitty, or open one on tmux
#   terminal.sh new        -> new tmux session, and focus the window
#   terminal.sh cwd [dir]  -> like new, but in the given directory (default: $PWD);
#                             used by Nautilus for "Open in Terminal"
#   terminal.sh run <cmd>  -> runs the command in a new tmux session inside
#                             the existing window. Used by programs that want
#                             to "open a terminal", like the arch-updater
#                             plugin: it also accepts the -e separator that
#                             many pass out of habit.
SESSION=main

kitty_id() {
  niri msg --json windows 2>/dev/null \
    | jq -r 'map(select(.app_id == "kitty")) | sort_by(.id) | .[0].id // empty'
}

last_client() {  # the most recently used tmux client
  tmux list-clients -F '#{client_activity} #{client_name}' 2>/dev/null \
    | sort -rn | head -1 | cut -d' ' -f2-
}

open_kitty() {   # $1 = initial directory (optional)
                 # attaches to an existing session, otherwise creates one
  target=$(tmux ls -F '#{session_last_attached} #{session_name}' 2>/dev/null \
    | sort -rn | head -1 | cut -d' ' -f2-)
  [ -n "$target" ] || target=$SESSION
  if [ -n "${1:-}" ]; then
    # with a directory we need a new session: "new-session -A" on an
    # existing session reattaches it and ignores -c, and we would end up elsewhere
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
    [ $# -gt 0 ] || { echo "usage: $0 run [-e] <command...>" >&2; exit 1; }
    if [ -n "$id" ] && tmux has-session 2>/dev/null; then
      name=$(tmux new-session -d -P -F '#{session_name}' "$@")
      # on success the pane closes with the command, as in a normal terminal;
      # on failure it stays visible, otherwise the error would vanish before
      # you could read it
      tmux set-option -t "$name" remain-on-exit failed
      client=$(last_client)
      [ -n "$client" ] && tmux switch-client -c "$client" -t "$name"
      niri msg action focus-window --id "$id"
    else
      setsid kitty -- tmux new-session "$@" >/dev/null 2>&1 &
    fi
    ;;
  *)
    echo "usage: $0 {focus|new|cwd [dir]|run <command>}" >&2; exit 1 ;;
esac
