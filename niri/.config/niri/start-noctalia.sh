#!/bin/sh
# Starts the noctalia shell (v5, native). If it dies, shows why:
# in v5 noctalia IS also the notification daemon, so notify-send cannot
# report its own failure. Log goes to the journal + a kitty window.
LOG="${XDG_RUNTIME_DIR:-/tmp}/noctalia.log"

"$HOME/.config/niri/theme-session.sh" niri

noctalia >"$LOG" 2>&1
rc=$?

logger -t noctalia-startup "noctalia exited with code $rc (log: $LOG)"
kitty -e sh -c "printf '\n=== noctalia exited, code %s ===\n\n' '$rc'; tail -n 60 '$LOG'; printf '\nPress Enter to close.\n'; read _" 2>/dev/null
