#!/bin/sh
# Accende/spegne i temi scritti dai template noctalia a seconda della sessione.
#   theme-session.sh gnome  -> GTK e Obsidian tornano ai temi di GNOME
#   theme-session.sh niri   -> riattiva i temi noctalia
mode="$1"
IMPORT='@import url("noctalia.css");'

for d in "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"; do
  css="$d/gtk.css"
  [ -f "$d/noctalia.css" ] || continue
  case "$mode" in
    gnome) [ -f "$css" ] && sed -i '\|^@import url("noctalia.css");$|d' "$css" ;;
    niri)  grep -qxF "$IMPORT" "$css" 2>/dev/null || { printf '%s\n' "$IMPORT" | cat - "$css" 2>/dev/null > "$css.tmp"; mv "$css.tmp" "$css"; } ;;
  esac
done

find "$HOME" -maxdepth 4 -name .obsidian -type d 2>/dev/null | while read -r o; do
  [ -f "$o/snippets/noctalia.css" ] && [ -f "$o/appearance.json" ] || continue
  python3 - "$o/appearance.json" "$mode" <<'PY'
import json, sys
path, mode = sys.argv[1], sys.argv[2]
d = json.load(open(path))
s = d.get("enabledCssSnippets", [])
if mode == "gnome" and "noctalia" in s:
    s.remove("noctalia")
elif mode == "niri" and "noctalia" not in s:
    s.append("noctalia")
else:
    sys.exit(0)
d["enabledCssSnippets"] = s
with open(path, "w") as f:
    json.dump(d, f, indent=2); f.write("\n")
PY
done
