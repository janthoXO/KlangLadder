import Foundation

/// Assembles KlangLadder.app around an executable. Used by bundle.sh and the Raycast installer.
public enum AppBundle {
    public static let identifier = "dev.klangladder.KlangLadder"

    public static func assemble(at app: URL, executable: URL) throws {
        let fileManager = FileManager.default
        let macOS = app.appending(path: "Contents/MacOS")
        try? fileManager.removeItem(at: app)
        try fileManager.createDirectory(at: macOS, withIntermediateDirectories: true)
        try fileManager.copyItem(at: executable, to: macOS.appending(path: "KlangLadder"))
        try infoPlist.write(to: app.appending(path: "Contents/Info.plist"), atomically: true, encoding: .utf8)

        let codesign = try Process.run(URL(filePath: "/usr/bin/codesign"), arguments: ["--force", "--sign", "-", app.path])
        codesign.waitUntilExit()
        guard codesign.terminationStatus == 0 else {
            throw NSError(domain: identifier, code: Int(codesign.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "codesign failed for \(app.path)"])
        }
    }

    static let infoPlist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        	<key>CFBundleIdentifier</key>
        	<string>\(identifier)</string>
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
        			<string>\(identifier)</string>
        			<key>CFBundleURLSchemes</key>
        			<array>
        				<string>klangladder</string>
        			</array>
        		</dict>
        	</array>
        </dict>
        </plist>
        """
}
