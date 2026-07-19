# Running a KD100 keydial next to a Huion GT2401 pen display on Linux

This fork patches [mckset/KD100](https://github.com/mckset/KD100) to work on a
machine that has **both** a Huion **GT2401 pen display** and a Huion **KD100
mini keydial** connected at the same time, on **Linux Mint / X11**.

It documents the whole journey: the root cause, the code patch, the udev rules,
the button/mouse/scroll mapping, and — most importantly — the **gotchas** around
making the keydial coexist with Huion's proprietary driver (which drives the pen
display). If you only have a KD100 and no Huion pen display, you probably don't
need any of the coexistence machinery; just build and run the patched driver.

> Everything here was worked out on one specific machine. Paths
> (`/home/<user>/...`), the USB **port** (`1-13.4`), and the assumption of a
> single GT2401 + single KD100 are environment-specific. Adjust before reuse.

---

## TL;DR

- The GT2401 pen display and the KD100 keydial **both enumerate as USB
  `256c:006d`**. Huion's driver can only bind one of them and keeps grabbing the
  keydial, which breaks the keydial *and* makes the pen-display settings UI
  refresh in a loop.
- Fix: let Huion keep the **pen display**, and hand the **keydial** to this
  patched mckset/KD100 driver.
- The patch makes device-matching pick the keydial by its **product string**
  instead of the shared `256c:006d`, because on this unit the keydial reports an
  **empty** product string while the display reports `Huion Tablet_GT2401`.
- Biggest gotcha: **you cannot run Huion's driver and this driver against the
  keydial at the same time**, and **de-authorizing the USB port does NOT hide
  the keydial from Huion** (Huion enumerates via libusb, which still sees a
  de-authorized device). Only a real unplug / USB driver *unbind* hides it.

---

## The problem

```
$ lsusb | grep -i 256c
Bus 001 Device 014: ID 256c:006d  Huion Tablet_GT2401     <- pen display  (port 1-13.2)
Bus 001 Device 0xx: ID 256c:006d                          <- KD100 keydial (port 1-13.4)
```

Both devices share vendor:product `256c:006d`. Symptoms with Huion's official
driver (`/usr/lib/huiontablet`, v15.0.0.175) and both devices plugged in:

- The pen-display settings tab **refreshes in a loop**; you cannot change
  settings. In `~/.huion.log` this shows as a repeating
  `on_screen_changed huion_reload_uhid_pen_event` / `Wrong size written to uhid`
  cycle.
- The keydial cannot be configured (newer Huion drivers also ship **no KD100
  profile**).

Root cause: Huion's driver keys on the USB id, can't tell the two `256c:006d`
devices apart, and keeps opening/closing the keydial's HID path — which detaches
the kernel driver and triggers the reload loop.

---

## The code patch

Upstream mckset/KD100 matches the device purely on `vid == 0x256c &&
pid == 0x006d` and, with `-a`, grabs the **first** match — which may be the pen
display. Its product-string check existed only in the *root* code path.

This fork (`KD100.c`) changes device selection so it **always** verifies the USB
product string, root or not:

- The GT2401 pen display reliably reports `Huion Tablet_GT2401`.
- The KD100 keydial reports either `Huion Tablet_KD100` **or (on this unit) an
  empty string**. So: accept empty / `Huion Tablet_KD100`, reject the display.
- Also fixed the `-a` bail-out (`Found device does not appear to be the keydial`)
  that made the driver quit if the pen display happened to enumerate *before*
  the keydial; it now keeps looking / waiting instead.

Net effect: with `-a`, the driver deterministically claims the keydial and never
grabs the GT2401, so it can run as a non-interactive login service.

---

## Build & install (keydial driver)

Dependencies (Debian/Ubuntu/Mint):

```sh
sudo apt-get install -y libusb-1.0-0-dev xdotool
```

Build:

```sh
gcc KD100.c -lusb-1.0 -o ~/.local/bin/KD100
```

udev rule so it can open the device **without root** — `contrib/.../50-huion-kd100.rules`:

```
SUBSYSTEM=="usb",ATTRS{idVendor}=="256c",ATTRS{idProduct}=="006d",MODE="0666"
```

