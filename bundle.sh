#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

swift build -c release "$@"
.build/release/KlangLadder --bundle build/KlangLadder.app

if [[ -n "${VERSION:-}" ]]; then
    plutil -replace CFBundleShortVersionString -string "$VERSION" build/KlangLadder.app/Contents/Info.plist
    codesign --force --sign - build/KlangLadder.app
fi

echo "Built build/KlangLadder.app"
