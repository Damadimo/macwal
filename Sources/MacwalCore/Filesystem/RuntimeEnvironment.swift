import Foundation

public struct RuntimeEnvironment: Sendable {
    public var homeDirectory: URL
    public var currentDirectory: URL
    public var environment: [String: String]

    public init(
        homeDirectory: URL,
        currentDirectory: URL,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.homeDirectory = homeDirectory
        self.currentDirectory = currentDirectory
        self.environment = environment
    }

    public static var live: RuntimeEnvironment {
        let env = ProcessInfo.processInfo.environment
        let home = env["HOME"].map(URL.init(fileURLWithPath:)) ?? FileManager.default.homeDirectoryForCurrentUser
        return RuntimeEnvironment(
            homeDirectory: home,
            currentDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
            environment: env
        )
    }
}
