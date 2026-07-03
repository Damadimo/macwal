import Darwin
import Foundation

public struct BackupRecord: Codable, Equatable, Sendable {
    public let id: String
    public let adapter: String
    public let kind: String
    public let originalPath: String
    public let backupPath: String?
    public let originalExisted: Bool
    public let timestamp: String
    public let preferenceDomain: String?
    public let preferenceKey: String?
    public let xattrName: String?

    public init(
        id: String,
        adapter: String,
        kind: String,
        originalPath: String,
        backupPath: String?,
        originalExisted: Bool,
        timestamp: String,
        preferenceDomain: String? = nil,
        preferenceKey: String? = nil,
        xattrName: String? = nil
    ) {
        self.id = id
        self.adapter = adapter
        self.kind = kind
        self.originalPath = originalPath
        self.backupPath = backupPath
        self.originalExisted = originalExisted
        self.timestamp = timestamp
        self.preferenceDomain = preferenceDomain
        self.preferenceKey = preferenceKey
        self.xattrName = xattrName
    }
}

public struct BackupIndex: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var records: [BackupRecord]

    public static var empty: BackupIndex {
        BackupIndex(schemaVersion: 1, records: [])
    }
}

public struct RestoreSummary: Equatable, Sendable {
    public let restored: [String]
    public let removed: [String]

    public func jsonValue() -> JSONValue {
        .object([
            "restored": .array(restored.map(JSONValue.string)),
            "removed": .array(removed.map(JSONValue.string))
        ])
    }
}

public struct BackupManager {
    public let paths: MacwalPaths
    public let fileSystem: FileSystem
    public let commandExecutor: CommandExecutor

    private var indexURL: URL {
        paths.backups.appendingPathComponent("index.json")
    }

    public init(
        paths: MacwalPaths,
        fileSystem: FileSystem = FileSystem(),
        commandExecutor: CommandExecutor = CommandExecutor()
    ) {
        self.paths = paths
        self.fileSystem = fileSystem
        self.commandExecutor = commandExecutor
    }

    public func backupFileBeforeWrite(_ url: URL, adapter: MacwalTarget, dryRun: Bool) throws {
        if dryRun {
            return
        }

        try fileSystem.ensureDirectory(paths.backups)
        var index = try loadIndex()

        if index.records.contains(where: { $0.kind == "file" && $0.adapter == adapter.rawValue && $0.originalPath == url.path }) {
            return
        }

        let existed = fileSystem.fileExists(url)
        let backupURL: URL?
        if existed {
            let adapterDirectory = paths.backups.appendingPathComponent(adapter.rawValue, isDirectory: true)
            try fileSystem.ensureDirectory(adapterDirectory)
            backupURL = adapterDirectory.appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)")
            try FileManager.default.copyItem(at: url, to: backupURL!)
        } else {
            backupURL = nil
        }

