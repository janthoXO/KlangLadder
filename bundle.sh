#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

swift build -c release

APP="build/KlangLadder.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp ".build/release/KlangLadder" "$APP/Contents/MacOS/KlangLadder"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key>
	<string>dev.klangladder.KlangLadder</string>
	<key>CFBundleName</key>
	<string>KlangLadder</string>
	<key>CFBundleExecutable</key>
	<string>KlangLadder</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string>dev.klangladder.KlangLadder</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>klangladder</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"

echo "Built $APP"
