# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

KlangLadder is a macOS 14+ menu bar app (Swift 5.10, SwiftPM, no Xcode project). It switches the default audio input/output device by a per-scope priority list. `DESIGN.md` is the spec. `README_DEV.md` is the detailed implementation guide. Code comments cite design sections as `(4.4)`, `(6.2)` and goals as `(G6)`, `(G19)`. Keep using these references and look them up in `DESIGN.md`.

## Commands

```sh
swift build                                       # debug build
swift test                                        # all tests (swift-testing, not XCTest)
swift test --filter connectRanksAboveActive_switches   # one test, by function name
./bundle.sh                                       # release build → build/KlangLadder.app (ad-hoc signed)
open build/KlangLadder.app
cd raycast && npm ci && npm run lint              # Raycast extension lint (ray lint), runs in CI
cd raycast && npm run build                       # ray build; needs full Xcode 16.3+, not just CLT
```

`.build/debug/KlangLadder` runs without a bundle ID or Info.plist. The URL scheme, the single-instance check and launch at login only work in the bundled app.

## Architecture

Three targets in the root package:

- **KlangLadderCore**: all logic, no UI.
  - `Model.swift`: `ScopeConfig` and `Rules.target`. These are pure and unit-tested in `Tests/KlangLadderCoreTests/RulesTests.swift`. The tests mirror table 6.4.
  - `Engine.swift`: `@MainActor @Observable`. Wires Core Audio events to the rules. Also holds `ConfigStore` and `LoginSession`.
  - `CoreAudio.swift`: thin HAL adapter.
- **KlangLadderApp**: a *library* containing the AppKit shell (`App.swift`), the SwiftUI popover and `AppBundle`. It is a library so the Raycast binary can link it and call `runApp()`.
- **KlangLadder**: a thin executable. `--bundle <path>` assembles the .app (used by `bundle.sh`). Otherwise it calls `runApp()`.

Invariants to preserve:

- **Rank = array index** in `ScopeConfig.priority`. Never store positions. A device is in exactly one of `priority` or `disabled`. Disabled or unknown means rank −∞ (`rank()` returns nil).
- **Only connect/disconnect events (and the first start per login session) switch devices.** Config edits, `delete` and manual default changes never do. User actions go through `engine.edit(scope) { ... }`, which only mutates and saves.
- **Telling a macOS auto-switch from a manual choice** (4.4): device-list events are debounced (`debounceDelay`). `defaultChanged` ignores events while an evaluation is pending, and handles late auto-switches via `recentConnect` within `autoSwitchWindow`. `active[scope]` is the *recorded* default and is passed as `previous` to `Rules.target`, not whatever Core Audio reports now. The two timing knobs are unverified guesses (spike S5).
- `config.json` in `~/Library/Application Support/KlangLadder/` is written only by the running app, atomically. An unreadable file or `version > 1` gets moved aside, never overwritten. Add schema migrations in `ConfigStore.load`.
- The URL scheme is a trust boundary. Only `klangladder://open` is accepted, and everything else is ignored.
- Everything runs on the main thread. Core Audio listeners deliver on `.main`, and callbacks use `MainActor.assumeIsolated`.

## Raycast extension (`raycast/`)

`raycast/swift` is a separate package. It depends on the root package via `.package(path: "../..")` and refers to it as `package: "KlangLadder"`. SwiftPM derives that identity from the folder name, so the repo folder must be named `KlangLadder`. The Raycast package uses its own `main.swift` (only `RaycastTypeScriptPlugin`, not `RaycastSwiftPlugin`). The one compiled binary is both the Raycast bridge and the app. `Install.swift` installs or updates `~/Applications/KlangLadder.app` from that binary. It never touches a standalone copy, and it detects updates by SHA-256 stored in a marker file.

## CI / release

- `build.yml` runs on PRs to non-main branches: swift build, swift test, ray lint.
- `package.yml` runs on PRs to `main`: bundle, Homebrew formula install/test/audit from a local tap, and `ray build`.
- `release.yml` runs on every push to `main`. It auto-bumps the patch version, creates a GitHub release, rewrites the `url`/`tag`/`revision` in `Formula/klangladder.rb` and commits it to `main` as the bot, then publishes to the Raycast Store. It also swaps the `../..` path dependency for the GitHub URL.

Don't hand-edit the formula's `url` block. The release job owns it. `bundle.sh` forwards its arguments to `swift build`, because the formula needs `--disable-sandbox`.
