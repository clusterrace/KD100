#!/bin/sh
# Runs the patched mckset KD100 driver and restarts it if the (flaky) keydial
# drops off USB. No device "dance" here — orchestration lives in
# ~/.local/bin/kd100-setup.sh, which is run manually.

export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"

BIN="$HOME/.local/bin/KD100"
LOG="$HOME/.local/share/kd100.log"
mkdir -p "$(dirname "$LOG")"

# Don't start a second supervisor if one is already running.
for pid in $(pgrep -f kd100-supervisor.sh); do
    [ "$pid" = "$$" ] || [ "$pid" = "$PPID" ] || exit 0
done

CFG="$HOME/.config/KD100/blender.cfg"   # active mapping (see also default.cfg)

while true; do
    echo "$(date '+%F %T') starting KD100 driver ($CFG)" >> "$LOG"
    "$BIN" -a -c "$CFG" >> "$LOG" 2>&1
    echo "$(date '+%F %T') KD100 driver exited ($?); retrying in 3s" >> "$LOG"
    sleep 3
done
