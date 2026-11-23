# keymaps

Layouts of the programmable keyboards, one file per keyboard, exported from the
software that flashes them:

- `corne.vil` — Corne `DH747 BCORNE` (`6401:45d4`, serial `vial:f64c2b3c`),
  exported from Vial: layers, tap dances, combos, key overrides, macros and the
  QMK settings Vial exposes.

These are backups, not configuration files anything reads. A layout lives in
the keyboard's own memory and the flashing tool writes it there over USB;
nothing on this machine loads these files at login or at boot. They are here so
that a reflash, a firmware update or a second keyboard does not mean rebuilding
a layout by hand.

To restore a `.vil`, open Vial and use *Load saved layout* on the file, then
*Save + Reboot*. The keyboard keeps the layout afterwards, on any machine.

After changing something on the keyboard, export it from Vial (*Save current
layout*) straight onto the file here: its save dialog takes a path, and there
is no copy of these layouts anywhere else, so the repo is the only place they
are kept. Then reindent it with tabs, which is what makes the diff show the
change instead of the whole file, because Vial writes everything on few long
lines:

    ./update.sh

With no argument it goes over every `.vil` in the folder; pass a name to do
just one. Earlier versions are in the git history, which is why no copies of
them are kept here.
