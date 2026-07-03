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

    public struct ChromeConfig: Codable, Equatable, Sendable {
        public var profiles: [String]
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
        public var chrome: ChromeConfig
        public var spotify: SpotifyConfig
        public var system: SystemConfig
        public var finder: FinderConfig
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
                chrome: ChromeConfig(profiles: []),
                spotify: SpotifyConfig(enabled: false, spicetifyPath: "spicetify"),
                system: SystemConfig(setAppearanceMode: false, setAccentColor: false, setHighlightColor: false),
                finder: FinderConfig(setFolderTint: false, folders: [])
            )
        )
    }
}
