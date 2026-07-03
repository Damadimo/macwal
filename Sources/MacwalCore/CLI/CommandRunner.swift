import Foundation

public struct CommandRunResult: Equatable, Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
}

public struct CommandRunner {
    private let environment: RuntimeEnvironment
    private let wallpaperProvider: any WallpaperProviding
    private let fileSystem: FileSystem
    private let commandExecutor: CommandExecutor

    @MainActor
    public init(
        environment: RuntimeEnvironment = .live,
        wallpaperProvider: any WallpaperProviding = AppKitWallpaperProvider(),
        fileSystem: FileSystem = FileSystem(),
        commandExecutor: CommandExecutor? = nil
    ) {
        self.environment = environment
        self.wallpaperProvider = wallpaperProvider
        self.fileSystem = fileSystem
        self.commandExecutor = commandExecutor ?? CommandExecutor(environment: environment.environment)
    }

    @MainActor
    public func run(arguments: [String]) -> CommandRunResult {
        let wantsJSON = arguments.contains("--json")

        do {
            if arguments.isEmpty || arguments.contains("--help") || arguments.contains("-h") {
                return CommandRunResult(exitCode: 0, stdout: Self.helpText, stderr: "")
            }

            let command = arguments[0]
            let options = try CLIOptions(arguments: Array(arguments.dropFirst()))
            let paths = MacwalPaths(environment: environment)
            let configStore = ConfigStore(paths: paths, fileSystem: fileSystem)

            switch command {
            case "palette":
                let config = try configStore.load(createIfMissing: false)
                let palette = try buildPalette(options: options, paths: paths, config: config)
                if options.json {
                    return CommandRunResult(exitCode: 0, stdout: try palette.encodedJSON() + "\n", stderr: "")
                }
                return CommandRunResult(exitCode: 0, stdout: renderPaletteText(palette), stderr: "")

            case "preview":
                let config = try configStore.load(createIfMissing: false)
                let allowPrivate = options.allowPrivate || config.allowPrivateByDefault
                let targets = try selectedTargets(options: options, config: config, allowPrivate: allowPrivate)
                let palette = try buildPalette(options: options, paths: paths, config: config)
                let registry = AdapterRegistry(paths: paths, config: config, fileSystem: fileSystem, commandExecutor: commandExecutor)
                let plans = registry.preview(targets: targets, allowPrivate: allowPrivate)
                let response = CommandResponse(
                    command: "preview",
                    success: true,
                    messages: [.init(level: "info", text: "Preview generated for \(targets.count) target(s).")],
                    data: .object([
                        "palette": palette.jsonValue(),
                        "targets": .array(plans.map { $0.jsonValue() })
                    ])
                )
                return try output(response, json: options.json, text: renderPreviewText(plans))

            case "apply":
                let config = try configStore.load(createIfMissing: !options.dryRun)
                let allowPrivate = options.allowPrivate || config.allowPrivateByDefault
                let targets = try selectedTargets(options: options, config: config, allowPrivate: allowPrivate)
                let palette = try buildPalette(options: options, paths: paths, config: config)
                let registry = AdapterRegistry(paths: paths, config: config, fileSystem: fileSystem, commandExecutor: commandExecutor)
                let summaries = try registry.apply(targets: targets, palette: palette, allowPrivate: allowPrivate, dryRun: options.dryRun)
                let response = CommandResponse(
                    command: "apply",
                    success: true,
                    messages: [.init(level: "info", text: options.dryRun ? "Dry run completed." : "Apply completed.")],
                    data: .object([
                        "dryRun": .bool(options.dryRun),
                        "targets": .array(summaries.map { $0.jsonValue() })
                    ])
                )
                return try output(response, json: options.json, text: renderApplyText(summaries, dryRun: options.dryRun))

            case "restore":
                let config = try configStore.load(createIfMissing: false)
                let targets = try selectedTargetsForRestore(options: options, config: config)
                let backupManager = BackupManager(paths: paths, fileSystem: fileSystem, commandExecutor: commandExecutor)
                let summary = try backupManager.restore(targets: targets, dryRun: options.dryRun)
                let restoreMessages = try postRestoreMessages(targets: targets, config: config, dryRun: options.dryRun)
                let response = CommandResponse(
                    command: "restore",
                    success: true,
                    messages: [.init(level: "info", text: options.dryRun ? "Restore dry run completed." : "Restore completed.")] + restoreMessages,
                    data: .object([
                        "dryRun": .bool(options.dryRun),
                        "summary": summary.jsonValue()
                    ])
                )
                return try output(response, json: options.json, text: renderRestoreText(summary, dryRun: options.dryRun))

            case "doctor":
                let config = try configStore.loadOrCreate()
                let diagnostics = doctor(paths: paths, config: config)
                let response = CommandResponse(
                    command: "doctor",
                    success: true,
                    messages: [.init(level: "info", text: "Diagnostics completed.")],
                    data: diagnostics
                )
                return try output(response, json: options.json, text: renderDoctorText(diagnostics))

            case "list-targets":
                let targets = MacwalTarget.allCases.map(TargetInfo.init)
                let response = CommandResponse(
                    command: "list-targets",
                    success: true,
                    messages: [],
                    data: .object(["targets": .array(targets.map { $0.jsonValue() })])
                )
                return try output(response, json: options.json, text: renderTargetsText(targets))

            case "watch":
                let config = try configStore.load(createIfMissing: true)
                return try runWatch(arguments: Array(arguments.dropFirst()), paths: paths, config: config, json: wantsJSON)

            default:
                throw MacwalError.invalidArguments("Unknown command '\(command)'. Run 'macwal --help'.")
            }
        } catch let error as MacwalError {
            return errorResult(error, command: arguments.first ?? "macwal", json: wantsJSON)
        } catch {
            let wrapped = MacwalError.adapterFailed(error.localizedDescription)
            return errorResult(wrapped, command: arguments.first ?? "macwal", json: wantsJSON)
        }
    }

