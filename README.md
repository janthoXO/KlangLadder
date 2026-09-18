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

### Homebrew

The formula builds KlangLadder on your machine, so it needs the Xcode Command Line Tools. It builds the latest release. Add `--HEAD` to build the latest `main` instead.

```sh
brew tap janthoXO/klangladder https://github.com/janthoXO/KlangLadder
brew install klangladder
brew services start klangladder
```

`brew services start` runs KlangLadder now and at every login. Use it instead of the **Launch at login** toggle. To run it once without a service, use `open $(brew --prefix)/opt/klangladder/KlangLadder.app`.

Update with `brew upgrade klangladder`, then `brew services restart klangladder`.

### GitHub release

Download `KlangLadder-v<version>.zip` from the [latest release](https://github.com/janthoXO/KlangLadder/releases/latest), unzip it and move `KlangLadder.app` to `~/Applications`. The app is not notarized, so Gatekeeper blocks the first launch. Allow it in **System Settings → Privacy & Security**.

### From source

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

The extension in [`raycast/`](raycast/) adds an "Open KlangLadder" command to Raycast. It bundles the app: the first time you run the command, it installs KlangLadder into `~/Applications` and keeps it updated after that. If you already have a standalone copy (built from source, a Homebrew keg, or a manual copy in `~/Applications`), the extension uses that copy as-is instead.

To load it locally (needs Xcode 16.3+):

```sh
cd raycast && npm install && npm run dev
```

## Use

Left-click the menu bar icon to open the device lists. Right-click it for settings.

- **Output / Input tabs:** each tab has its own priority list. The popover opens on the tab you used last.
- **Make a device active:** click a connected device.
- **Change the ranking:** drag a device to a new place, or use **Move Up** / **Move Down** to shift it one place. The device at the top is number 1.
- **More actions:** right-click a device, or hover over it and click the **…** button that appears.
  - Move Up / Move Down: one place at a time
  - Disable: moves the device to the Disabled list
  - Enable (in the Disabled list): adds the device to the bottom of the priority list
  - Delete: only for disconnected devices
- **Disabled list:** collapsed below the priority list. It opens by itself when the active device is disabled. Click it to expand or collapse it.
- **Settings:** right-click the menu bar icon for **Launch at Login** and **Quit KlangLadder**.

The popover is as tall as your device list, up to twelve rows. The active device has a filled icon and a bold name. Disconnected devices are dimmed. Hover over a device to see whether it is connected, its connection type, when it was last seen and its ID.

Reordering, disabling, enabling and deleting never switch devices by themselves. They take effect on the next connect or disconnect.

### Tips

- New devices join the **bottom** of the priority list. Move them up if they should win.
- Bluetooth headsets (for example AirPods) used as a **microphone** force a low-quality call profile, so music sounds worse too. Consider disabling them in the Input tab.
- Virtual devices (BlackHole, Zoom, Teams, Loopback) are good candidates for the Disabled list.

### Open from other apps

`open klangladder://open` opens the popover. KlangLadder starts first if it isn't running.

## Uninstall

If you installed with Homebrew, run `brew services stop klangladder`, `brew uninstall klangladder` and `brew untap janthoXO/klangladder`.

Otherwise:

1. Turn off **Launch at login** in the popover, then click **Quit**.
2. Delete `~/Applications/KlangLadder.app`.
3. Optionally, delete your settings: `~/Library/Application Support/KlangLadder`.

## Development

See [README_DEV.md](README_DEV.md).
