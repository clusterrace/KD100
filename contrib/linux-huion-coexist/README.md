# contrib/linux-huion-coexist

Setup artifacts for running the KD100 keydial alongside a Huion GT2401 pen
display. Full background and gotchas: [`../../HUION_GT2401_COEXIST.md`](../../HUION_GT2401_COEXIST.md).

> These are copied verbatim from a working machine. They hardcode `$HOME`
> paths and the keydial's USB **port `1-13.4`**. Adjust for your system before
> using (find your port with `lsusb` and `/sys/bus/usb/devices/*/product`).

| File | Purpose |
|------|---------|
| `50-huion-kd100.rules` | udev: `MODE=0666` on `256c:006d` so the driver opens the keydial without root. **Required.** → `/etc/udev/rules.d/` |
| `kd100-supervisor.sh` | Runs `KD100 -a -c ~/.config/KD100/blender.cfg` and restarts it if the (flaky) keydial drops. → `~/.local/bin/` |
| `kd100.desktop` | Login autostart for the supervisor. Ships **enabled** (`X-GNOME-Autostart-enabled=true`). → `~/.config/autostart/` |
| `kd100-setup.sh` | **Unreliable on the original hardware** — automates the sequence with a USB *soft-unplug* (`unbind`/`bind`, needs sudo) that did not behave like a real unplug here. Prefer autostart + a physical replug. → `~/.local/bin/` |
| `51-huion-kd100-authorized.rules` | **Dead end, kept as a record.** Makes the port's `authorized` flag writable for a de-authorize "dance" that does **not** work (Huion still sees the keydial via libusb). Not needed. |

The `kd100-supervisor.sh` here launches with `-c ~/.config/KD100/blender.cfg`
(the [example Blender layout](../blender.cfg)); edit that line for your own config.

## Quick start (keydial only, no pen display)

```sh
sudo apt-get install -y libusb-1.0-0-dev xdotool
gcc ../../KD100.c -lusb-1.0 -o ~/.local/bin/KD100
sudo cp 50-huion-kd100.rules /etc/udev/rules.d/ && sudo udevadm control --reload && sudo udevadm trigger
mkdir -p ~/.config/KD100 && cp ../../default.cfg ~/.config/KD100/
~/.local/bin/KD100 -a
```

## With a Huion GT2401 pen display (coexistence)

Autostart the driver, then replug the keydial by hand each session:

```sh
cp kd100-supervisor.sh ~/.local/bin/ && chmod +x ~/.local/bin/kd100-supervisor.sh
cp kd100.desktop ~/.config/autostart/       # ships enabled
```
Then per boot: start with the keydial unplugged so Huion binds the pen display,
and once it does, **plug the keydial in** — the waiting supervisor claims it.
See [`../../HUION_GT2401_COEXIST.md`](../../HUION_GT2401_COEXIST.md) for details.
