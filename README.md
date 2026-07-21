# Huion KD100 Linux Driver
A simple driver for the Huion KD100 Mini Keydial written in C to give the device some usability while waiting for Huion to fix their Linux drivers. Each button can be configured to either act as a key/multiple keys or to execute a program/command

> **Fork note (clusterrace):** this fork patches device selection so the KD100
> can be used on a machine that *also* has a Huion **GT2401 pen display** — both
> enumerate as USB `256c:006d`. See **[`HUION_GT2401_COEXIST.md`](HUION_GT2401_COEXIST.md)**
> for the full story, the coexistence gotchas, and setup scripts in
> [`contrib/linux-huion-coexist/`](contrib/linux-huion-coexist/).

> **_NOTICE:_**  When updating from **v1.31** or below, make sure you updated your config file to follow the new format shown in the default config file

Pre-Installation
------------
Arch Linux/Manjaro:
```
sudo pacman -S libusb-1.0 xdotool
```
Ubuntu/Debian/Pop OS:
```
sudo apt-get install libusb-1.0-0-dev xdotool
```
> **_NOTE:_**  Some distros label libusb as "libusb-1.0-0" and others might require the separate "libusb-1.0-dev" package

Installation
------------
You can either download the latest release or run the following:
```
git clone https://github.com/mckset/KD100.git
cd KD100
make
```

> Running make as root will install the driver as a command and create a folder in ~/.config to store config files

Usage
-----
```
sudo ./KD100 [options]
```
**-a**  Assume that the first device that matches the vid and pid is the keydial (skips prompt to select a device)

**-c**  Specify a config file to use after the flag (./default.cfg or ~/.config/KD100/default.cfg is used normally)

**-d**  Enable debug output (can be used twice to output the full packet of data recieved from the device)

**-dry**  Display data sent from the keydial and ignore events

**-h**  Displays a help message

Configuring
----------
Edit or copy **default.cfg** to add your own keys/commands and use the **-c** flag to specify the location of the config file. New config files do not need to end in ".cfg". If the config file is not found in the current directory, the driver while look for it in ~/.config/KD100/

Each button is set with a `type:` and a `function:`. See **default.cfg** for the full list; in brief: `0` = key/combo, `1` = run a command, `2` = mouse button, and (**clusterrace fork**) `3` = sticky modifier — see Known Issues below.

> **Config parser gotcha:** the file is parsed line-by-line and *any* line containing the capitalized word `Button N`, or the substrings `type:` / `function:`, is treated as a definition — **even inside a `//` comment**. Avoid those strings in comment text or they will hijack the button currently being defined.

Caveats
-------
- Because the driver relies on xdotool, it only works on X11 desktops but it can be patched for wayland desktops by altering the "handler" function
- You do not need to run this with sudo if you set a udev rule for the device. Create/edit a rule file in /etc/udev/rules.d/ and add the following:
```
SUBSYSTEM=="usb",ATTRS{idVendor}=="256c",ATTRS{idProduct}=="006d",MODE="0666"
```
Save and then reboot or reload your udev rules with:
```
sudo udevadm control --reload
sudo udevadm trigger
```
> **_NOTE:_**  Some systems might require you to run "sudo udevadm trigger" on boot 

- Technically speaking, this can support other devices, especially if they send the same type of byte information, otherwise the code should be easy enough to edit and add support for other usb devices. If you want to see the information sent by different devices, change the vid and pid in the program and run it with the **-dry** flag

Tested Distros
--------------
- Arch linux
- Manjaro
- Ubuntu
- Pop OS

Known Issues
------------
- Setting shortcuts like "ctrl+c" will close the driver if it ran from a terminal and it's active
- **The keydial reports only one button at a time (hardware limit).** Holding one button and pressing a second does not produce a chord — the device drops the first button from its report the moment the second is pressed (verified by capturing raw USB packets). So a live two-button combo such as `Shift`+middle-click (Blender's pan) is impossible by physically holding two device buttons, and no change to the driver's packet decoding can recover it.
  - **Workaround (clusterrace fork): sticky modifiers (`type: 3`).** A `type: 3` button latches its key down in software on the first tap and releases it on the next tap, so the modifier stays pressed while you hold a *different* button (or drag the pen) with the same hand. Example for Blender panning: set the Shift button to `type: 3`, tap it to latch Shift on, then hold a `type: 2` `mouse2` button and drag the pen — the app sees `Shift`+MMB. Tap Shift again to release. (A latched modifier stays active until tapped off, so it affects all input meanwhile.) See [`contrib/blender.cfg`](contrib/blender.cfg) for a working example.