    @MainActor
    private func buildPalette(options: CLIOptions, paths: MacwalPaths, config: MacwalConfig) throws -> PaletteDocument {
        let sourceURL: URL
        let source: PaletteSource

        if let imagePath = options.image {
            let url = resolvePath(imagePath)
            sourceURL = url
            source = PaletteSource(kind: "image", path: url.path)
        } else {
            let wallpapers = try wallpaperProvider.wallpapers()
            guard !wallpapers.isEmpty else {
                throw MacwalError.paletteGenerationFailed("No desktop wallpaper image was reported by macOS. Pass --image PATH.")
            }
            let screenIndex = options.screenIndex ?? 0
            guard let wallpaper = wallpapers.first(where: { $0.index == screenIndex }) else {
                throw MacwalError.invalidArguments("Screen index \(screenIndex) is not available.")
            }
            sourceURL = wallpaper.url
            source = PaletteSource(
                kind: "wallpaper",
                path: wallpaper.url.path,
                screenIndex: wallpaper.index,
                displayID: wallpaper.displayID
            )
        }

        return try PaletteGenerator().generate(from: sourceURL, source: source, config: config.palette)
    }

    private func resolvePath(_ path: String) -> URL {
        let url = URL(fileURLWithPath: path)
        if url.path.hasPrefix("/") {
            return url.standardizedFileURL
        }
        return environment.currentDirectory.appendingPathComponent(path).standardizedFileURL
    }

