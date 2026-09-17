import Foundation
import KlangLadderApp
import RaycastSwiftMacros

// This binary is both the Raycast bridge and the app (9.2).
// Raycast calls it with a function name. Launched from KlangLadder.app, it runs the app.
if CommandLine.argc > 1, let proxy = NSClassFromString("KlangLadderRaycast._Proxy\(CommandLine.arguments[1])") as? _Ray.Proxy.Type {
    // Same as the main file RaycastSwiftPlugin generates.
    let callback = _Ray.Callback()
    proxy._execute(callback)
    do {
        print(try await callback.encodedString)
        exit(EXIT_SUCCESS)
    } catch {
        FileHandle.standardError.write(Data("\(error)\n".utf8))
        exit(EXIT_FAILURE)
    }
}
runApp()
