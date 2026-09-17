import Foundation
import KlangLadderApp

// `KlangLadder --bundle <path>` assembles the .app around this binary (bundle.sh).
let arguments = CommandLine.arguments
if arguments.count == 3, arguments[1] == "--bundle", let executable = Bundle.main.executableURL {
    do {
        try AppBundle.assemble(at: URL(filePath: arguments[2]), executable: executable)
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
        exit(1)
    }
}
runApp()
