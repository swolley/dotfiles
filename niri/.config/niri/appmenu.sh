#!/bin/sh
# Menu applicazioni in stile mate (nwg-menu): categorie in colonna a sinistra.
# Si apre dal pulsante sulla barra di noctalia, accanto alla lente.
#
# nwg-menu non ha ne' -open ne' -close e non resta residente: ogni avvio apre
# una finestra nuova. Il secondo clic sul pulsante arriverebbe quando il menu
# e' gia' aperto, quindi qui si fa il toggle a mano chiudendo il processo.
#
# -t  le categorie si aprono passandoci sopra, come su mate
# -k  un clic fuori chiude
# -d  si chiude anche uscendo col mouse
# -va top  la barra di noctalia sta in alto
#
# Le icone: -isl vale per le categorie e per i risultati della ricerca, -iss
# per le voci dentro i sottomenu. A 1 l'icona sparisce, ed e' quello che si
# vuole nella colonna delle categorie, che fa solo da indice. Le dimensioni
# dei nomi stanno nel css, perche' nwg-menu non ha flag per il testo.
#
# nwg-menu non conosce niri: il suo -wm sa solo sway, hyprland e river. Senza
# quel flag lancia i programmi da se', che per l'avvio normale va bene; restano
# figli del menu invece di essere avviati dal compositore.

if pgrep -x nwg-menu >/dev/null 2>&1; then
  pkill -x nwg-menu
  exit 0
fi

exec nwg-menu \
  -t -k -d \
  -va top -ha left \
  -mt 4 -ml 4 \
  -isl 1 -iss 16 \
  -padding 4 \
  -fm nautilus \
  -term "$HOME/.config/niri/terminal.sh run" \
  -cmd-lock "noctalia msg session lock" \
  -cmd-logout "noctalia msg session logout" \
  -cmd-restart "noctalia msg session reboot" \
  -cmd-shutdown "noctalia msg session shutdown"
