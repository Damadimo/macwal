import Foundation

public struct AdapterRegistry {
    public let paths: MacwalPaths
    public let config: MacwalConfig
    public let fileSystem: FileSystem
    public let commandExecutor: CommandExecutor

    public init(
        paths: MacwalPaths,
        config: MacwalConfig,
        fileSystem: FileSystem = FileSystem(),
        commandExecutor: CommandExecutor = CommandExecutor()
    ) {
        self.paths = paths
        self.config = config
        self.fileSystem = fileSystem
        self.commandExecutor = commandExecutor
    }

    public func preview(targets: [MacwalTarget], allowPrivate: Bool) -> [AdapterPlan] {
        targets.map { target in
            if target.requiresAllowPrivate && !allowPrivate {
                return AdapterPlan(
                    target: target,
                    status: "blocked",
                    messages: ["Requires --allow-private and performs no writes without it."]
                )
            }

            switch target {
            case .shell:
                return ShellAdapter(paths: paths, fileSystem: fileSystemFor(target: .shell), backupManager: backupManager(for: .shell)).preview()
            case .terminal:
                return TerminalAdapter(paths: paths, config: config.adapters.terminal, fileSystem: fileSystemFor(target: .terminal), backupManager: backupManager(for: .terminal), commandExecutor: commandExecutor, opacity: config.adapters.terminalOpacity).preview()
            case .obsidian:
                return ObsidianAdapter(paths: paths, config: config.adapters.obsidian, fileSystem: fileSystemFor(target: .obsidian), backupManager: backupManager(for: .obsidian)).preview()
            case .chrome:
                return ChromeAdapter(paths: paths, fileSystem: fileSystemFor(target: .chrome), backupManager: backupManager(for: .chrome)).preview()
            case .firefox, .librewolf, .zen, .floorp, .alacritty, .kitty, .wezterm, .ghostty, .iterm2, .vscode, .zed, .vim, .neovim, .tmux, .starship, .bat, .btop, .yazi, .fzf, .lazygit, .aerospace, .yabai, .sketchybar, .jankyBorders, .hammerspoon, .raycast, .alfred, .discord, .thunderbird, .telegram, .slack:
                return GeneratedAppAdapter(target: target, paths: paths, fileSystem: fileSystemFor(target: target), backupManager: backupManager(for: target), commandExecutor: commandExecutor, terminalOpacity: config.adapters.terminalOpacity).preview()
            case .safari:
                return AdapterPlan(
                    target: .safari,
                    status: "noop",
                    messages: ["Safari inherits system appearance; no Safari chrome files or preferences are modified."]
                )
            case .spotify:
                return SpotifyAdapter(paths: paths, config: config.adapters.spotify, fileSystem: fileSystemFor(target: .spotify), backupManager: backupManager(for: .spotify), commandExecutor: commandExecutor).preview()
            case .system:
                return SystemAdapter(paths: paths, config: config.adapters.system, fileSystem: fileSystemFor(target: .system), backupManager: backupManager(for: .system), commandExecutor: commandExecutor).preview()
            case .finder:
                return FinderAdapter(paths: paths, config: config.adapters.finder, fileSystem: fileSystemFor(target: .finder), backupManager: backupManager(for: .finder)).preview()
            }
        }
    }

