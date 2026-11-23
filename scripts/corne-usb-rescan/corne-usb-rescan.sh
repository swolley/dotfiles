#!/bin/sh
# The Corne keyboard is not enumerated at the first cold boot of the day: the
# kernel logs nothing at all on its port, not even a failed attempt, and a
# manual unplug/replug brings it up cleanly. Power cycles close together are
# fine, so what the firmware leaves behind after a night is the variable.
#
# There is no way to ask USB to rescan a single port from sysfs, the way PCI or
# SCSI allow: the only thing that makes the controller look again is detaching
# and reattaching its driver. That is what this does, and only when the
# keyboard is really missing, so that on a normal boot nothing is touched.
set -eu

VID=6401          # Corne "DH747 BCORNE", serial vial:f64c2b3c
PID=45d4
XHCI=0000:00:14.0 # internal xHCI controller, the one the two USB-C ports hang off

keyboard_present() {
  for f in /sys/bus/usb/devices/*/idVendor; do
    [ -r "$f" ] || continue
    [ "$(cat "$f")" = "$VID" ] || continue
    [ "$(cat "${f%idVendor}idProduct" 2>/dev/null)" = "$PID" ] && return 0
  done
  return 1
}

keyboard_present && exit 0

# No controller, nothing to do: this machine is not the ZenBook, or the id has
# changed. Not an error, the service runs on every boot.
[ -e "/sys/bus/pci/devices/$XHCI" ] || exit 0

echo "keyboard $VID:$PID missing, rebinding $XHCI"
# Everything else on USB goes away for these two seconds as well, the dock
# included. At boot, before the session is up, that costs nothing.
echo "$XHCI" > /sys/bus/pci/drivers/xhci_hcd/unbind
sleep 2
echo "$XHCI" > /sys/bus/pci/drivers/xhci_hcd/bind

# Enumeration takes a moment; give it ten seconds before calling it a failure.
i=0
while [ "$i" -lt 10 ]; do
  keyboard_present && { echo "keyboard back"; exit 0; }
  sleep 1
  i=$((i + 1))
done

echo "keyboard $VID:$PID still absent after rebinding $XHCI" >&2
exit 1
