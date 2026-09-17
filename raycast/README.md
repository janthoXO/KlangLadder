# KlangLadder (Raycast)

A Raycast extension with one command, **Open KlangLadder**, which opens the [KlangLadder](https://github.com/janthoXO/KlangLadder) menu bar app's popover.

This extension does not bundle the app. It requires KlangLadder to already be installed:

```sh
brew tap janthoXO/klangladder https://github.com/janthoXO/KlangLadder && brew install --HEAD klangladder
```

Or build it from source, see the [main README](../README.md#install). If the app isn't installed, the command shows a toast with an action to copy the install command above.

## Development

```sh
npm install
npm run dev
```
