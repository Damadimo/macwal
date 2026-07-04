import Darwin
import Foundation

public struct FinderAdapter {
    private struct TagCandidate {
        let name: String
        let index: Int
        let color: RGBColor
    }

    public let paths: MacwalPaths
    public let config: MacwalConfig.FinderConfig
    public let fileSystem: FileSystem
    public let backupManager: BackupManager

    private let tagXattrName = "com.apple.metadata:_kMDItemUserTags"

    public init(
        paths: MacwalPaths,
        config: MacwalConfig.FinderConfig,
        fileSystem: FileSystem = FileSystem(),
        backupManager: BackupManager
    ) {
        self.paths = paths
        self.config = config
        self.fileSystem = fileSystem
        self.backupManager = backupManager
    }

    public func preview() -> AdapterPlan {
        if !config.setFolderTint {
            return AdapterPlan(
                target: .finder,
                status: "noop",
                messages: ["Finder folder tinting is disabled in config.json."]
            )
        }

        if config.folders.isEmpty {
            return AdapterPlan(
                target: .finder,
                status: "blocked",
                messages: ["No folders are configured for Finder tinting."]
            )
        }

        return AdapterPlan(
            target: .finder,
            status: isTahoeOrNewer ? "ready" : "unavailable",
            plannedWrites: config.folders.map { "\($0):\(tagXattrName)" },
            messages: ["Uses a reversible colored Finder tag xattr on configured folders."]
        )
    }

    public func apply(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        guard config.setFolderTint else {
            return AdapterApplySummary(
                target: .finder,
                changedPaths: [],
                messages: ["Finder folder tinting is disabled in config.json."]
            )
        }

        guard isTahoeOrNewer else {
            throw MacwalError.missingPrerequisite("Finder folder tinting requires macOS 26 Tahoe or newer.")
        }

        guard !config.folders.isEmpty else {
            throw MacwalError.missingPrerequisite("No folders are configured for Finder tinting.")
        }

        let tag = try nearestTag(for: palette)
        let folders = try config.folders.map(validateFolderPath)
        let changed = folders.map { "\($0.path):\(tagXattrName)" }

        if dryRun {
            return AdapterApplySummary(
                target: .finder,
                changedPaths: changed,
                messages: ["Dry run: would apply Finder tag color \(tag.name) to configured folders."]
            )
        }

        for folder in folders {
            try backupManager.backupXattrBeforeWrite(path: folder, name: tagXattrName, adapter: .finder, dryRun: false)
            var tags = try readTags(from: folder)
            tags.removeAll { $0.hasPrefix("macwal\n") }
            tags.append("macwal\n\(tag.index)")
            try writeTags(tags, to: folder)
        }

        return AdapterApplySummary(
            target: .finder,
            changedPaths: changed,
            messages: ["Applied Finder tag color \(tag.name) to configured folders."]
        )
    }

    private func validateFolderPath(_ rawPath: String) throws -> URL {
        let url = MacwalPaths.resolve(rawPath, home: paths.home).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw MacwalError.missingPrerequisite("Configured Finder path is not a folder: \(url.path)")
        }

        let forbidden = [
            "/System",
            "/Applications",
            "/Library",
            "/Users"
        ]
        if forbidden.contains(url.path) {
            throw MacwalError.permissionDenied("Refusing to modify protected root folder: \(url.path)")
        }
        return url
    }

    private func nearestTag(for palette: PaletteDocument) throws -> TagCandidate {
        guard let hex = palette.colors["accent"] else {
            throw MacwalError.adapterFailed("Palette is missing required color 'accent'.")
        }
        let accent = try RGBColor(hex: hex)
        return Self.tagCandidates.min { lhs, rhs in
            distance(lhs.color, accent) < distance(rhs.color, accent)
        } ?? Self.tagCandidates[3]
    }

    private func distance(_ lhs: RGBColor, _ rhs: RGBColor) -> Double {
        let red = Double(lhs.red) - Double(rhs.red)
        let green = Double(lhs.green) - Double(rhs.green)
        let blue = Double(lhs.blue) - Double(rhs.blue)
        return red * red + green * green + blue * blue
    }

    private var isTahoeOrNewer: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26
    }

    private func readTags(from url: URL) throws -> [String] {
        let size = getxattr(url.path, tagXattrName, nil, 0, 0, 0)
        if size < 0 {
            if errno == ENOATTR {
                return []
            }
            throw MacwalError.adapterFailed("Could not read Finder tags from \(url.path): errno \(errno)")
        }

        var data = Data(count: size)
        let readSize = data.withUnsafeMutableBytes { buffer in
            getxattr(url.path, tagXattrName, buffer.baseAddress, size, 0, 0)
        }
        if readSize < 0 {
            throw MacwalError.adapterFailed("Could not read Finder tags from \(url.path): errno \(errno)")
        }

        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return plist as? [String] ?? []
    }

    private func writeTags(_ tags: [String], to url: URL) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: tags, format: .binary, options: 0)
        let result = data.withUnsafeBytes { buffer in
            setxattr(url.path, tagXattrName, buffer.baseAddress, data.count, 0, 0)
        }
        if result != 0 {
            throw MacwalError.adapterFailed("Could not write Finder tags to \(url.path): errno \(errno)")
        }
    }

    private static let tagCandidates: [TagCandidate] = [
        TagCandidate(name: "gray", index: 1, color: RGBColor(red: 142, green: 142, blue: 147)),
        TagCandidate(name: "green", index: 2, color: RGBColor(red: 52, green: 199, blue: 89)),
        TagCandidate(name: "purple", index: 3, color: RGBColor(red: 175, green: 82, blue: 222)),
        TagCandidate(name: "blue", index: 4, color: RGBColor(red: 0, green: 122, blue: 255)),
        TagCandidate(name: "yellow", index: 5, color: RGBColor(red: 255, green: 204, blue: 0)),
        TagCandidate(name: "red", index: 6, color: RGBColor(red: 255, green: 59, blue: 48)),
        TagCandidate(name: "orange", index: 7, color: RGBColor(red: 255, green: 149, blue: 0))
    ]
}
