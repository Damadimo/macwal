import Foundation

public struct FileSystem {
    public let fileManager: FileManager
    private let allowedWriteRoots: [URL]?

    public init(fileManager: FileManager = .default, allowedWriteRoots: [URL]? = nil) {
        self.fileManager = fileManager
        self.allowedWriteRoots = allowedWriteRoots?.map { $0.standardizedFileURL }
    }

    public func restricted(to roots: [URL]) -> FileSystem {
        FileSystem(fileManager: fileManager, allowedWriteRoots: roots)
    }

    public func ensureDirectory(_ url: URL) throws {
        try validateWritePath(url)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    public func fileExists(_ url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    public func atomicWrite(_ data: Data, to url: URL) throws {
        try validateWritePath(url)
        try ensureDirectory(url.deletingLastPathComponent())
        let temporary = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        do {
            try data.write(to: temporary, options: [.atomic])
            if fileExists(url) {
                _ = try fileManager.replaceItemAt(url, withItemAt: temporary)
            } else {
                try fileManager.moveItem(at: temporary, to: url)
            }
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw error
        }
    }

    public func atomicWriteString(_ string: String, to url: URL) throws {
        guard let data = string.data(using: .utf8) else {
            throw MacwalError.adapterFailed("Could not encode text for \(url.path).")
        }
        try atomicWrite(data, to: url)
    }

    public func removeIfExists(_ url: URL) throws {
        try validateWritePath(url)
        if fileExists(url) {
            try fileManager.removeItem(at: url)
        }
    }

    private func validateWritePath(_ url: URL) throws {
        guard let allowedWriteRoots else {
            return
        }

        let path = url.standardizedFileURL.path
        for root in allowedWriteRoots {
            let rootPath = root.standardizedFileURL.path
            if path == rootPath || path.hasPrefix(rootPath + "/") {
                return
            }
        }

        throw MacwalError.permissionDenied("Refusing to write outside declared roots: \(path)")
    }
}
