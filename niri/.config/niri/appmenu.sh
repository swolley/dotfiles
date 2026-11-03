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
# per le voci dentro i sottomenu. Restano accese entrambe, perche' sulle
# applicazioni servono a riconoscerle; quelle delle categorie le spegne il
# css, che e' l'unico modo per distinguerle. Le dimensioni dei nomi stanno
# anch'esse nel css: nwg-menu non ha flag per il testo.
#
# I quattro -cmd vuoti tolgono la barra di spegnimento: spegnere e bloccare
# si fanno dal pannello di noctalia, qui erano solo quattro bersagli grossi
# e colorati sotto le cartelle.
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
  -isl 24 -iss 16 \
  -padding 4 \
  -fm nautilus \
  -term "$HOME/.config/niri/terminal.sh run" \
  -cmd-lock "" \
  -cmd-logout "" \
  -cmd-restart "" \
  -cmd-shutdown ""
