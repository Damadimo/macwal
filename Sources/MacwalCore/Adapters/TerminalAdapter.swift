import AppKit
import Foundation

public struct TerminalAdapter {
    public let paths: MacwalPaths
    public let config: MacwalConfig.TerminalConfig
    public let fileSystem: FileSystem
    public let backupManager: BackupManager
    public let commandExecutor: CommandExecutor

    private var outputFile: URL {
        paths.generated.appendingPathComponent("terminal/\(safeProfileFileName).terminal")
    }

    public init(
        paths: MacwalPaths,
        config: MacwalConfig.TerminalConfig = MacwalConfig.default.adapters.terminal,
        fileSystem: FileSystem = FileSystem(),
        backupManager: BackupManager? = nil,
        commandExecutor: CommandExecutor = CommandExecutor()
    ) {
        self.paths = paths
        self.config = config
        self.fileSystem = fileSystem
        self.commandExecutor = commandExecutor
        self.backupManager = backupManager ?? BackupManager(paths: paths, fileSystem: fileSystem, commandExecutor: commandExecutor)
    }

    private var safeProfileFileName: String {
        config.profileName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func preview() -> AdapterPlan {
        AdapterPlan(
            target: .terminal,
            status: "ready",
            plannedWrites: plannedWrites(),
            messages: config.setAsDefault
                ? ["Generates a Terminal.app profile file and installs it as the default Terminal profile."]
                : ["Generates a Terminal.app profile file. Direct preference mutation is not performed."]
        )
    }

    public func apply(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        let changedPaths = plannedWrites()
        if dryRun {
            return AdapterApplySummary(
                target: .terminal,
                changedPaths: changedPaths,
                messages: ["Dry run: no Terminal profile was written."]
            )
        }

        let profile = try renderProfileDictionary(palette)
        let data = try PropertyListSerialization.data(fromPropertyList: profile, format: .xml, options: 0)
        try backupManager.backupFileBeforeWrite(outputFile.deletingLastPathComponent(), adapter: .terminal, dryRun: false)
        try backupManager.backupFileBeforeWrite(outputFile, adapter: .terminal, dryRun: false)
        try fileSystem.atomicWrite(data, to: outputFile)

        var messages = ["Terminal profile generated."]
        if config.setAsDefault {
            try installAsDefault(profile: profile)
            let restartMessage = AppRestarter(commandExecutor: commandExecutor).restart(
                appName: "Terminal",
                processName: "Terminal",
                selfTermProgram: "Apple_Terminal"
            )
            messages = ["Terminal profile generated and installed as the default Terminal profile.", restartMessage]
        } else {
            messages = ["Terminal profile generated. Direct Terminal preference mutation is disabled in config.json."]
        }

        return AdapterApplySummary(
            target: .terminal,
            changedPaths: changedPaths,
            messages: messages
        )
    }

    private func plannedWrites() -> [String] {
        var writes = [outputFile.path]
        if config.setAsDefault {
            writes.append("com.apple.Terminal:Window Settings")
            writes.append("com.apple.Terminal:Default Window Settings")
            writes.append("com.apple.Terminal:Startup Window Settings")
        }
        return writes
    }

    private func renderProfileDictionary(_ palette: PaletteDocument) throws -> [String: Any] {
        var profile: [String: Any] = [
            "name": config.profileName,
            "type": "Window Settings",
            "ProfileCurrentVersion": "2.09",
            "columnCount": 120,
            "rowCount": 30,
            "FontAntialias": true,
            "FontWidthSpacing": 1,
            "FontHeightSpacing": 1,
            "DynamicANSIForegroundColors": false,
            "BackgroundBlur": 0,
            "BackgroundBlurInactive": 0
        ]

        let colorKeys: [(String, String)] = [
            ("background", "BackgroundColor"),
            ("foreground", "TextColor"),
            ("foreground", "TextBoldColor"),
            ("cursor", "CursorColor"),
            ("selection", "SelectionColor"),
            ("black", "ANSIBlackColor"),
            ("red", "ANSIRedColor"),
            ("green", "ANSIGreenColor"),
            ("yellow", "ANSIYellowColor"),
            ("blue", "ANSIBlueColor"),
            ("magenta", "ANSIMagentaColor"),
            ("cyan", "ANSICyanColor"),
            ("white", "ANSIWhiteColor"),
            ("brightBlack", "ANSIBrightBlackColor"),
            ("brightRed", "ANSIBrightRedColor"),
            ("brightGreen", "ANSIBrightGreenColor"),
            ("brightYellow", "ANSIBrightYellowColor"),
            ("brightBlue", "ANSIBrightBlueColor"),
            ("brightMagenta", "ANSIBrightMagentaColor"),
            ("brightCyan", "ANSIBrightCyanColor"),
            ("brightWhite", "ANSIBrightWhiteColor")
        ]

        for (paletteKey, terminalKey) in colorKeys {
            guard let hex = palette.colors[paletteKey] else {
                throw MacwalError.adapterFailed("Palette is missing required color '\(paletteKey)'.")
            }
            profile[terminalKey] = try archiveColor(hex)
        }

        return profile
    }

    private func installAsDefault(profile: [String: Any]) throws {
        let defaults = DefaultsClient(paths: paths, executor: commandExecutor, fileSystem: fileSystem)
        let domain = "com.apple.Terminal"
        let keys = ["Window Settings", "Default Window Settings", "Startup Window Settings"]

        for key in keys {
            try backupManager.backupDefaultsBeforeWrite(
                domain: domain,
                key: key,
                value: try defaults.readValue(domain: domain, key: key),
                adapter: .terminal,
                dryRun: false
            )
        }

        // Add only our profile under "Window Settings" with `-dict-add`; every
        // other profile the user has defined is preserved. The whole-dictionary
        // read/merge/write this replaced would silently drop sibling profiles
        // whenever the read step returned an empty dictionary.
        try defaults.addDictionaryEntry(profile, forKey: config.profileName, domain: domain, key: "Window Settings")
        try defaults.setValue(config.profileName, domain: domain, key: "Default Window Settings")
        try defaults.setValue(config.profileName, domain: domain, key: "Startup Window Settings")
    }

    private func archiveColor(_ hex: String) throws -> Data {
        let rgb = try RGBColor(hex: hex)
        let color = NSColor(
            calibratedRed: CGFloat(rgb.red) / 255.0,
            green: CGFloat(rgb.green) / 255.0,
            blue: CGFloat(rgb.blue) / 255.0,
            alpha: 1.0
        )
        return try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true)
    }
}
