#!/bin/sh
# Mod+D in stile gnome: un ciclo a tre passi.
#   chiuso   -> launcher di noctalia
#   launcher -> overview delle finestre
#   overview -> chiuso
#
# Lo stato del pannello lo dice la shell: `noctalia msg status` riporta quale
# pannello e' attivo. Quello di niri sta in `niri msg overview-state`.

launcher_aperto() {
  noctalia msg status 2>/dev/null | grep -q '"activePanelId":[[:space:]]*"launcher"'
}

overview_aperta() {
  niri msg --json overview-state 2>/dev/null | grep -q '"is_open":[[:space:]]*true'
}

if launcher_aperto; then
  noctalia msg panel-close launcher >/dev/null 2>&1
  niri msg action toggle-overview
elif overview_aperta; then
  niri msg action toggle-overview
else
  noctalia msg panel-open launcher >/dev/null 2>&1
fi
