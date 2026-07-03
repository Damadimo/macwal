import Foundation

public struct SpotifyAdapter {
    public let paths: MacwalPaths
    public let config: MacwalConfig.SpotifyConfig
    public let fileSystem: FileSystem
    public let backupManager: BackupManager
    public let commandExecutor: CommandExecutor

    private var themeDirectory: URL {
        paths.home.appendingPathComponent(".config/spicetify/Themes/macwal", isDirectory: true)
    }

    private var spicetifyConfigFiles: [URL] {
        [
            paths.home.appendingPathComponent(".config/spicetify/config-xpui.ini"),
            paths.home.appendingPathComponent(".config/spicetify/config.ini")
        ]
    }

    public init(
        paths: MacwalPaths,
        config: MacwalConfig.SpotifyConfig,
        fileSystem: FileSystem = FileSystem(),
        backupManager: BackupManager,
        commandExecutor: CommandExecutor
    ) {
        self.paths = paths
        self.config = config
        self.fileSystem = fileSystem
        self.backupManager = backupManager
        self.commandExecutor = commandExecutor
    }

    public func preview() -> AdapterPlan {
        let available = commandExecutor.executablePath(config.spicetifyPath) != nil
        return AdapterPlan(
            target: .spotify,
            status: available ? "ready" : "unavailable",
            plannedWrites: [
                themeDirectory.appendingPathComponent("color.ini").path,
                themeDirectory.appendingPathComponent("user.css").path
            ],
            messages: available
                ? ["Spicetify was found. Apply will run `spicetify config current_theme macwal` and `spicetify apply`."]
                : ["Spicetify is required for Spotify theming."]
        )
    }

    public func apply(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        guard commandExecutor.executablePath(config.spicetifyPath) != nil else {
            throw MacwalError.missingPrerequisite("Spicetify is required for target 'spotify'. Install Spicetify, then rerun this command.")
        }

        let colorURL = themeDirectory.appendingPathComponent("color.ini")
        let cssURL = themeDirectory.appendingPathComponent("user.css")
        let changedPaths = [colorURL.path, cssURL.path]
        let commands = [
            "\(config.spicetifyPath) config current_theme macwal",
            "\(config.spicetifyPath) apply"
        ]

        if dryRun {
            return AdapterApplySummary(
                target: .spotify,
                changedPaths: changedPaths,
                messages: ["Dry run: no Spicetify files were written.", "Would run: \(commands.joined(separator: " && "))"]
            )
        }

        try backupManager.backupFileBeforeWrite(themeDirectory, adapter: .spotify, dryRun: false)
        for file in spicetifyConfigFiles {
            try backupManager.backupFileBeforeWrite(file, adapter: .spotify, dryRun: false)
        }
        try backupManager.backupFileBeforeWrite(colorURL, adapter: .spotify, dryRun: false)
        try backupManager.backupFileBeforeWrite(cssURL, adapter: .spotify, dryRun: false)

        try fileSystem.ensureDirectory(themeDirectory)
        try fileSystem.atomicWriteString(try renderColorINI(palette), to: colorURL)
        try fileSystem.atomicWriteString(try renderCSS(palette), to: cssURL)

        try runSpicetify(arguments: ["config", "current_theme", "macwal"])
        try runSpicetify(arguments: ["apply"])

        return AdapterApplySummary(
            target: .spotify,
            changedPaths: changedPaths,
            messages: ["Spicetify theme generated and applied.", "Ran: \(commands.joined(separator: " && "))"]
        )
    }

    private func runSpicetify(arguments: [String]) throws {
        let result = try commandExecutor.run(executable: config.spicetifyPath, arguments: arguments)
        guard result.exitCode == 0 else {
            throw MacwalError.adapterFailed("spicetify \(arguments.joined(separator: " ")) failed: \(result.stderrText)")
        }
    }

    private func renderColorINI(_ palette: PaletteDocument) throws -> String {
        func noHash(_ key: String) throws -> String {
            guard let value = palette.colors[key] else {
                throw MacwalError.adapterFailed("Palette is missing required color '\(key)'.")
            }
            return value.replacingOccurrences(of: "#", with: "")
        }

        return """
        [Base]
        text               = \(try noHash("foreground"))
        subtext            = \(try noHash("white"))
        main               = \(try noHash("background"))
        sidebar            = \(try noHash("black"))
        player             = \(try noHash("background"))
        card               = \(try noHash("brightBlack"))
        shadow             = \(try noHash("black"))
        selected-row       = \(try noHash("selection"))
        button             = \(try noHash("accent"))
        button-active      = \(try noHash("brightCyan"))
        button-disabled    = \(try noHash("brightBlack"))
        tab-active         = \(try noHash("accent"))
        notification       = \(try noHash("accentAlt"))
        notification-error = \(try noHash("red"))
        misc               = \(try noHash("magenta"))

        """
    }

    private func renderCSS(_ palette: PaletteDocument) throws -> String {
        func color(_ key: String) throws -> String {
            guard let value = palette.colors[key] else {
                throw MacwalError.adapterFailed("Palette is missing required color '\(key)'.")
            }
            return value
        }

        return """
        /* Generated by macwal. Do not edit by hand. */
        :root {
          --macwal-background: \(try color("background"));
          --macwal-foreground: \(try color("foreground"));
          --macwal-accent: \(try color("accent"));
          --spice-main: \(try color("background"));
          --spice-sidebar: \(try color("black"));
          --spice-player: \(try color("background"));
          --spice-card: \(try color("brightBlack"));
          --spice-text: \(try color("foreground"));
          --spice-subtext: \(try color("white"));
          --spice-button: \(try color("accent"));
        }

        """
    }
}
