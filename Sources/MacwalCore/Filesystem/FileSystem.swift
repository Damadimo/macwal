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

    /// Return a copy that also permits writing under `roots`, keeping the current
    /// roots. Used for locations only discovered at runtime — e.g. browser
    /// profile directories declared with absolute paths in `profiles.ini`, which
    /// are not knowable when the static sandbox roots are computed. A no-op when
    /// this filesystem is unrestricted.
    public func allowingAdditional(_ roots: [URL]) -> FileSystem {
        guard let allowedWriteRoots else {
            return self
        }
        return FileSystem(fileManager: fileManager, allowedWriteRoots: allowedWriteRoots + roots)
    }

    public func ensureDirectory(_ url: URL) throws {
        try validateWritePath(url)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    /// Create the directory tree needed to hold `fileURL`, WITHOUT validating the
    /// directory against the write roots. Only call this after the file path
    /// itself has passed `validateWritePath`: creating a file's ancestor
    /// directories is inherent to writing that (already-allowed) file. This lets
    /// an exact-file write root such as `~/.vimrc` work even though its parent
    /// (`~`) is deliberately not a write root.
    private func ensureParentDirectory(of fileURL: URL) throws {
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    }

    public func fileExists(_ url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    public func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    /// Copy `source` to `destination`, enforcing the write-root sandbox on the
    /// destination, creating intermediate directories, and replacing any
    /// existing file at the destination.
    public func copyItem(at source: URL, to destination: URL) throws {
        try validateWritePath(destination)
        try ensureParentDirectory(of: destination)
        if fileExists(destination) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
    }

    public func atomicWrite(_ data: Data, to url: URL) throws {
        try validateWritePath(url)
        try ensureParentDirectory(of: url)
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
