# KlangLadder

KlangLadder is a macOS menu bar app that picks your default audio devices for you.

You rank your devices once: one list for output (speakers, headphones) and one for input (microphones). When a device connects or disconnects, KlangLadder switches to the highest-ranked device that is connected.

macOS picks the default device on its own. It often jumps to whatever you just plugged in, and it doesn't remember your preferences. KlangLadder fixes this.

## What it does

- **Switches when a better device connects.** If a device with a higher rank than the current one connects, KlangLadder makes it the default.
- **Undoes unwanted switches.** If macOS switches to a newly connected device that ranks lower, KlangLadder switches back.
- **Falls back when a device disconnects.** If the active device disconnects, KlangLadder picks the best device still connected.
- **Respects your manual choice.** If you pick a device in System Settings or Control Center, KlangLadder keeps it until the next connect or disconnect.
- **Applies your ranking once per login.** On the first start after you log in, KlangLadder switches to your best connected device. A restart later in the same session doesn't override your choice.
- **Remembers disconnected devices.** They stay in the list, dimmed, so their rank is kept for next time.
- **Lets you disable devices.** Disabled devices, like virtual devices from Zoom or Teams, are never chosen by KlangLadder. If only disabled devices are connected, macOS decides.

KlangLadder reacts to system events. It does not poll, and it needs no special permissions.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode or the Xcode Command Line Tools with Swift 5.10 or later

## Install

For now, KlangLadder is installed by building it from source. A Homebrew tap and GitHub releases are planned.

```sh
git clone https://github.com/janthoXO/KlangLadder.git
cd KlangLadder
./bundle.sh
cp -R build/KlangLadder.app ~/Applications/
open ~/Applications/KlangLadder.app
```

The app appears as a speaker icon in the menu bar. It has no Dock icon.

A locally built app is not quarantined, so macOS should open it without a Gatekeeper prompt.

On its first run, KlangLadder puts your current default device at the top of each list. It doesn't switch your audio until you change the order.

### Raycast

The extension in [`raycast/`](raycast/) adds an "Open KlangLadder" command to Raycast. It requires the app to already be installed; it does not bundle it. To load it locally:

```sh
cd raycast && npm install && npm run dev
```

## Use

Click the menu bar icon to open the popover.

- **Output / Input tabs:** each tab has its own priority list. The popover opens on the tab you used last.
- **Make a device active:** click a connected device.
- **Change the ranking:** drag a device up or down. The device at the top is number 1.
- **More actions:** right-click a device, or hover over it and click the **…** button.
  - Move to Top / Move to Bottom
  - Disable: moves the device to the Disabled list
  - Enable (in the Disabled list): adds the device to the bottom of the priority list
  - Delete: only for disconnected devices. You can also use the trash button that appears on hover.
- **Disabled list:** collapsed below the priority list. It opens by itself when the active device is disabled. Click it to expand or collapse it.
- **Launch at login:** turn on the toggle at the bottom of the popover.
- **Quit:** click **Quit**.

The active device has a checkmark and a highlighted row. Disconnected devices are dimmed. Hover over a device to see its connection type, when it was last seen and its ID.

Reordering, disabling, enabling and deleting never switch devices by themselves. They take effect on the next connect or disconnect.

### Tips

- New devices join the **bottom** of the priority list. Move them up if they should win.
- Bluetooth headsets (for example AirPods) used as a **microphone** force a low-quality call profile, so music sounds worse too. Consider disabling them in the Input tab.
- Virtual devices (BlackHole, Zoom, Teams, Loopback) are good candidates for the Disabled list.

### Open from other apps

`open klangladder://open` opens the popover. KlangLadder starts first if it isn't running.

## Uninstall

1. Turn off **Launch at login** in the popover, then click **Quit**.
2. Delete `~/Applications/KlangLadder.app`.
3. Optionally, delete your settings: `~/Library/Application Support/KlangLadder`.

## Development

See [README_DEV.md](README_DEV.md).
