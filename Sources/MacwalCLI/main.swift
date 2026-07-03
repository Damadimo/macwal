import Foundation
import MacwalCore

@main
struct MacwalMain {
    static func main() async {
        let result = await MainActor.run {
            let runner = CommandRunner()
            return runner.run(arguments: Array(CommandLine.arguments.dropFirst()))
        }

        if !result.stdout.isEmpty {
            FileHandle.standardOutput.write(Data(result.stdout.utf8))
        }

        if !result.stderr.isEmpty {
            FileHandle.standardError.write(Data(result.stderr.utf8))
        }

        exit(result.exitCode)
    }
}