    private func selectedTargets(options: CLIOptions, config: MacwalConfig, allowPrivate: Bool) throws -> [MacwalTarget] {
        if let targetString = options.targets {
            if targetString.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).contains("all") {
                return availableTargetsForAll(config: config, allowPrivate: allowPrivate)
            }
            return try MacwalTarget.parseList(targetString, allowPrivate: allowPrivate)
        }
        return try MacwalTarget.parseList(config.defaultTargets.joined(separator: ","), allowPrivate: allowPrivate)
    }

    private func availableTargetsForAll(config: MacwalConfig, allowPrivate: Bool) -> [MacwalTarget] {
        MacwalTarget.allCases.filter { target in
            if target.requiresAllowPrivate && !allowPrivate {
                return false
            }

            switch target {
            case .spotify:
                return commandExecutor.executablePath(config.adapters.spotify.spicetifyPath) != nil
            case .obsidian:
                return !config.adapters.obsidian.vaults.isEmpty
            case .finder:
                return allowPrivate && config.adapters.finder.setFolderTint && ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26
            case .system:
                return allowPrivate
                    && (config.adapters.system.setAppearanceMode || config.adapters.system.setAccentColor || config.adapters.system.setHighlightColor)
            case .firefox, .librewolf, .zen, .floorp, .alacritty, .kitty, .wezterm, .ghostty, .iterm2, .vscode, .zed, .vim, .neovim, .tmux, .starship, .bat, .btop, .yazi, .fzf, .lazygit, .aerospace, .yabai, .sketchybar, .jankyBorders, .hammerspoon, .raycast, .alfred, .discord, .thunderbird, .telegram, .slack:
                return false
            case .shell, .terminal, .chrome, .safari:
                return true
            }
        }
    }

    private func selectedTargetsForRestore(options: CLIOptions, config: MacwalConfig) throws -> [MacwalTarget] {
        if let targetString = options.targets {
            return try MacwalTarget.parseList(targetString, allowPrivate: true)
        }
        return try MacwalTarget.parseList(MacwalTarget.allCases.map(\.rawValue).joined(separator: ","), allowPrivate: true)
    }

    private func postRestoreMessages(targets: [MacwalTarget], config: MacwalConfig, dryRun: Bool) throws -> [ResponseMessage] {
        guard !dryRun else {
            return []
        }

        var messages: [ResponseMessage] = []
        if targets.contains(.system) {
            for name in ["AppleColorPreferencesChangedNotification", "AppleAquaColorVariantChanged"] {
                DistributedNotificationCenter.default().post(name: Notification.Name(name), object: nil)
            }
            messages.append(.init(level: "info", text: "Posted macOS appearance-change notifications after system restore."))
        }

        if targets.contains(.spotify) {
            if commandExecutor.executablePath(config.adapters.spotify.spicetifyPath) != nil {
                let result = try commandExecutor.run(executable: config.adapters.spotify.spicetifyPath, arguments: ["apply"])
                if result.exitCode == 0 {
                    messages.append(.init(level: "info", text: "Ran spicetify apply after Spotify restore."))
                } else {
                    messages.append(.init(level: "warning", text: "Spotify files were restored, but spicetify apply failed: \(result.stderrText)"))
                }
            } else {
                messages.append(.init(level: "warning", text: "Spotify files were restored, but Spicetify was not found for reapply."))
            }
        }

        return messages
    }

    private func output(_ response: CommandResponse, json: Bool, text: String) throws -> CommandRunResult {
        if json {
            return CommandRunResult(exitCode: 0, stdout: try response.encodedJSON() + "\n", stderr: "")
        }
        return CommandRunResult(exitCode: 0, stdout: text, stderr: "")
    }

    private func errorResult(_ error: MacwalError, command: String, json: Bool) -> CommandRunResult {
        if json {
            let response = CommandResponse(
                command: command,
                success: false,
                messages: [.init(level: "error", text: error.localizedDescription)]
            )
            let encoded = (try? response.encodedJSON()) ?? "{\"success\":false}\n"
            return CommandRunResult(exitCode: error.exitCode, stdout: encoded + "\n", stderr: "")
        }
        return CommandRunResult(exitCode: error.exitCode, stdout: "", stderr: error.localizedDescription + "\n")
    }

    @MainActor
    private func runWatch(arguments: [String], paths: MacwalPaths, config: MacwalConfig, json: Bool) throws -> CommandRunResult {
        let subcommand = arguments.first ?? ""
        let options = try CLIOptions(arguments: Array(arguments.dropFirst()))
        let allowPrivate = options.allowPrivate || config.allowPrivateByDefault
        let targets = try selectedTargets(options: options, config: config, allowPrivate: allowPrivate)

        switch subcommand {
        case "install":
            let result = try installWatcher(paths: paths, targets: targets, allowPrivate: allowPrivate)
            let response = CommandResponse(
                command: "watch install",
                success: true,
                messages: [.init(level: "info", text: result.message)],
                data: .object([
                    "launchAgent": .string(paths.launchAgent.path),
                    "programArguments": .array(result.programArguments.map(JSONValue.string))
                ])
            )
            return try output(response, json: json, text: result.message + "\n")
        case "uninstall":
            let message = try uninstallWatcher(paths: paths)
            let response = CommandResponse(
                command: "watch uninstall",
                success: true,
                messages: [.init(level: "info", text: message)],
                data: .object(["launchAgent": .string(paths.launchAgent.path)])
            )
            return try output(response, json: json, text: message + "\n")
        case "run":
            let result = try runWatcherOnce(paths: paths, config: config, options: options, targets: targets, allowPrivate: allowPrivate)
            let response = CommandResponse(
                command: "watch run",
                success: true,
                messages: [.init(level: "info", text: result.message)],
                data: result.data
            )
            return try output(response, json: json, text: result.message + "\n")
        default:
            throw MacwalError.invalidArguments("Expected 'macwal watch install', 'macwal watch uninstall', or 'macwal watch run'.")
        }
    }

    private struct WatchInstallResult {
        let message: String
        let programArguments: [String]
    }

    private struct WatchRunResult {
        let message: String
        let data: JSONValue
    }

    private struct WatchState: Codable, Equatable {
        let schemaVersion: Int
        let signature: String
        let appliedAt: String
    }

    private func installWatcher(paths: MacwalPaths, targets: [MacwalTarget], allowPrivate: Bool) throws -> WatchInstallResult {
        try fileSystem.ensureDirectory(paths.launchAgent.deletingLastPathComponent())
        try fileSystem.ensureDirectory(paths.logs)

        let executable = currentExecutablePath()
        var programArguments = [
            executable,
            "watch",
            "run",
            "--targets",
            targets.map(\.rawValue).joined(separator: ",")
        ]
        if allowPrivate {
            programArguments.append("--allow-private")
        }

        let plist: [String: Any] = [
            "Label": "io.macwal.watch",
            "ProgramArguments": programArguments,
            "RunAtLoad": true,
            "StartInterval": 300,
            "StandardOutPath": paths.logs.appendingPathComponent("watch.log").path,
            "StandardErrorPath": paths.logs.appendingPathComponent("watch.log").path
        ]

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try fileSystem.atomicWrite(data, to: paths.launchAgent)

        var message = "Watcher LaunchAgent installed at \(paths.launchAgent.path)."
        if environment.environment["MACWAL_SKIP_LAUNCHCTL"] != "1" {
            _ = try? commandExecutor.run(executable: "/bin/launchctl", arguments: ["unload", paths.launchAgent.path])
            let load = try commandExecutor.run(executable: "/bin/launchctl", arguments: ["load", paths.launchAgent.path])
            if load.exitCode == 0 {
                message += " launchctl load completed."
            } else {
                message += " launchctl load failed: \(load.stderrText.trimmingCharacters(in: .whitespacesAndNewlines))"
            }
        }

        return WatchInstallResult(message: message, programArguments: programArguments)
    }

    private func uninstallWatcher(paths: MacwalPaths) throws -> String {
        if fileSystem.fileExists(paths.launchAgent), environment.environment["MACWAL_SKIP_LAUNCHCTL"] != "1" {
            _ = try? commandExecutor.run(executable: "/bin/launchctl", arguments: ["unload", paths.launchAgent.path])
        }
        try fileSystem.removeIfExists(paths.launchAgent)
        return "Watcher LaunchAgent removed from \(paths.launchAgent.path)."
    }

    @MainActor
    private func runWatcherOnce(
        paths: MacwalPaths,
        config: MacwalConfig,
        options: CLIOptions,
        targets: [MacwalTarget],
        allowPrivate: Bool
    ) throws -> WatchRunResult {
        let palette = try buildPalette(options: options, paths: paths, config: config)
        let signature = try watchSignature(palette: palette, targets: targets, allowPrivate: allowPrivate)
        let stateURL = paths.appSupport.appendingPathComponent("watch-state.json")

        if let existingState = try loadWatchState(from: stateURL), existingState.signature == signature {
            return WatchRunResult(
                message: "No wallpaper or target changes detected; no adapters were applied.",
                data: .object([
                    "changed": .bool(false),
                    "signature": .string(signature)
                ])
            )
        }

        let registry = AdapterRegistry(paths: paths, config: config, fileSystem: fileSystem, commandExecutor: commandExecutor)
        let summaries = try registry.apply(targets: targets, palette: palette, allowPrivate: allowPrivate, dryRun: false)
        let state = WatchState(schemaVersion: 1, signature: signature, appliedAt: Self.isoString(from: Date()))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try fileSystem.atomicWrite(try encoder.encode(state), to: stateURL)

        return WatchRunResult(
            message: "Wallpaper change detected; applied \(summaries.count) target(s).",
            data: .object([
                "changed": .bool(true),
                "signature": .string(signature),
                "targets": .array(summaries.map { $0.jsonValue() })
            ])
        )
    }

    private func loadWatchState(from url: URL) throws -> WatchState? {
        guard fileSystem.fileExists(url) else {
            return nil
        }
        return try JSONDecoder().decode(WatchState.self, from: Data(contentsOf: url))
    }

    private func watchSignature(palette: PaletteDocument, targets: [MacwalTarget], allowPrivate: Bool) throws -> String {
        let sourceURL = URL(fileURLWithPath: palette.source.path)
        let attributes = try? FileManager.default.attributesOfItem(atPath: sourceURL.path)
        let modified = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        return [
            palette.source.path,
            String(modified),
            String(size),
            targets.map(\.rawValue).joined(separator: ","),
            allowPrivate ? "private" : "public"
        ].joined(separator: "|")
    }

    private func currentExecutablePath() -> String {
        let raw = environment.environment["MACWAL_EXECUTABLE"] ?? CommandLine.arguments.first ?? "macwal"
        if raw.hasPrefix("/") {
            return raw
        }
        return environment.currentDirectory.appendingPathComponent(raw).standardizedFileURL.path
    }

    private static func isoString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private func doctor(paths: MacwalPaths, config: MacwalConfig) -> JSONValue {
        let targetDiagnostics = MacwalTarget.allCases.map { target in
            JSONValue.object([
                "target": .string(target.rawValue),
                "classification": .string(target.classification.rawValue),
                "defaultEnabled": .bool(config.defaultTargets.contains(target.rawValue)),
                "status": .string(doctorStatus(for: target, config: config)),
                "remediation": .string(remediation(for: target))
            ])
        }

        return .object([
            "paths": .object([
                "appSupport": .string(paths.appSupport.path),
                "cache": .string(paths.cache.path),
                "configFile": .string(paths.configFile.path),
                "launchAgent": .string(paths.launchAgent.path)
            ]),
            "environment": .object([
                "macOSVersion": .string(ProcessInfo.processInfo.operatingSystemVersionString),
                "appSupportWritable": .bool(FileManager.default.isWritableFile(atPath: paths.appSupport.path)),
                "launchAgentInstalled": .bool(fileSystem.fileExists(paths.launchAgent))
            ]),
            "targets": .array(targetDiagnostics)
        ])
    }

    private func doctorStatus(for target: MacwalTarget, config: MacwalConfig) -> String {
        switch target {
        case .spotify:
            return commandExecutor.executablePath(config.adapters.spotify.spicetifyPath) == nil
                ? "missing optional prerequisite"
                : "available"
        case .obsidian:
            return config.adapters.obsidian.vaults.isEmpty ? "needs configuration" : "configured"
        case .system:
            return (config.adapters.system.setAppearanceMode || config.adapters.system.setAccentColor || config.adapters.system.setHighlightColor)
                ? "configured private"
                : "available noop"
        case .finder:
            if ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 26 {
                return "unavailable on this macOS version"
            }
            return config.adapters.finder.setFolderTint ? "configured private" : "available noop"
        case .firefox, .librewolf, .zen, .floorp, .thunderbird:
            return "available; preview detects profiles"
        case .yabai, .sketchybar, .jankyBorders, .aerospace:
            if let executable = target.requiresExternalTool, commandExecutor.executablePath(executable) == nil {
                return "missing optional prerequisite"
            }
            return "available"
        case .chrome, .safari, .shell, .terminal, .alacritty, .kitty, .wezterm, .ghostty, .iterm2, .vscode, .zed, .vim, .neovim, .tmux, .starship, .bat, .btop, .yazi, .fzf, .lazygit, .hammerspoon, .raycast, .alfred, .discord, .telegram, .slack:
            return "available"
        }
    }

    private func remediation(for target: MacwalTarget) -> String {
        switch target {
        case .spotify:
            "Install Spicetify before enabling the Spotify adapter."
        case .system, .finder:
            "Run with --allow-private only after reviewing private adapter risks."
        case .obsidian:
            "Add vault paths to config.json before applying the Obsidian adapter."
        case .chrome:
            "Chrome has no supported per-user silent theme activation API; load the generated theme folder from chrome://extensions."
        case .terminal:
            "No action required; macwal installs the generated Terminal profile unless setAsDefault is disabled."
        case .firefox, .librewolf, .zen, .floorp, .thunderbird:
            "Close and reopen the app after applying profile CSS."
        case .raycast, .alfred, .telegram, .slack:
            "macwal can generate palette assets, but this app does not expose stable theme dotfiles for automatic activation."
        case .aerospace, .yabai, .sketchybar, .jankyBorders:
            "Install the corresponding CLI tool before using this target."
        default:
            "No action required for the current implementation stage."
        }
    }

    private func renderPaletteText(_ palette: PaletteDocument) -> String {
        var lines = [
            "source: \(palette.source.path)",
            "mode: \(palette.appearance.recommendedMode)",
            "contrast validated: \(palette.appearance.contrastValidated ? "yes" : "no")"
        ]
        for key in palette.colors.keys.sorted() {
            lines.append("\(key): \(palette.colors[key] ?? "")")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func renderPreviewText(_ plans: [AdapterPlan]) -> String {
        plans.map { plan in
            "\(plan.target.rawValue): \(plan.status) - \(plan.messages.joined(separator: " "))"
        }.joined(separator: "\n") + "\n"
    }

    private func renderApplyText(_ summaries: [AdapterApplySummary], dryRun: Bool) -> String {
        var lines = [dryRun ? "dry run completed" : "apply completed"]
        for summary in summaries {
            lines.append("\(summary.target.rawValue): \(summary.changedPaths.count) path(s)")
            lines.append(contentsOf: summary.messages.map { "  \($0)" })
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func renderRestoreText(_ summary: RestoreSummary, dryRun: Bool) -> String {
        [
            dryRun ? "restore dry run completed" : "restore completed",
            "restored: \(summary.restored.count)",
            "removed: \(summary.removed.count)"
        ].joined(separator: "\n") + "\n"
    }

    private func renderDoctorText(_ diagnostics: JSONValue) -> String {
        guard case .object(let object) = diagnostics,
              case .array(let targets)? = object["targets"] else {
            return "diagnostics completed\n"
        }
        var lines = ["diagnostics completed"]
        for target in targets {
            guard case .object(let item) = target,
                  case .string(let name)? = item["target"],
                  case .string(let status)? = item["status"] else {
                continue
            }
            lines.append("\(name): \(status)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func renderTargetsText(_ targets: [TargetInfo]) -> String {
        targets.map { "\($0.name): \($0.classification)" }.joined(separator: "\n") + "\n"
    }

    public static let helpText = """
    macwal

    Usage:
      macwal palette [--image PATH] [--screen INDEX] [--json]
      macwal preview [--image PATH] [--targets TARGETS] [--allow-private] [--json]
      macwal apply [--image PATH] [--targets TARGETS] [--allow-private] [--dry-run] [--json]
      macwal restore [--targets TARGETS] [--dry-run] [--json]
      macwal watch install [--targets TARGETS] [--allow-private]
      macwal watch uninstall
      macwal watch run [--targets TARGETS] [--allow-private]
      macwal doctor [--json]
      macwal list-targets [--json]

    Targets:
      Run `macwal list-targets` for the full target list.

    """
}

private struct CLIOptions {
    var image: String?
    var screenIndex: Int?
    var targets: String?
    var json = false
    var dryRun = false
    var allowPrivate = false

    init(arguments: [String]) throws {
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]

            if argument == "--json" {
                json = true
            } else if argument == "--dry-run" {
                dryRun = true
            } else if argument == "--allow-private" {
                allowPrivate = true
            } else if argument == "--image" {
                index += 1
                guard index < arguments.count else {
                    throw MacwalError.invalidArguments("--image requires a path.")
                }
                image = arguments[index]
            } else if argument.hasPrefix("--image=") {
                image = String(argument.dropFirst("--image=".count))
            } else if argument == "--screen" {
                index += 1
                guard index < arguments.count, let value = Int(arguments[index]) else {
                    throw MacwalError.invalidArguments("--screen requires an integer.")
                }
                screenIndex = value
            } else if argument.hasPrefix("--screen=") {
                guard let value = Int(argument.dropFirst("--screen=".count)) else {
                    throw MacwalError.invalidArguments("--screen requires an integer.")
                }
                screenIndex = value
            } else if argument == "--targets" {
                index += 1
                guard index < arguments.count else {
                    throw MacwalError.invalidArguments("--targets requires a comma-separated target list.")
                }
                targets = arguments[index]
            } else if argument.hasPrefix("--targets=") {
                targets = String(argument.dropFirst("--targets=".count))
            } else if !argument.hasPrefix("--") {
                // Subcommands such as "watch install" are handled by the command itself.
            } else {
                throw MacwalError.invalidArguments("Unknown option '\(argument)'.")
            }

            index += 1
        }
    }
}