        let record = BackupRecord(
            id: UUID().uuidString,
            adapter: adapter.rawValue,
            kind: "file",
            originalPath: url.path,
            backupPath: backupURL?.path,
            originalExisted: existed,
            timestamp: Self.isoString(from: Date())
        )
        index.records.append(record)
        try saveIndex(index)
    }

    public func backupDefaultsBeforeWrite(domain: String, key: String, value: Any?, adapter: MacwalTarget, dryRun: Bool) throws {
        if dryRun {
            return
        }

        try fileSystem.ensureDirectory(paths.backups)
        var index = try loadIndex()
        let originalPath = "\(domain):\(key)"

        if index.records.contains(where: { $0.kind == "defaults" && $0.adapter == adapter.rawValue && $0.originalPath == originalPath }) {
            return
        }

        let existed = value != nil
        let backupURL: URL?
        if let value {
            let adapterDirectory = paths.backups.appendingPathComponent(adapter.rawValue, isDirectory: true)
            try fileSystem.ensureDirectory(adapterDirectory)
            backupURL = adapterDirectory.appendingPathComponent("\(UUID().uuidString)-\(key).plist")
            let data = try PropertyListSerialization.data(fromPropertyList: ["value": value], format: .binary, options: 0)
            try fileSystem.atomicWrite(data, to: backupURL!)
        } else {
            backupURL = nil
        }

        index.records.append(BackupRecord(
            id: UUID().uuidString,
            adapter: adapter.rawValue,
            kind: "defaults",
            originalPath: originalPath,
            backupPath: backupURL?.path,
            originalExisted: existed,
            timestamp: Self.isoString(from: Date()),
            preferenceDomain: domain,
            preferenceKey: key
        ))
        try saveIndex(index)
    }

    public func backupXattrBeforeWrite(path: URL, name: String, adapter: MacwalTarget, dryRun: Bool) throws {
        if dryRun {
            return
        }

        try fileSystem.ensureDirectory(paths.backups)
        var index = try loadIndex()

        if index.records.contains(where: { $0.kind == "xattr" && $0.adapter == adapter.rawValue && $0.originalPath == path.path && $0.xattrName == name }) {
            return
        }

        let value = try readXattr(path: path, name: name)
        let existed = value != nil
        let backupURL: URL?
        if let value {
            let adapterDirectory = paths.backups.appendingPathComponent(adapter.rawValue, isDirectory: true)
            try fileSystem.ensureDirectory(adapterDirectory)
            backupURL = adapterDirectory.appendingPathComponent("\(UUID().uuidString)-xattr.plist")
            let data = try PropertyListSerialization.data(fromPropertyList: ["value": value], format: .binary, options: 0)
            try fileSystem.atomicWrite(data, to: backupURL!)
        } else {
            backupURL = nil
        }

        index.records.append(BackupRecord(
            id: UUID().uuidString,
            adapter: adapter.rawValue,
            kind: "xattr",
            originalPath: path.path,
            backupPath: backupURL?.path,
            originalExisted: existed,
            timestamp: Self.isoString(from: Date()),
            xattrName: name
        ))
        try saveIndex(index)
    }

    public func restore(targets: [MacwalTarget], dryRun: Bool) throws -> RestoreSummary {
        var index = try loadIndex()
        let targetNames = Set(targets.map(\.rawValue))
        let records = index.records.filter { targetNames.contains($0.adapter) }
        var restored: [String] = []
        var removed: [String] = []

        for record in records.reversed() {
            switch record.kind {
            case "file":
                try restoreFile(record: record, restored: &restored, removed: &removed, dryRun: dryRun)
            case "defaults":
                try restoreDefaults(record: record, restored: &restored, removed: &removed, dryRun: dryRun)
            case "xattr":
                try restoreXattr(record: record, restored: &restored, removed: &removed, dryRun: dryRun)
            default:
                continue
            }
        }

        if !dryRun {
            index.records.removeAll { targetNames.contains($0.adapter) }
            try saveIndex(index)
        }

        return RestoreSummary(restored: restored.sorted(), removed: removed.sorted())
    }

    private func restoreFile(record: BackupRecord, restored: inout [String], removed: inout [String], dryRun: Bool) throws {
            let originalURL = URL(fileURLWithPath: record.originalPath)

            if record.originalExisted {
                guard let backupPath = record.backupPath else {
                    throw MacwalError.restoreFailed("Missing backup path for \(record.originalPath).")
                }
                if !dryRun {
                    try fileSystem.ensureDirectory(originalURL.deletingLastPathComponent())
                    if fileSystem.fileExists(originalURL) {
                        try FileManager.default.removeItem(at: originalURL)
                    }
                    try FileManager.default.copyItem(at: URL(fileURLWithPath: backupPath), to: originalURL)
                }
                restored.append(record.originalPath)
            } else {
                if !dryRun {
                    try fileSystem.removeIfExists(originalURL)
                }
                removed.append(record.originalPath)
            }
    }

    private func restoreDefaults(record: BackupRecord, restored: inout [String], removed: inout [String], dryRun: Bool) throws {
        guard let domain = record.preferenceDomain, let key = record.preferenceKey else {
            throw MacwalError.restoreFailed("Missing preference metadata for \(record.originalPath).")
        }

        if record.originalExisted {
            guard let backupPath = record.backupPath else {
                throw MacwalError.restoreFailed("Missing preference backup for \(record.originalPath).")
            }
            if !dryRun {
                let data = try Data(contentsOf: URL(fileURLWithPath: backupPath))
                let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
                guard let dictionary = plist as? [String: Any], let value = dictionary["value"] else {
                    throw MacwalError.restoreFailed("Invalid preference backup for \(record.originalPath).")
                }
                let defaults = DefaultsClient(paths: paths, executor: commandExecutor, fileSystem: fileSystem)
                try defaults.setValue(value, domain: domain, key: key)
            }
            restored.append(record.originalPath)
        } else {
            if !dryRun {
                let defaults = DefaultsClient(paths: paths, executor: commandExecutor, fileSystem: fileSystem)
                try defaults.deleteValue(domain: domain, key: key)
            }
            removed.append(record.originalPath)
        }
    }

    private func restoreXattr(record: BackupRecord, restored: inout [String], removed: inout [String], dryRun: Bool) throws {
        guard let name = record.xattrName else {
            throw MacwalError.restoreFailed("Missing xattr metadata for \(record.originalPath).")
        }

        let url = URL(fileURLWithPath: record.originalPath)
        let displayPath = "\(record.originalPath):\(name)"
        if record.originalExisted {
            guard let backupPath = record.backupPath else {
                throw MacwalError.restoreFailed("Missing xattr backup for \(displayPath).")
            }
            if !dryRun {
                let data = try Data(contentsOf: URL(fileURLWithPath: backupPath))
                let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
                guard let dictionary = plist as? [String: Any], let value = dictionary["value"] as? Data else {
                    throw MacwalError.restoreFailed("Invalid xattr backup for \(displayPath).")
                }
                try writeXattr(path: url, name: name, value: value)
            }
            restored.append(displayPath)
        } else {
            if !dryRun {
                try removeXattrIfExists(path: url, name: name)
            }
            removed.append(displayPath)
        }
    }

    public func plannedRestore(targets: [MacwalTarget]) throws -> [BackupRecord] {
        let targetNames = Set(targets.map(\.rawValue))
        return try loadIndex().records.filter { targetNames.contains($0.adapter) }
    }

    private func loadIndex() throws -> BackupIndex {
        guard fileSystem.fileExists(indexURL) else {
            return .empty
        }

        let data = try Data(contentsOf: indexURL)
        return try JSONDecoder().decode(BackupIndex.self, from: data)
    }

    private func saveIndex(_ index: BackupIndex) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try fileSystem.atomicWrite(try encoder.encode(index), to: indexURL)
    }

    private func readXattr(path: URL, name: String) throws -> Data? {
        let size = getxattr(path.path, name, nil, 0, 0, 0)
        if size < 0 {
            if errno == ENOATTR {
                return nil
            }
            throw MacwalError.adapterFailed("Could not read xattr \(name) from \(path.path): errno \(errno)")
        }

        var data = Data(count: size)
        let readSize = data.withUnsafeMutableBytes { buffer in
            getxattr(path.path, name, buffer.baseAddress, size, 0, 0)
        }
        if readSize < 0 {
            throw MacwalError.adapterFailed("Could not read xattr \(name) from \(path.path): errno \(errno)")
        }
        return data
    }

    private func writeXattr(path: URL, name: String, value: Data) throws {
        let result = value.withUnsafeBytes { buffer in
            setxattr(path.path, name, buffer.baseAddress, value.count, 0, 0)
        }
        if result != 0 {
            throw MacwalError.restoreFailed("Could not restore xattr \(name) on \(path.path): errno \(errno)")
        }
    }

    private func removeXattrIfExists(path: URL, name: String) throws {
        let result = removexattr(path.path, name, 0)
        if result != 0 && errno != ENOATTR {
            throw MacwalError.restoreFailed("Could not remove xattr \(name) from \(path.path): errno \(errno)")
        }
    }

    private static func isoString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
