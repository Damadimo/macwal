import Foundation

public struct ProcessResult: Equatable, Sendable {
    public let exitCode: Int32
    public let stdout: Data
    public let stderr: Data

    public var stderrText: String {
        String(decoding: stderr, as: UTF8.self)
    }
}

public struct CommandExecutor: Sendable {
    public let environment: [String: String]

    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
    }

    public func executablePath(_ nameOrPath: String) -> String? {
        if nameOrPath.contains("/") {
            return FileManager.default.isExecutableFile(atPath: nameOrPath) ? nameOrPath : nil
        }

        let pathValue = environment["PATH"] ?? ProcessInfo.processInfo.environment["PATH"] ?? ""
        for directory in pathValue.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent(nameOrPath).path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    public func run(executable: String, arguments: [String]) throws -> ProcessResult {
        let resolved = executablePath(executable) ?? executable
        let process = Process()
        process.executableURL = URL(fileURLWithPath: resolved)
        process.arguments = arguments
        process.environment = environment

        let stdout = Pipe()
        process.standardOutput = stdout

        // Route stderr to a temporary file rather than a second pipe. Reading two
        // pipes sequentially (stdout to EOF, then stderr) deadlocks whenever a
        // child fills the stderr pipe buffer while we are still blocked draining
        // stdout. A file sink has no bounded buffer, so the child can never block
        // on stderr, and we drain the single stdout pipe with no ordering hazard.
        let stderrURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macwal-stderr-\(UUID().uuidString)")
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
        let stderrHandle = try FileHandle(forWritingTo: stderrURL)
        process.standardError = stderrHandle
        defer {
            try? FileManager.default.removeItem(at: stderrURL)
        }

        try process.run()
        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        try? stderrHandle.close()
        let stderrData = (try? Data(contentsOf: stderrURL)) ?? Data()

        return ProcessResult(
            exitCode: process.terminationStatus,
            stdout: stdoutData,
            stderr: stderrData
        )
    }
}
