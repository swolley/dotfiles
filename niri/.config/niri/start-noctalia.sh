#!/bin/sh
# Avvia la shell noctalia (v5, nativa). Se muore, mostra il motivo:
# in v5 noctalia E' anche il demone di notifica, quindi notify-send non
# puo' segnalare il proprio fallimento. Log su journal + finestra kitty.
LOG="${XDG_RUNTIME_DIR:-/tmp}/noctalia.log"

"$HOME/.config/niri/theme-session.sh" niri

noctalia >"$LOG" 2>&1
rc=$?

logger -t noctalia-startup "noctalia terminato con codice $rc (log: $LOG)"
kitty -e sh -c "printf '\n=== noctalia terminato, codice %s ===\n\n' '$rc'; tail -n 60 '$LOG'; printf '\nPremi Invio per chiudere.\n'; read _" 2>/dev/null
