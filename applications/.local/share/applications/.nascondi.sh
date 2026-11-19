#!/bin/sh
# Regenerates the overrides that hide useless system entries from the launcher.
# A file with the same name in ~/.local/share/applications takes precedence over
# the one in /usr/share: NoDisplay=true removes the icon but leaves the file
# type associations intact, so those programs can still be opened from the
# files they handle. Run it again if an update adds new entries.
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

nascondi yad-settings           "yad draws the windows of the eos scripts, not meant to be used directly"
nascondi yad-icon-browser       "yad icon browser, a tool for people writing scripts"
nascondi cmake-gui              "cmake is used from the command line"
nascondi electron34             "runtime, not a program to open"
nascondi electron37             "runtime, not a program to open"
nascondi java-java-openjdk      "Java runtime, launched by other programs"
nascondi jconsole-java-openjdk  "JVM diagnostics console"
nascondi jshell-java-openjdk    "interactive Java shell, used from the terminal"
nascondi org.freedesktop.IBus.Setup "input method not in use"
nascondi assistant              "Qt API manual, for Qt developers"
nascondi designer               "Qt interface editor"
nascondi linguist               "Qt translation tool"
nascondi qdbusviewer            "Qt D-Bus inspector"
nascondi qv4l2                  "webcam test tool from v4l-utils"
nascondi qvidcap                "video capture from v4l-utils"
nascondi stoken-gui             "RSA SecurID token, not in use"
nascondi stoken-gui-small       "RSA SecurID token, not in use"
nascondi gnome-display-panel    "GNOME display settings: under niri, nwg-displays is used"
nascondi org.gnome.ColorProfileViewer "color profiles: none are configured"
nascondi gcm-picker             "color picker from gnome-color-manager"
nascondi gcm-import             "imports color profiles"
nascondi vim                    "the editor is neovim; vim stays for the vi command used by scripts"

# KDE Connect: most of the work is done by the phone-connect plugin on the
# noctalia bar, pairing included (the panel shows Pair next to the devices
# seen on the network). The real window stays in the menu though: it is the
# only way to reach the per-device settings, the plugins and the phone file
# browser, which the bar does not expose.
nascondi org.kde.kdeconnect.nonplasma "indicator for non-Plasma desktops: the bar already does this"
nascondi org.kde.kdeconnect.sms       "SMS are sent from the phone-connect panel"

# Viewers: they remain the default programs for images and PDFs, so they open
# with a double click from nautilus. They are not needed in the menu: that is
# not where you start from, you always start from the file.
nascondi org.gnome.Loupe  "image viewer: opened from the file, not from the menu"
nascondi org.gnome.Papers "PDF viewer: opened from the file, not from the menu"

# hwloc: draws the CPU and memory topology. It comes in as a dependency (used
# by pipewire), it is not a program to open from the menu; from the command
# line `lstopo` remains.
nascondi lstopo "hardware topology map, a command-line tool"

# nvtop: the GPU `top`, it comes in as a dependency of mission-center, which is
# the interface I actually use. The `nvtop` command remains in the terminal.
nascondi nvtop "terminal GPU monitor: the window is mission-center"

# archive manager: always opened from nautilus, with "Extract here" or a double
# click on a zip. It remains the default program for archives.
nascondi org.gnome.FileRoller "archive manager: opened from the file, not from the menu"


# eos-update: opens a terminal to do what I do by hand when I feel like it,
# with a 60-second countdown at the end.
nascondi eos-update "EndeavourOS update: I run it from the terminal"

# GParted: same precedence, but here it is not hidden, the command is
# replaced. The launcher path has to be written out in full, because in
# .desktop files neither ~ nor environment variables exist.
if [ -f /usr/share/applications/gparted.desktop ]; then
cat > gparted.desktop <<FINE
[Desktop Entry]
# launched through gparted-wayland: see the comments in that script
Type=Application
Name=$(grep -m1 '^Name=' /usr/share/applications/gparted.desktop | cut -d= -f2-)
Comment=$(grep -m1 '^Comment=' /usr/share/applications/gparted.desktop | cut -d= -f2-)
Exec=$HOME/.local/share/applications/gparted-wayland %f
Icon=$(grep -m1 '^Icon=' /usr/share/applications/gparted.desktop | cut -d= -f2-)
Categories=System;Filesystem;
Keywords=Partition;Partitions;Disk;
Terminal=false
StartupNotify=true
FINE
fi
