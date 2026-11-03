#!/bin/sh
# Mod+D in stile gnome: un ciclo a tre passi.
#   chiuso  -> griglia applicazioni (nwg-drawer)
#   griglia -> overview delle finestre
#   overview-> chiuso
#
# nwg-drawer non sa dire se e' visibile: lo si deduce dal suo layer-shell,
# che compare in `niri msg layers` solo quando la finestra e' mostrata.

drawer_visibile() {
  niri msg --json layers 2>/dev/null | grep -q '"nwg-drawer"'
}

overview_aperta() {
  niri msg --json overview-state 2>/dev/null | grep -q '"is_open":[[:space:]]*true'
}

if drawer_visibile; then
  nwg-drawer -close >/dev/null 2>&1
  niri msg action toggle-overview
elif overview_aperta; then
  niri msg action toggle-overview
elif command -v nwg-drawer >/dev/null 2>&1; then
  nwg-drawer -open >/dev/null 2>&1
else
  # ripiego se nwg-drawer non e' installato
  noctalia msg panel-toggle launcher
fi
