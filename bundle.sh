#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

swift build -c release "$@"
.build/release/KlangLadder --bundle build/KlangLadder.app

echo "Built build/KlangLadder.app"
