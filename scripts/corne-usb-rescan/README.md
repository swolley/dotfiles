# corne-usb-rescan

Works around a firmware problem on the ZenBook: at the first cold boot of the
day the Corne keyboard (`6401:45d4`, serial `vial:f64c2b3c`) is never
enumerated. The kernel logs nothing whatsoever on its port, not even a failed
attempt, so the device is not answering, or the port is not being looked at.
Unplugging and plugging it back in brings it up cleanly every time, and power
cycles a few minutes apart are fine too: only the first boot after a night
fails.

USB has no per-port rescan in sysfs, unlike PCI and SCSI. The only thing that
makes the controller enumerate again is detaching and reattaching its driver,
which is what the script does, writing the controller address to
`/sys/bus/pci/drivers/xhci_hcd/{unbind,bind}`.

It first checks whether the keyboard is present and exits without touching
anything when it is, so a normal boot is unaffected. When it does act, every
other USB device drops for two seconds as well, the dock included; it runs
after `multi-user.target`, before the graphical session, so nobody notices.

The installer copies the script to `/usr/local/bin/corne-usb-rescan` and the
unit to `/etc/systemd/system/`, then enables it. The unit has a
`ConditionPathExists` on the controller, so on another machine it is skipped
instead of failing.

Should the keyboard be repaired or replaced, delete the two files, disable the
unit and drop `configure_corne_usb_rescan` from `setup-machine.sh`.
