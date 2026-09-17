# KlangLadder (Raycast)

A Raycast extension with one command, **Open KlangLadder**, which opens the [KlangLadder](https://github.com/janthoXO/KlangLadder) menu bar app's popover.

The extension bundles the app. The first time you run the command, it installs KlangLadder into `~/Applications` and keeps it updated after that. If you already have a standalone copy (built from source, a Homebrew keg, or a manual copy in `~/Applications`), the extension leaves it alone and uses that copy instead.

## Development

```sh
npm install
npm run dev
```

Building the Swift side needs Xcode 16.3 or later (not just the Command Line Tools) — see [`swift/`](swift/) and the [main developer guide](../README_DEV.md#raycast-extension).
