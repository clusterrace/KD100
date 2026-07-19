#!/bin/sh
# Manual, on-demand setup for the Huion GT2401 pen display + KD100 keydial.
#
# They share USB id 256c:006d and Huion's driver can only bind one, preferring
# the keydial. This reproduces the known-good "unplug the keydial, let Huion
# grab the display, plug the keydial back for mckset" sequence — automatically,
# using a real USB soft-unplug (driver unbind) rather than the `authorized`
# toggle (which does NOT hide the device from Huion's libusb enumeration).
#
# Run it in a terminal after login:  kd100-setup.sh
# Needs sudo (for the USB unbind/bind); it will prompt for your password.

set -e
export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"
PORT=1-13.4
UNBIND=/sys/bus/usb/drivers/usb/unbind
BIND=/sys/bus/usb/drivers/usb/bind

echo "==> Stopping Huion + keydial driver..."
killall KD100 kd100-supervisor.sh huionCore huiontablet 2>/dev/null || true
sleep 2

echo "==> Soft-unplugging the keydial (port $PORT) so Huion can't see it..."
echo "$PORT" | sudo tee "$UNBIND" >/dev/null
sleep 1

echo "==> Starting Huion; it will bind the pen display alone..."
( cd "$HOME" && env DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" \
    /usr/lib/huiontablet/huiontablet.sh ) >/dev/null 2>&1 &
echo "    waiting for Huion to bind the display..."
sleep 12

echo "==> Starting the keydial driver (mckset), then re-plugging the keydial..."
nohup "$HOME/.local/bin/kd100-supervisor.sh" >/dev/null 2>&1 &
sleep 1
echo "$PORT" | sudo tee "$BIND" >/dev/null
sleep 2

echo "==> Done."
echo "    - Pen display should now work under Huion."
echo "    - Keydial should be on mckset (test a button in a text editor)."
echo "    Check keydial driver log: tail -f ~/.local/share/kd100.log"
