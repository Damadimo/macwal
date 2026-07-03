import Foundation

public struct SystemAdapter {
    private struct AccentCandidate {
        let name: String
        let value: Int
        let color: RGBColor
    }

    public let paths: MacwalPaths
    public let config: MacwalConfig.SystemConfig
    public let fileSystem: FileSystem
    public let backupManager: BackupManager
    public let commandExecutor: CommandExecutor

    private let domain = "-globalDomain"

    public init(
        paths: MacwalPaths,
        config: MacwalConfig.SystemConfig,
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

    public func preview(palette: PaletteDocument?) -> AdapterPlan {
        var writes: [String] = []
        if config.setAppearanceMode {
            writes.append("\(domain):AppleInterfaceStyle")
            writes.append("\(domain):AppleInterfaceStyleSwitchesAutomatically")
        }
        if config.setAccentColor {
            writes.append("\(domain):AppleAccentColor")
        }
        if config.setHighlightColor {
            writes.append("\(domain):AppleHighlightColor")
        }

        return AdapterPlan(
            target: .system,
            status: writes.isEmpty ? "noop" : "ready",
            plannedWrites: writes,
            messages: writes.isEmpty
                ? ["System adapter is enabled but no system settings are enabled in config.json."]
                : ["Private macOS defaults writes are enabled for configured system settings."]
        )
    }

    public func apply(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        let defaults = DefaultsClient(paths: paths, executor: commandExecutor, fileSystem: fileSystem)
        var changed: [String] = []
        var messages: [String] = []

        if config.setAppearanceMode {
            try backupPreference(defaults: defaults, key: "AppleInterfaceStyle", dryRun: dryRun)
            try backupPreference(defaults: defaults, key: "AppleInterfaceStyleSwitchesAutomatically", dryRun: dryRun)
            changed.append("\(domain):AppleInterfaceStyle")
            changed.append("\(domain):AppleInterfaceStyleSwitchesAutomatically")

            if !dryRun {
                if palette.appearance.recommendedMode == "dark" {
                    try defaults.setValue("Dark", domain: domain, key: "AppleInterfaceStyle")
                } else {
                    try defaults.deleteValue(domain: domain, key: "AppleInterfaceStyle")
                }
                try defaults.setValue(false, domain: domain, key: "AppleInterfaceStyleSwitchesAutomatically")
            }
            messages.append("System appearance mode set to \(palette.appearance.recommendedMode).")
        }

        if config.setAccentColor {
            try backupPreference(defaults: defaults, key: "AppleAccentColor", dryRun: dryRun)
            let accent = try nearestAccentColor(for: palette)
            changed.append("\(domain):AppleAccentColor")
            if !dryRun {
                try defaults.setValue(accent.value, domain: domain, key: "AppleAccentColor")
            }
            messages.append("Accent color mapped to \(accent.name).")
        }

        if config.setHighlightColor {
            try backupPreference(defaults: defaults, key: "AppleHighlightColor", dryRun: dryRun)
            changed.append("\(domain):AppleHighlightColor")
            if !dryRun {
                try defaults.setValue(try highlightColorString(for: palette), domain: domain, key: "AppleHighlightColor")
            }
            messages.append("Text highlight color set from palette accent.")
        }

        if !dryRun && !changed.isEmpty {
            postAppearanceNotifications()
        }

        if changed.isEmpty {
            messages.append("No system settings are enabled in config.json.")
        }

        return AdapterApplySummary(
            target: .system,
            changedPaths: changed,
            messages: dryRun ? messages.map { "Dry run: \($0)" } : messages
        )
    }

    private func backupPreference(defaults: DefaultsClient, key: String, dryRun: Bool) throws {
        let value = try defaults.readValue(domain: domain, key: key)
        try backupManager.backupDefaultsBeforeWrite(domain: domain, key: key, value: value, adapter: .system, dryRun: dryRun)
    }

    private func nearestAccentColor(for palette: PaletteDocument) throws -> AccentCandidate {
        guard let hex = palette.colors["accent"] else {
            throw MacwalError.adapterFailed("Palette is missing required color 'accent'.")
        }
        let accent = try RGBColor(hex: hex)
        return Self.accentCandidates.min { lhs, rhs in
            distance(lhs.color, accent) < distance(rhs.color, accent)
        } ?? Self.accentCandidates[4]
    }

    private func highlightColorString(for palette: PaletteDocument) throws -> String {
        guard let hex = palette.colors["accent"] else {
            throw MacwalError.adapterFailed("Palette is missing required color 'accent'.")
        }
        let accent = try RGBColor(hex: hex)
        return String(
            format: "%.6f %.6f %.6f",
            Double(accent.red) / 255.0,
            Double(accent.green) / 255.0,
            Double(accent.blue) / 255.0
        )
    }

    private func distance(_ lhs: RGBColor, _ rhs: RGBColor) -> Double {
        let red = Double(lhs.red) - Double(rhs.red)
        let green = Double(lhs.green) - Double(rhs.green)
        let blue = Double(lhs.blue) - Double(rhs.blue)
        return red * red + green * green + blue * blue
    }

    private func postAppearanceNotifications() {
        for name in ["AppleColorPreferencesChangedNotification", "AppleAquaColorVariantChanged"] {
            DistributedNotificationCenter.default().post(name: Notification.Name(name), object: nil)
        }
    }

    private static let accentCandidates: [AccentCandidate] = [
        AccentCandidate(name: "red", value: 0, color: RGBColor(red: 255, green: 59, blue: 48)),
        AccentCandidate(name: "orange", value: 1, color: RGBColor(red: 255, green: 149, blue: 0)),
        AccentCandidate(name: "yellow", value: 2, color: RGBColor(red: 255, green: 204, blue: 0)),
        AccentCandidate(name: "green", value: 3, color: RGBColor(red: 52, green: 199, blue: 89)),
        AccentCandidate(name: "blue", value: 4, color: RGBColor(red: 0, green: 122, blue: 255)),
        AccentCandidate(name: "purple", value: 5, color: RGBColor(red: 175, green: 82, blue: 222)),
        AccentCandidate(name: "pink", value: 6, color: RGBColor(red: 255, green: 45, blue: 85)),
        AccentCandidate(name: "graphite", value: -1, color: RGBColor(red: 142, green: 142, blue: 147))
    ]
}
