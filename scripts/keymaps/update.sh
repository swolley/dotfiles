#!/bin/sh
# Reindents the layouts in this folder with tabs, so that the diff of an export
# shows what really changed instead of the whole file: Vial writes everything
# on few long lines.
#
#   ./update.sh            every .vil here
#   ./update.sh corne.vil  only that one
#
# Vial exports straight onto these files (its save dialog takes a path), so the
# normal round is: export over the file, run this, commit. There is no copy of
# them outside the repo.
set -eu
cd "$(dirname "$0")"
if [ "$#" -gt 0 ]; then
  set -- "$@"
else
  set -- *.vil
fi
for f in "$@"; do
  [ -f "$f" ] || { echo "$f not found" >&2; exit 1; }
  python3 -I - "$f" <<'PY'
import collections, json, sys
p = sys.argv[1]
d = json.load(open(p), object_pairs_hook=collections.OrderedDict)
open(p, "w", encoding="utf-8").write(
    json.dumps(d, indent="\t", ensure_ascii=False) + "\n")
PY
  echo "$f reformatted"
done
