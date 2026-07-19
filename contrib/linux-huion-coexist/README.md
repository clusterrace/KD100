# contrib/linux-huion-coexist

Setup artifacts for running the KD100 keydial alongside a Huion GT2401 pen
display. Full background and gotchas: [`../../HUION_GT2401_COEXIST.md`](../../HUION_GT2401_COEXIST.md).

> These are copied verbatim from a working machine. They hardcode `$HOME`
> paths and the keydial's USB **port `1-13.4`**. Adjust for your system before
> using (find your port with `lsusb` and `/sys/bus/usb/devices/*/product`).

| File | Purpose |
|------|---------|
| `50-huion-kd100.rules` | udev: `MODE=0666` on `256c:006d` so the driver opens the keydial without root. **Required.** → `/etc/udev/rules.d/` |
| `kd100-supervisor.sh` | Runs `KD100 -a` and restarts it if the (flaky) keydial drops. → `~/.local/bin/` |
| `kd100-setup.sh` | On-demand: stop Huion+driver, **soft-unplug** the keydial (USB unbind, needs sudo), start Huion so it binds the display alone, start the driver, then soft-replug the keydial so the driver claims it. Run once per session. → `~/.local/bin/` |
| `kd100.desktop` | Optional login autostart for the supervisor. Shipped **disabled** (`Hidden=true`) — the setup above is manual. → `~/.config/autostart/` |
| `51-huion-kd100-authorized.rules` | **Dead end, kept as a record.** Makes the port's `authorized` flag writable for a de-authorize "dance" that does **not** work (Huion still sees the keydial via libusb). Not needed. |

## Quick start (keydial only, no pen display)

```sh
sudo apt-get install -y libusb-1.0-0-dev xdotool
gcc ../../KD100.c -lusb-1.0 -o ~/.local/bin/KD100
sudo cp 50-huion-kd100.rules /etc/udev/rules.d/ && sudo udevadm control --reload && sudo udevadm trigger
mkdir -p ~/.config/KD100 && cp ../../default.cfg ~/.config/KD100/
~/.local/bin/KD100 -a
```

## With a Huion GT2401 pen display (coexistence)

```sh
cp kd100-supervisor.sh kd100-setup.sh ~/.local/bin/ && chmod +x ~/.local/bin/kd100-*.sh
# edit the PORT / paths in the scripts to match your machine, then per session:
~/.local/bin/kd100-setup.sh      # prompts for sudo (USB soft-unplug)
```