```sh
sudo cp contrib/linux-huion-coexist/50-huion-kd100.rules /etc/udev/rules.d/
sudo udevadm control --reload && sudo udevadm trigger
```

Config: copy `default.cfg` to `~/.config/KD100/default.cfg` and edit (see
mapping below).

Run / verify:

```sh
~/.local/bin/KD100 -a            # normal
~/.local/bin/KD100 -a -dry -d    # print raw packets without injecting input
```

---

## Button / mouse / scroll mapping

Config lives at `~/.config/KD100/default.cfg`. Each button is three lines:
`// Button N`, `type:`, `function:`. Physical numbering:

```
| 0 | 1 | 2 | 3 |
| 4 | 5 | 6 | 7 |
| 8 | 9 | 10| 11|
| 12| 13| 14|   |
|  16   | 17| 15|     dial press = Button 18, plus dial rotation (Wheel section)
```

| `type:` | Action        | `function:` examples                          |
|---------|---------------|-----------------------------------------------|
| `0`     | key / combo   | `a`, `space`, `ctrl+c`, `ctrl+shift+z`        |
| `1`     | run a command | `krita`, `firefox`, `/path/to/script.sh`, `swap` |
| `2`     | mouse button  | `mouse1`..`mouse5`                             |

Mouse functions (type 2): `mouse1`=left, `mouse2`=middle, `mouse3`=right,
`mouse4`=**scroll up**, `mouse5`=**scroll down**. Example — button 4 = left
click, button 6 = scroll up:

```
// Button 4
type: 2
function: mouse1
// Button 6
type: 2
function: mouse4
```

Key names for type 0 are X keysyms (`space`, `Return`, `Prior`/`Next` for
PageUp/Down, `bracketleft`, `KP_Add`, ...). Find any with `xev`.

**Dial rotation limitation:** the `Wheel` section (clockwise / counter-clockwise)
can only send **keys** — the driver forces `xdotool key` for wheel events, so
`mouse4`/`mouse5` scrolling does **not** work there. Making the dial scroll the
mouse wheel requires a small patch to have wheel events use `xdotool click 4/5`.

Reload after editing the config:

```sh
killall KD100     # a running supervisor relaunches it with the new config
```

**Example config:** [`contrib/blender.cfg`](contrib/blender.cfg) is a
ready-to-use layout for Blender modelling + sculpting (hold-modifiers for
smooth/invert while stroking with the pen, dual-purpose keys that work in both
Edit and Sculpt mode, zoom on the dial).

**Calibrating your device's button numbers.** The physical position → button
index map can differ per unit, so verify it rather than trusting the ASCII
diagram. Run `KD100 -a -dry -d`, press each physical button in reading order,
and decode the raw `DATA:` packets (`-dry` zeroes the `Keycode:` line, so read
the packet bytes): buttons live in `data[4]` (indices 0–7), `data[5]` (8–15),
`data[6]` (16–18) with `data[1]==224`; the dial sends `data[1]==241` with
`data[5]` = 1 (CW) / 2 (CCW). On the machine this was built for, reading order
mapped cleanly to indices 0–17, i.e. it matches the diagram.

---

## Coexisting with Huion's driver — the hard part

Keep Huion for the **pen display**, use this driver for the **keydial**. That
turns out to be surprisingly fragile. Everything below was learned the hard way.

### Gotcha 1 — one device at a time
Huion's `huionCore` can only bind **one** `256c:006d` device, it **continuously
re-scans**, and it **prefers the keydial**. If the keydial is visible whenever
Huion scans, Huion grabs it and then fails to serve the display (its UI shows
"cannot find pen display"), or loops.

### Gotcha 2 — `DEVICE IS ALREADY IN USE`
This driver uses libusb and claims the keydial's interfaces. If Huion grabbed
the keydial first, this driver's `interrupt_transfer` fails and it prints
`DEVICE IS ALREADY IN USE` and exits. Only one of them can own the keydial.

### Gotcha 3 (the big one) — de-authorize does NOT hide the device
The intuitive trick "de-authorize the keydial's USB port so Huion can't see it"
**does not work**:

