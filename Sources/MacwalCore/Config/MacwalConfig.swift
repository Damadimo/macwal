import Foundation

public struct MacwalConfig: Codable, Equatable, Sendable {
    public struct PaletteConfig: Codable, Equatable, Sendable {
        public var mode: String
        public var minimumForegroundContrast: Double
        public var minimumAccentContrast: Double

        public init(mode: String, minimumForegroundContrast: Double, minimumAccentContrast: Double) {
            self.mode = mode
            self.minimumForegroundContrast = minimumForegroundContrast
            self.minimumAccentContrast = minimumAccentContrast
        }

        public static var `default`: PaletteConfig {
            PaletteConfig(mode: "auto", minimumForegroundContrast: 7.0, minimumAccentContrast: 3.0)
        }
    }

    public struct TerminalConfig: Codable, Equatable, Sendable {
        public var profileName: String
        public var setAsDefault: Bool
    }

    public struct ObsidianConfig: Codable, Equatable, Sendable {
        public var vaults: [String]
    }

    public struct SpotifyConfig: Codable, Equatable, Sendable {
        public var enabled: Bool
        public var spicetifyPath: String
    }

    public struct SystemConfig: Codable, Equatable, Sendable {
        public var setAppearanceMode: Bool
        public var setAccentColor: Bool
        public var setHighlightColor: Bool
    }

    public struct FinderConfig: Codable, Equatable, Sendable {
        public var setFolderTint: Bool
        public var folders: [String]
    }

    public struct AdapterConfig: Codable, Equatable, Sendable {
        public var terminal: TerminalConfig
        public var obsidian: ObsidianConfig
        public var spotify: SpotifyConfig
        public var system: SystemConfig
        public var finder: FinderConfig
        /// Background opacity applied to every generated terminal theme.
        /// 0.0 = fully transparent, 1.0 = fully opaque. Default is a subtle 0.85.
        public var terminalOpacity: Double = 0.85
    }

    public var schemaVersion: Int
    public var defaultTargets: [String]
    public var allowPrivateByDefault: Bool
    public var palette: PaletteConfig
    public var adapters: AdapterConfig

    public static var `default`: MacwalConfig {
        MacwalConfig(
            schemaVersion: 1,
            defaultTargets: ["shell", "terminal", "obsidian", "chrome"],
            allowPrivateByDefault: false,
            palette: .default,
            adapters: AdapterConfig(
                terminal: TerminalConfig(profileName: "macwal", setAsDefault: true),
                obsidian: ObsidianConfig(vaults: []),
                spotify: SpotifyConfig(enabled: false, spicetifyPath: "spicetify"),
                system: SystemConfig(setAppearanceMode: false, setAccentColor: false, setHighlightColor: false),
                finder: FinderConfig(setFolderTint: false, folders: []),
                terminalOpacity: 0.85
            )
        )
    }
}

extension MacwalConfig.AdapterConfig {
    private enum CodingKeys: String, CodingKey {
        case terminal, obsidian, spotify, system, finder, terminalOpacity
    }

    // Custom decoding so that config.json files written by earlier versions
    // (which have no `terminalOpacity` key) still load, defaulting to 0.85.
    // Declared in an extension to keep the synthesized memberwise init and the
    // synthesized Encodable conformance.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            terminal: try container.decode(MacwalConfig.TerminalConfig.self, forKey: .terminal),
            obsidian: try container.decode(MacwalConfig.ObsidianConfig.self, forKey: .obsidian),
            spotify: try container.decode(MacwalConfig.SpotifyConfig.self, forKey: .spotify),
            system: try container.decode(MacwalConfig.SystemConfig.self, forKey: .system),
            finder: try container.decode(MacwalConfig.FinderConfig.self, forKey: .finder),
            terminalOpacity: try container.decodeIfPresent(Double.self, forKey: .terminalOpacity) ?? 0.85
        )
    }
}
