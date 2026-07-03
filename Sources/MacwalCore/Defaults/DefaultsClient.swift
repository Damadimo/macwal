import Foundation

public struct DefaultsClient {
    public let paths: MacwalPaths
    public let executor: CommandExecutor
    public let fileSystem: FileSystem

    public init(paths: MacwalPaths, executor: CommandExecutor, fileSystem: FileSystem = FileSystem()) {
        self.paths = paths
        self.executor = executor
        self.fileSystem = fileSystem
    }

    public func readValue(domain: String, key: String) throws -> Any? {
        let domainValues = try readDomain(domain)
        return domainValues[key]
    }

    public func setValue(_ value: Any, domain: String, key: String) throws {
        var domainValues = try readDomain(domain)
        domainValues[key] = value
        try importDomain(domain, values: domainValues)
    }

    public func deleteValue(domain: String, key: String) throws {
        var domainValues = try readDomain(domain)
        domainValues.removeValue(forKey: key)
        try importDomain(domain, values: domainValues)
    }

    public func readDomain(_ domain: String) throws -> [String: Any] {
        let result = try executor.run(executable: "/usr/bin/defaults", arguments: ["export", domain, "-"])
        if result.exitCode != 0 || result.stdout.isEmpty {
            return [:]
        }

        let plist = try PropertyListSerialization.propertyList(from: result.stdout, options: [], format: nil)
        return plist as? [String: Any] ?? [:]
    }

    public func importDomain(_ domain: String, values: [String: Any]) throws {
        try fileSystem.ensureDirectory(paths.cache)
        let temp = paths.cache.appendingPathComponent("defaults-\(UUID().uuidString).plist")
        let data = try PropertyListSerialization.data(fromPropertyList: values, format: .binary, options: 0)
        try data.write(to: temp, options: [.atomic])
        defer {
            try? FileManager.default.removeItem(at: temp)
        }

        let result = try executor.run(executable: "/usr/bin/defaults", arguments: ["import", domain, temp.path])
        guard result.exitCode == 0 else {
            throw MacwalError.adapterFailed("defaults import failed for \(domain): \(result.stderrText)")
        }
    }
}
