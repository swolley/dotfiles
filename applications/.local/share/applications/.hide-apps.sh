#!/bin/sh
# Regenerates the overrides that hide useless system entries from the launcher.
# A file with the same name in ~/.local/share/applications takes precedence over
# the one in /usr/share: NoDisplay=true removes the icon but leaves the file
# type associations intact, so those programs can still be opened from the
# files they handle. Run it again if an update adds new entries.
set -eu
cd "$(dirname "$0")"

hide_app() {
  name="$1"
  reason="$2"
  source="/usr/share/applications/$name.desktop"
  [ -f "$source" ] || return 0
  {
    echo "[Desktop Entry]"
    echo "# $reason"
    echo "Type=Application"
    echo "Name=$(grep -m1 '^Name=' "$source" | cut -d= -f2-)"
    echo "Exec=$(grep -m1 '^Exec=' "$source" | cut -d= -f2-)"
    icon=$(grep -m1 '^Icon=' "$source" | cut -d= -f2- || true)
    [ -n "$icon" ] && echo "Icon=$icon"
    # without MimeType the override would also drop the file associations
    # (a local file replaces the system one entirely)
    mime=$(grep -m1 '^MimeType=' "$source" | cut -d= -f2- || true)
    [ -n "$mime" ] && echo "MimeType=$mime"
    echo "NoDisplay=true"
  } > "$name.desktop"
}

hide_app yad-settings           "yad draws the windows of the eos scripts, not meant to be used directly"
hide_app yad-icon-browser       "yad icon browser, a tool for people writing scripts"
hide_app cmake-gui              "cmake is used from the command line"
hide_app electron34             "runtime, not a program to open"
hide_app electron37             "runtime, not a program to open"
hide_app java-java-openjdk      "Java runtime, launched by other programs"
hide_app jconsole-java-openjdk  "JVM diagnostics console"
hide_app jshell-java-openjdk    "interactive Java shell, used from the terminal"
hide_app org.freedesktop.IBus.Setup "input method not in use"
hide_app assistant              "Qt API manual, for Qt developers"
hide_app designer               "Qt interface editor"
hide_app linguist               "Qt translation tool"
hide_app qdbusviewer            "Qt D-Bus inspector"
hide_app qv4l2                  "webcam test tool from v4l-utils"
hide_app qvidcap                "video capture from v4l-utils"
hide_app stoken-gui             "RSA SecurID token, not in use"
hide_app stoken-gui-small       "RSA SecurID token, not in use"
hide_app gnome-display-panel    "GNOME display settings: under niri, nwg-displays is used"
hide_app org.gnome.ColorProfileViewer "color profiles: none are configured"
hide_app gcm-picker             "color picker from gnome-color-manager"
hide_app gcm-import             "imports color profiles"
hide_app vim                    "the editor is neovim; vim stays for the vi command used by scripts"

# KDE Connect: most of the work is done by the phone-connect plugin on the
# noctalia bar, pairing included (the panel shows Pair next to the devices
# seen on the network). The real window stays in the menu though: it is the
# only way to reach the per-device settings, the plugins and the phone file
# browser, which the bar does not expose.
hide_app org.kde.kdeconnect.nonplasma "indicator for non-Plasma desktops: the bar already does this"
hide_app org.kde.kdeconnect.sms       "SMS are sent from the phone-connect panel"

# Viewers: they remain the default programs for images and PDFs, so they open
# with a double click from nautilus. They are not needed in the menu: that is
# not where you start from, you always start from the file.
hide_app org.gnome.Loupe  "image viewer: opened from the file, not from the menu"
hide_app org.gnome.Papers "PDF viewer: opened from the file, not from the menu"

# hwloc: draws the CPU and memory topology. It comes in as a dependency (used
# by pipewire), it is not a program to open from the menu; from the command
# line `lstopo` remains.
hide_app lstopo "hardware topology map, a command-line tool"

# nvtop: the GPU `top`, it comes in as a dependency of mission-center, which is
# the interface I actually use. The `nvtop` command remains in the terminal.
hide_app nvtop "terminal GPU monitor: the window is mission-center"

# archive manager: always opened from nautilus, with "Extract here" or a double
# click on a zip. It remains the default program for archives.
hide_app org.gnome.FileRoller "archive manager: opened from the file, not from the menu"


# eos-update: opens a terminal to do what I do by hand when I feel like it,
# with a 60-second countdown at the end.
hide_app eos-update "EndeavourOS update: I run it from the terminal"

# GParted: same precedence, but here it is not hidden, the command is
# replaced. .desktop files expand neither ~ nor environment variables, so the
# launcher goes through sh to expand $HOME (this keeps the file portable).
if [ -f /usr/share/applications/gparted.desktop ]; then
cat > gparted.desktop <<EOF
[Desktop Entry]
# launched through gparted-wayland: see the comments in that script
Type=Application
Name=$(grep -m1 '^Name=' /usr/share/applications/gparted.desktop | cut -d= -f2-)
Comment=$(grep -m1 '^Comment=' /usr/share/applications/gparted.desktop | cut -d= -f2-)
Exec=sh -c "exec \"\\\\\$HOME/.local/share/applications/gparted-wayland\" \"\\\\\$@\"" sh %f
Icon=$(grep -m1 '^Icon=' /usr/share/applications/gparted.desktop | cut -d= -f2-)
Categories=System;Filesystem;
Keywords=Partition;Partitions;Disk;
Terminal=false
StartupNotify=true
EOF
fi
