import Foundation

public struct ConfigStore {
    public let paths: MacwalPaths
    public let fileSystem: FileSystem

    public init(paths: MacwalPaths, fileSystem: FileSystem = FileSystem()) {
        self.paths = paths
        self.fileSystem = fileSystem
    }

    public func loadOrCreate() throws -> MacwalConfig {
        try load(createIfMissing: true)
    }

    public func load(createIfMissing: Bool) throws -> MacwalConfig {
        if fileSystem.fileExists(paths.configFile) {
            let data = try Data(contentsOf: paths.configFile)
            return try JSONDecoder().decode(MacwalConfig.self, from: data)
        }

        guard createIfMissing else {
            return .default
        }

        try fileSystem.ensureDirectory(paths.appSupport)
        let config = MacwalConfig.default
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try fileSystem.atomicWrite(try encoder.encode(config), to: paths.configFile)
        return config
    }
}