    public func apply(targets: [MacwalTarget], palette: PaletteDocument, allowPrivate: Bool, dryRun: Bool) throws -> [AdapterApplySummary] {
        var summaries: [AdapterApplySummary] = []
        for target in targets {
            if target.requiresAllowPrivate && !allowPrivate && !dryRun {
                throw MacwalError.permissionDenied("Target '\(target.rawValue)' requires --allow-private.")
            }
            switch target {
            case .shell:
                summaries.append(try ShellAdapter(paths: paths, fileSystem: fileSystemFor(target: .shell), backupManager: backupManager(for: .shell)).apply(palette: palette, dryRun: dryRun))
            case .terminal:
                summaries.append(try TerminalAdapter(paths: paths, config: config.adapters.terminal, fileSystem: fileSystemFor(target: .terminal), backupManager: backupManager(for: .terminal), commandExecutor: commandExecutor, opacity: config.adapters.terminalOpacity).apply(palette: palette, dryRun: dryRun))
            case .obsidian:
                summaries.append(try ObsidianAdapter(paths: paths, config: config.adapters.obsidian, fileSystem: fileSystemFor(target: .obsidian), backupManager: backupManager(for: .obsidian)).apply(palette: palette, dryRun: dryRun))
            case .chrome:
                summaries.append(try ChromeAdapter(paths: paths, fileSystem: fileSystemFor(target: .chrome), backupManager: backupManager(for: .chrome)).apply(palette: palette, dryRun: dryRun))
            case .firefox, .librewolf, .zen, .floorp, .alacritty, .kitty, .wezterm, .ghostty, .iterm2, .vscode, .zed, .vim, .neovim, .tmux, .starship, .bat, .btop, .yazi, .fzf, .lazygit, .aerospace, .yabai, .sketchybar, .jankyBorders, .hammerspoon, .raycast, .alfred, .discord, .thunderbird, .telegram, .slack:
                summaries.append(try GeneratedAppAdapter(target: target, paths: paths, fileSystem: fileSystemFor(target: target), backupManager: backupManager(for: target), commandExecutor: commandExecutor, terminalOpacity: config.adapters.terminalOpacity).apply(palette: palette, dryRun: dryRun))
            case .safari:
                summaries.append(AdapterApplySummary(
                    target: .safari,
                    changedPaths: [],
                    messages: ["Safari inherits system appearance; no writes performed."]
                ))
            case .spotify:
                summaries.append(try SpotifyAdapter(paths: paths, config: config.adapters.spotify, fileSystem: fileSystemFor(target: .spotify), backupManager: backupManager(for: .spotify), commandExecutor: commandExecutor).apply(palette: palette, dryRun: dryRun))
            case .system:
                summaries.append(try SystemAdapter(paths: paths, config: config.adapters.system, fileSystem: fileSystemFor(target: .system), backupManager: backupManager(for: .system), commandExecutor: commandExecutor).apply(palette: palette, dryRun: dryRun))
            case .finder:
                summaries.append(try FinderAdapter(paths: paths, config: config.adapters.finder, fileSystem: fileSystemFor(target: .finder), backupManager: backupManager(for: .finder)).apply(palette: palette, dryRun: dryRun))
            }
        }
        return summaries
    }

    /// Targets that should be themed by `macwal set` — every supported target the
    /// user actually has installed. Private targets (system/finder) are only
    /// included when `allowPrivate` is set, and Safari is skipped because it has
    /// nothing to write (it inherits system appearance).
    public func installedSupportedTargets(allowPrivate: Bool) -> [MacwalTarget] {
        MacwalTarget.allCases.filter { target in
            if target == .safari {
                return false
            }
            if target.requiresAllowPrivate && !allowPrivate {
                return false
            }
            return isInstalled(target)
        }
    }

