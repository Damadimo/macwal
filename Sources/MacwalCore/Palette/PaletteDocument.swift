import Foundation

public struct PaletteSource: Codable, Equatable, Sendable {
    public let kind: String
    public let path: String
    public let screenIndex: Int?
    public let displayID: UInt32?

    public init(kind: String, path: String, screenIndex: Int? = nil, displayID: UInt32? = nil) {
        self.kind = kind
        self.path = path
        self.screenIndex = screenIndex
        self.displayID = displayID
    }

    public func jsonValue() -> JSONValue {
        .object([
            "kind": .string(kind),
            "path": .string(path),
            "screenIndex": screenIndex.map(JSONValue.int) ?? .null,
            "displayID": displayID.map { .number(Double($0)) } ?? .null
        ])
    }
}

public struct PaletteAppearance: Codable, Equatable, Sendable {
    public let recommendedMode: String
    public let wallpaperLuminance: Double
    public let contrastValidated: Bool

    public init(recommendedMode: String, wallpaperLuminance: Double, contrastValidated: Bool) {
        self.recommendedMode = recommendedMode
        self.wallpaperLuminance = wallpaperLuminance
        self.contrastValidated = contrastValidated
    }

    public func jsonValue() -> JSONValue {
        .object([
            "recommendedMode": .string(recommendedMode),
            "wallpaperLuminance": .number(wallpaperLuminance),
            "contrastValidated": .bool(contrastValidated)
        ])
    }
}

public struct PaletteDocument: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let generatedAt: String
    public let source: PaletteSource
    public let appearance: PaletteAppearance
    public let colors: [String: String]

    public init(
        schemaVersion: Int = 1,
        generatedAt: String,
        source: PaletteSource,
        appearance: PaletteAppearance,
        colors: [String: String]
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.source = source
        self.appearance = appearance
        self.colors = colors
    }

    public func encodedJSON(pretty: Bool = true) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        return String(decoding: try encoder.encode(self), as: UTF8.self)
    }

    public func jsonValue() -> JSONValue {
        .object([
            "schemaVersion": .int(schemaVersion),
            "generatedAt": .string(generatedAt),
            "source": source.jsonValue(),
            "appearance": appearance.jsonValue(),
            "colors": .object(colors.mapValues { .string($0) })
        ])
    }
}
