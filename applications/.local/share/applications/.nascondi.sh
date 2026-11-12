#!/bin/sh
# Rigenera gli override che nascondono dal launcher le voci di sistema inutili.
# Un file con lo stesso nome in ~/.local/share/applications ha la precedenza su
# quello in /usr/share: NoDisplay=true toglie l'icona ma lascia intatte le
# associazioni ai tipi di file, cosi' quei programmi restano apribili dai file
# che gestiscono. Serve ripassarlo se un aggiornamento aggiunge voci nuove.
set -eu
cd "$(dirname "$0")"

nascondi() {
  nome="$1"
  motivo="$2"
  origine="/usr/share/applications/$nome.desktop"
  [ -f "$origine" ] || return 0
  {
    echo "[Desktop Entry]"
    echo "# $motivo"
    echo "Type=Application"
    echo "Name=$(grep -m1 '^Name=' "$origine" | cut -d= -f2-)"
    echo "Exec=$(grep -m1 '^Exec=' "$origine" | cut -d= -f2-)"
    icona=$(grep -m1 '^Icon=' "$origine" | cut -d= -f2- || true)
    [ -n "$icona" ] && echo "Icon=$icona"
    echo "NoDisplay=true"
  } > "$nome.desktop"
}

nascondi yad-settings           "yad disegna le finestre degli script eos, non si usa a mano"
nascondi yad-icon-browser       "sfoglia-icone di yad, strumento per chi scrive script"
nascondi cmake-gui              "cmake si usa da riga di comando"
nascondi electron34             "runtime, non un programma da aprire"
nascondi electron37             "runtime, non un programma da aprire"
nascondi java-java-openjdk      "runtime java, lanciato dai programmi"
nascondi jconsole-java-openjdk  "console di diagnostica della jvm"
nascondi jshell-java-openjdk    "shell java interattiva, si usa dal terminale"
nascondi org.freedesktop.IBus.Setup "metodo di input non usato"
nascondi assistant              "manuale delle api qt, per chi sviluppa in qt"
nascondi designer               "editor di interfacce qt"
nascondi linguist               "strumento di traduzione qt"
nascondi qdbusviewer            "ispettore dbus di qt"
nascondi qv4l2                  "test delle webcam, strumento di v4l-utils"
nascondi qvidcap                "cattura video di v4l-utils"
nascondi stoken-gui             "token rsa securid, non in uso"
nascondi stoken-gui-small       "token rsa securid, non in uso"
nascondi gnome-display-panel    "impostazioni schermo di gnome: sotto niri si usa nwg-displays"
nascondi org.gnome.ColorProfileViewer "profili colore: nessuno e' configurato"
nascondi gcm-picker             "prelievo colore di gnome-color-manager"
nascondi gcm-import             "importa profili colore"
nascondi vim                    "l'editor e' neovim; vim resta per il comando vi degli script"

# KDE Connect: l'interfaccia e' il plugin phone-connect sulla barra di
# noctalia, accoppiamento compreso (il pannello mostra Accoppia accanto ai
# dispositivi visti in rete). kdeconnect-app resta solo come riserva.
nascondi org.kde.kdeconnect.app       "il telefono si governa dal widget di noctalia"
nascondi org.kde.kdeconnect.nonplasma "indicatore per desktop senza plasma: lo fa gia' la barra"
nascondi org.kde.kdeconnect.sms       "gli sms si mandano dal pannello di phone-connect"

# Visualizzatori: restano i programmi predefiniti per immagini e PDF, quindi
# si aprono con un doppio clic da nautilus. Nel menu' non servono: non e' da
# li' che si parte, si parte sempre dal file.
nascondi org.gnome.Loupe  "visualizzatore immagini: si apre dal file, non dal menu'"
nascondi org.gnome.Papers "visualizzatore pdf: si apre dal file, non dal menu'"

# hwloc: disegna la topologia di cpu e memoria. Arriva come dipendenza (lo usa
# pipewire), non e' un programma che si apre dal menu'; da riga di comando
# resta `lstopo`.
nascondi lstopo "mappa della topologia hardware, strumento da riga di comando"

# nvtop: il `top` della gpu, arriva come dipendenza di mission-center, che e'
# l'interfaccia che uso davvero. Resta il comando `nvtop` nel terminale.
nascondi nvtop "monitor gpu da terminale: la finestra e' mission-center"

# gestore archivi: si apre sempre da nautilus, con "Estrai qui" o doppio clic
# su uno zip. Resta il programma predefinito per gli archivi.
nascondi org.gnome.FileRoller "gestore archivi: si apre dal file, non dal menu'"


# eos-update: apre un terminale per fare quello che faccio a mano quando mi
# va, con un conto alla rovescia di 60 secondi alla fine.
nascondi eos-update "aggiornamento di endeavouros: lo lancio dal terminale"

# GParted: stessa precedenza, ma qui non si nasconde, si sostituisce il
# comando. Il percorso del lanciatore va scritto per esteso, perche' nei file
# .desktop non esistono ne' ~ ne' le variabili d'ambiente.
cat > gparted.desktop <<FINE
[Desktop Entry]
# lanciato tramite gparted-wayland: vedi i commenti in quello script
Type=Application
Name=$(grep -m1 '^Name=' /usr/share/applications/gparted.desktop | cut -d= -f2-)
Comment=$(grep -m1 '^Comment=' /usr/share/applications/gparted.desktop | cut -d= -f2-)
Exec=$HOME/.local/share/applications/gparted-wayland %f
Icon=$(grep -m1 '^Icon=' /usr/share/applications/gparted.desktop | cut -d= -f2-)
Categories=System;Filesystem;
Keywords=Partition;Partizioni;Disco;
Terminal=false
StartupNotify=true
FINE
