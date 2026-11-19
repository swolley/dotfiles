# tidal-hifi settings

`config.json` here is the template, not the file in use.

tidal-hifi saves its settings through electron-store, which writes a
temporary file and then renames it over the target. A rename replaces a
symlink with a real file, so this directory cannot be a stow package: at the
first settings change the link would break silently and the repo would fall
behind without anyone noticing. kdeglobals became a noctalia template for
the same reason.

`configure_tidal` in `setup-machine.sh` copies this file to
`~/.config/tidal-hifi/config.json` only when nothing is there yet: a new
machine starts from the right settings, a running one does not get its own
overwritten.

Two fields stay out of the template because they change on their own and say
nothing to whoever is installing: `windowBounds`, the window geometry, and
`__internal__`, the version electron-store uses to track its own migrations.

To refresh the template from the settings in use:

    ./scripts/tidal-hifi/update-template.sh
