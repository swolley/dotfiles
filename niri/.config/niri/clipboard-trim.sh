#!/bin/bash
# Trims spaces and newlines at the edges of copied text, like the GNOME
# extension did. Started at login by niri (spawn-sh-at-startup).
#
# wl-paste --watch runs this same script again for every text copy, with the
# clipboard on stdin. If trimming changes something the text is copied back;
# the copy-back triggers the watcher once more, finds nothing to trim and
# stops, so there is no loop. Images and files are never touched.
# Caveat: a trimmed copy replaces the original offers, so rich formats (HTML)
# are lost for that one copy.
if [ "${1:-}" = "--handle" ]; then
  shopt -s extglob
  orig=$(cat; printf x); orig=${orig%x}   # the x keeps trailing newlines
  trimmed=${orig##+([[:space:]])}
  trimmed=${trimmed%%+([[:space:]])}
  [ -n "$trimmed" ] && [ "$trimmed" != "$orig" ] && printf '%s' "$trimmed" | wl-copy --type text/plain
  exit 0
fi

exec wl-paste --type text --watch "$0" --handle
