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

    /// Set a single key to `value`, leaving every sibling key in the domain
    /// untouched. Real domains are mutated with a targeted `defaults write`; the
    /// previous implementation exported the whole domain, mutated it in memory,
    /// and re-imported it, which wiped every other key whenever the export step
    /// hiccuped (see `readDomain`).
    public func setValue(_ value: Any, domain: String, key: String) throws {
        if let fakeURL = fakeDomainURL(domain) {
            var domainValues = try readDomain(domain)
            domainValues[key] = value
            try writeFakeDomain(domainValues, to: fakeURL)
            return
        }

        let argument = try xmlPlistString(value)
        let result = try executor.run(executable: "/usr/bin/defaults", arguments: ["write", domain, key, argument])
        guard result.exitCode == 0 else {
            throw MacwalError.adapterFailed("defaults write failed for \(domain) \(key): \(result.stderrText)")
        }
    }

    /// Add (or replace) a single entry inside the dictionary stored at `key`
    /// without reading or rewriting the rest of that dictionary or the domain.
    /// This is how the Terminal profile is installed under `Window Settings`
    /// while preserving the user's other profiles.
    public func addDictionaryEntry(_ entry: [String: Any], forKey entryKey: String, domain: String, key: String) throws {
        if let fakeURL = fakeDomainURL(domain) {
            var domainValues = try readDomain(domain)
            var dictionary = domainValues[key] as? [String: Any] ?? [:]
            dictionary[entryKey] = entry
            domainValues[key] = dictionary
            try writeFakeDomain(domainValues, to: fakeURL)
            return
        }

        let argument = try xmlPlistString(entry)
        let result = try executor.run(
            executable: "/usr/bin/defaults",
            arguments: ["write", domain, key, "-dict-add", entryKey, argument]
        )
        guard result.exitCode == 0 else {
            throw MacwalError.adapterFailed("defaults write -dict-add failed for \(domain) \(key): \(result.stderrText)")
        }
    }

    public func deleteValue(domain: String, key: String) throws {
        if let fakeURL = fakeDomainURL(domain) {
            var domainValues = try readDomain(domain)
            domainValues.removeValue(forKey: key)
            try writeFakeDomain(domainValues, to: fakeURL)
            return
        }

        // `defaults delete` exits non-zero when the key is already absent; that
        // is a no-op for our purposes (restore of a key we created), so it is
        // not treated as an error.
        _ = try executor.run(executable: "/usr/bin/defaults", arguments: ["delete", domain, key])
    }

    public func readDomain(_ domain: String) throws -> [String: Any] {
        if let fakeURL = fakeDomainURL(domain) {
            guard fileSystem.fileExists(fakeURL) else {
                return [:]
            }
            let data = try Data(contentsOf: fakeURL)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            return plist as? [String: Any] ?? [:]
        }

        // `defaults export` exits 0 even for a domain that does not exist yet
        // (it prints `<dict/>`). A non-zero exit therefore signals a real
        // failure — surface it rather than pretending the domain is empty, so
        // callers never make a decision based on a phantom empty dictionary.
        let result = try executor.run(executable: "/usr/bin/defaults", arguments: ["export", domain, "-"])
        guard result.exitCode == 0 else {
            throw MacwalError.adapterFailed("defaults export failed for \(domain): \(result.stderrText)")
        }
        guard !result.stdout.isEmpty else {
            return [:]
        }

        let plist = try PropertyListSerialization.propertyList(from: result.stdout, options: [], format: nil)
        return plist as? [String: Any] ?? [:]
    }

    private func writeFakeDomain(_ values: [String: Any], to url: URL) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: values, format: .binary, options: 0)
        try fileSystem.atomicWrite(data, to: url)
    }

    private func xmlPlistString(_ value: Any) throws -> String {
        let data = try PropertyListSerialization.data(fromPropertyList: value, format: .xml, options: 0)
        return String(decoding: data, as: UTF8.self)
    }

    private func fakeDomainURL(_ domain: String) -> URL? {
        guard let storePath = executor.environment["MACWAL_DEFAULTS_STORE"] else {
            return nil
        }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let fileName = domain.addingPercentEncoding(withAllowedCharacters: allowed) ?? domain
        return URL(fileURLWithPath: storePath, isDirectory: true)
            .appendingPathComponent(fileName)
            .appendingPathExtension("plist")
    }
}
