#!/bin/sh
# Mod+D, GNOME style: a three-step cycle.
#   closed   -> noctalia launcher
#   launcher -> window overview
#   overview -> closed
#
# The shell reports the panel state: `noctalia msg status` says which panel is
# active. niri's own state is in `niri msg overview-state`.

launcher_open() {
  noctalia msg status 2>/dev/null | grep -q '"activePanelId":[[:space:]]*"launcher"'
}

overview_open() {
  niri msg --json overview-state 2>/dev/null | grep -q '"is_open":[[:space:]]*true'
}

if launcher_open; then
  noctalia msg panel-close launcher >/dev/null 2>&1
  niri msg action toggle-overview
elif overview_open; then
  niri msg action toggle-overview
else
  noctalia msg panel-open launcher >/dev/null 2>&1
fi