    /// Best-effort detection of whether a target's application/tool is present.
    /// Uses the app bundle, a CLI on PATH, or a config directory — whichever is a
    /// reliable signal for that target.
    public func isInstalled(_ target: MacwalTarget) -> Bool {
        switch target {
        case .system, .finder, .safari, .shell, .terminal:
            return true
        case .obsidian:
            return !config.adapters.obsidian.vaults.isEmpty
        case .spotify:
            return commandExecutor.executablePath(config.adapters.spotify.spicetifyPath) != nil
        case .chrome:
            return appExists("Google Chrome")
        case .firefox:
            return appExists("Firefox")
        case .librewolf:
            return appExists("LibreWolf")
        case .zen:
            return appExists("Zen") || appExists("Zen Browser")
        case .floorp:
            return appExists("Floorp")
        case .thunderbird:
            return appExists("Thunderbird") || dirExists("Library/Thunderbird")
        case .alacritty:
            return appExists("Alacritty") || cliExists("alacritty") || dirExists(".config/alacritty")
        case .kitty:
            return appExists("kitty") || cliExists("kitty") || dirExists(".config/kitty")
        case .wezterm:
            return appExists("WezTerm") || cliExists("wezterm") || dirExists(".config/wezterm")
        case .ghostty:
            return appExists("Ghostty") || cliExists("ghostty") || dirExists(".config/ghostty")
        case .iterm2:
            return appExists("iTerm")
        case .vscode:
            return appExists("Visual Studio Code") || cliExists("code") || dirExists("Library/Application Support/Code")
        case .zed:
            return appExists("Zed") || cliExists("zed") || dirExists(".config/zed")
        case .vim:
            return fileExists(".vimrc") || cliExists("vim")
        case .neovim:
            return cliExists("nvim") || dirExists(".config/nvim")
        case .tmux:
            return cliExists("tmux") || fileExists(".tmux.conf") || dirExists(".config/tmux")
        case .starship:
            return cliExists("starship") || fileExists(".config/starship.toml")
        case .bat:
            return cliExists("bat") || dirExists(".config/bat")
        case .btop:
            return cliExists("btop") || dirExists(".config/btop")
        case .yazi:
            return cliExists("yazi") || dirExists(".config/yazi")
        case .fzf:
            return cliExists("fzf")
        case .lazygit:
            return cliExists("lazygit") || dirExists(".config/lazygit") || dirExists("Library/Application Support/lazygit")
        case .aerospace:
            return appExists("AeroSpace") || cliExists("aerospace") || dirExists(".config/aerospace")
        case .yabai:
            return cliExists("yabai")
        case .sketchybar:
            return cliExists("sketchybar")
        case .jankyBorders:
            return cliExists("borders")
        case .hammerspoon:
            return appExists("Hammerspoon") || dirExists(".hammerspoon")
        case .raycast:
            return appExists("Raycast")
        case .alfred:
            return appExists("Alfred") || appExists("Alfred 5")
        case .discord:
            return appExists("Discord") || dirExists(".config/Vencord/themes") || dirExists("Library/Application Support/BetterDiscord/themes")
        case .telegram:
            return appExists("Telegram")
        case .slack:
            return appExists("Slack")
        }
    }

    private func appExists(_ name: String) -> Bool {
        let candidates = [
            URL(fileURLWithPath: "/Applications").appendingPathComponent("\(name).app"),
            paths.home.appendingPathComponent("Applications/\(name).app"),
            URL(fileURLWithPath: "/System/Applications").appendingPathComponent("\(name).app")
        ]
        return candidates.contains { fileSystem.fileExists($0) }
    }

    private func cliExists(_ tool: String) -> Bool {
        commandExecutor.executablePath(tool) != nil
    }

    private func dirExists(_ relativePath: String) -> Bool {
        fileSystem.isDirectory(paths.home.appendingPathComponent(relativePath))
    }

    private func fileExists(_ relativePath: String) -> Bool {
        fileSystem.fileExists(paths.home.appendingPathComponent(relativePath))
    }

    private func backupManager(for target: MacwalTarget) -> BackupManager {
        BackupManager(paths: paths, fileSystem: fileSystemFor(target: target), commandExecutor: commandExecutor)
    }

    private func fileSystemFor(target: MacwalTarget) -> FileSystem {
        fileSystem.restricted(to: writeRoots(for: target))
    }

    private func writeRoots(for target: MacwalTarget) -> [URL] {
        switch target {
        case .shell, .chrome:
            [paths.appSupport]
        case .firefox, .librewolf, .zen, .floorp, .alacritty, .kitty, .wezterm, .ghostty, .iterm2, .vscode, .zed, .vim, .neovim, .tmux, .starship, .bat, .btop, .yazi, .fzf, .lazygit, .aerospace, .yabai, .sketchybar, .jankyBorders, .hammerspoon, .raycast, .alfred, .discord, .thunderbird, .telegram, .slack:
            GeneratedAppAdapter.writeRoots(for: target, paths: paths, environment: commandExecutor.environment)
        case .terminal:
            [paths.appSupport, paths.cache]
        case .obsidian:
            [paths.appSupport] + config.adapters.obsidian.vaults.map { MacwalPaths.resolve($0, home: paths.home) }
        case .spotify:
            [paths.appSupport, paths.home.appendingPathComponent(".config/spicetify", isDirectory: true)]
        case .safari:
            [paths.appSupport]
        case .system:
            [paths.appSupport, paths.cache]
        case .finder:
            [paths.appSupport] + config.adapters.finder.folders.map { MacwalPaths.resolve($0, home: paths.home) }
        }
    }
}
