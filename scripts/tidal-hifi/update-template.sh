#!/bin/sh
# Copies the tidal-hifi settings in use back into the template, dropping the
# two fields that change on their own. Run it after changing something in the
# application settings that is worth keeping.
set -eu
cd "$(dirname "$0")"
src="${XDG_CONFIG_HOME:-$HOME/.config}/tidal-hifi/config.json"
[ -f "$src" ] || { echo "$src not found" >&2; exit 1; }
python3 - "$src" <<'PY'
import collections, json, sys
d = json.load(open(sys.argv[1]), object_pairs_hook=collections.OrderedDict)
for k in ("windowBounds", "__internal__"):
    d.pop(k, None)
if d.get("ListenBrainz", {}).get("token"):
    d["ListenBrainz"]["token"] = ""
    print("the ListenBrainz token does not go in the repo: emptied", file=sys.stderr)
open("config.json", "w", encoding="utf-8").write(
    json.dumps(d, indent="\t", ensure_ascii=False) + "\n")
PY
echo "template updated"