```sh
echo 0 > /sys/bus/usb/devices/1-13.4/authorized   # NOT enough
```

Huion enumerates through **libusb**, which still reads a de-authorized device's
descriptors, so Huion finds the keydial anyway (seen in `~/.huion.log` as
`hid_open_path(0001:00XX:00)` against the keydial). We built an automated
"authorized dance" around this and it **failed** for exactly this reason. Only a
**real removal** hides the keydial from Huion:

- physically unplug it, or
- soft-unplug via the USB driver:
  ```sh
  echo 1-13.4 | sudo tee /sys/bus/usb/drivers/usb/unbind   # remove
  echo 1-13.4 | sudo tee /sys/bus/usb/drivers/usb/bind     # bring back
  ```

### The sequence that works
1. Keydial **physically unplugged**.
2. Start Huion → it binds the **pen display** alone.
3. **Plug the keydial back in.**
4. This driver (already running and waiting) claims the keydial. Huion makes one
   failed open attempt and stays on the display.

> **Physical unplug/replug is the reliable method.** The USB soft-unplug
> (`echo 1-13.4 > /sys/bus/usb/drivers/usb/unbind` / `bind`) was tested on this
> hardware and did **not** reliably reproduce a real unplug, so
> `contrib/linux-huion-coexist/kd100-setup.sh` (which uses it) is unreliable
> here. Prefer the manual unplug/replug below.

### Recommended setup: autostart the driver, replug by hand
Run the keydial driver at login so it is always waiting, and just replug the
keydial once Huion has the display:

1. Install `kd100-supervisor.sh` to `~/.local/bin/` and the autostart entry:
   ```sh
   cp contrib/linux-huion-coexist/kd100-supervisor.sh ~/.local/bin/ && chmod +x ~/.local/bin/kd100-supervisor.sh
   cp contrib/linux-huion-coexist/kd100.desktop ~/.config/autostart/
   ```
   The `.desktop` ships with `X-GNOME-Autostart-enabled=true`. To disable later,
   set it to `false` (or add `Hidden=true`); to re-enable, set it back to `true`
   and remove any `Hidden=true` line.
2. **Boot with the keydial unplugged** (or unplug it if Huion fails to find the
   display). Huion binds the pen display; the supervisor starts and waits.
3. Once the display is recognised, **plug the keydial in** — the supervisor
   claims it. Huion, already committed to the display, leaves it alone.

The supervisor just runs `KD100 -a -c ~/.config/KD100/blender.cfg` in a restart
loop (no USB "dance"); it also re-grabs the keydial after the flaky unit drops.

### What did NOT work
- Starting this driver *before* Huion so it grabs the keydial first — Huion
  still fixates on the (held) keydial and fails to bind the display.
- The `authorized` de-authorize/re-authorize "dance" — see Gotcha 3. The
  `51-huion-kd100-authorized.rules` file is kept only as a record of that dead
  end; it is **not** needed.

### Fully deterministic alternative (no dance)
Drop Huion's driver entirely and run the GT2401 on the **in-kernel `uclogic` /
DIGImend** driver (the GT2401 exposes a native `Huion Tablet_GT2401 Stylus`
input device with pressure/tilt), keeping this driver for the keydial. You lose
Huion's GUI (pressure curve, on-screen express keys) and map the pen to the
correct monitor with `xinput map-to-output`, but there is no ordering game and
it is reboot-proof.

---

## Other notes

- **X11 only** — mapping uses `xdotool`. Wayland needs the `Handler()` function
  rewritten.
- **Flaky USB** — this KD100 unit intermittently drops off USB
  (`usb 1-13.4: USB disconnect`). `kd100-supervisor.sh` restarts the driver when
  it reconnects. If it happens a lot, suspect the cable/hub, not software.
- **Port dependency** — the coexistence scripts hardcode port `1-13.4`. If you
  move the keydial to another port, update the scripts (find it with
  `lsusb`/`/sys/bus/usb/devices/*/product`).

See `contrib/linux-huion-coexist/` for the actual scripts, udev rules, and the
autostart entry.
