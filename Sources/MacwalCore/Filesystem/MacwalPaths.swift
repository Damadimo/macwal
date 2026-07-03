import Foundation

public struct MacwalPaths: Sendable {
    public let home: URL
    public let appSupport: URL
    public let cache: URL
    public let configFile: URL
    public let generated: URL
    public let backups: URL
    public let logs: URL
    public let launchAgent: URL

    public init(environment: RuntimeEnvironment) {
        let home = environment.environment["MACWAL_HOME"].map(URL.init(fileURLWithPath:)) ?? environment.homeDirectory
        let appSupport = environment.environment["MACWAL_APP_SUPPORT"].map(URL.init(fileURLWithPath:))
            ?? home.appendingPathComponent("Library/Application Support/macwal", isDirectory: true)
        let cache = environment.environment["MACWAL_CACHE"].map(URL.init(fileURLWithPath:))
            ?? home.appendingPathComponent("Library/Caches/macwal", isDirectory: true)

        self.home = home
        self.appSupport = appSupport
        self.cache = cache
        self.configFile = appSupport.appendingPathComponent("config.json")
        self.generated = appSupport.appendingPathComponent("generated", isDirectory: true)
        self.backups = appSupport.appendingPathComponent("backups", isDirectory: true)
        self.logs = appSupport.appendingPathComponent("logs", isDirectory: true)
        self.launchAgent = home.appendingPathComponent("Library/LaunchAgents/io.macwal.watch.plist")
    }
}
