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
                return TerminalAdapter(paths: paths, config: config.adapters.terminal, fileSystem: fileSystemFor(target: .terminal), backupManager: backupManager(for: .terminal), commandExecutor: commandExecutor).preview()
            case .obsidian:
                return ObsidianAdapter(paths: paths, config: config.adapters.obsidian, fileSystem: fileSystemFor(target: .obsidian), backupManager: backupManager(for: .obsidian)).preview()
            case .chrome:
                return ChromeAdapter(paths: paths, fileSystem: fileSystemFor(target: .chrome), backupManager: backupManager(for: .chrome)).preview()
            case .firefox, .librewolf, .zen, .floorp, .alacritty, .kitty, .wezterm, .ghostty, .iterm2, .vscode, .zed, .vim, .neovim, .tmux, .starship, .bat, .btop, .yazi, .fzf, .lazygit, .aerospace, .yabai, .sketchybar, .jankyBorders, .hammerspoon, .raycast, .alfred, .discord, .thunderbird, .telegram, .slack:
                return GeneratedAppAdapter(target: target, paths: paths, fileSystem: fileSystemFor(target: target), backupManager: backupManager(for: target), commandExecutor: commandExecutor).preview()
            case .safari:
                return AdapterPlan(
                    target: .safari,
                    status: "noop",
                    messages: ["Safari inherits system appearance; no Safari chrome files or preferences are modified."]
                )
            case .spotify:
                return SpotifyAdapter(paths: paths, config: config.adapters.spotify, fileSystem: fileSystemFor(target: .spotify), backupManager: backupManager(for: .spotify), commandExecutor: commandExecutor).preview()
            case .system:
                return SystemAdapter(paths: paths, config: config.adapters.system, fileSystem: fileSystemFor(target: .system), backupManager: backupManager(for: .system), commandExecutor: commandExecutor).preview(palette: nil)
            case .finder:
                return FinderAdapter(paths: paths, config: config.adapters.finder, fileSystem: fileSystemFor(target: .finder), backupManager: backupManager(for: .finder)).preview(palette: nil)
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
                summaries.append(try TerminalAdapter(paths: paths, config: config.adapters.terminal, fileSystem: fileSystemFor(target: .terminal), backupManager: backupManager(for: .terminal), commandExecutor: commandExecutor).apply(palette: palette, dryRun: dryRun))
            case .obsidian:
                summaries.append(try ObsidianAdapter(paths: paths, config: config.adapters.obsidian, fileSystem: fileSystemFor(target: .obsidian), backupManager: backupManager(for: .obsidian)).apply(palette: palette, dryRun: dryRun))
            case .chrome:
                summaries.append(try ChromeAdapter(paths: paths, fileSystem: fileSystemFor(target: .chrome), backupManager: backupManager(for: .chrome)).apply(palette: palette, dryRun: dryRun))
            case .firefox, .librewolf, .zen, .floorp, .alacritty, .kitty, .wezterm, .ghostty, .iterm2, .vscode, .zed, .vim, .neovim, .tmux, .starship, .bat, .btop, .yazi, .fzf, .lazygit, .aerospace, .yabai, .sketchybar, .jankyBorders, .hammerspoon, .raycast, .alfred, .discord, .thunderbird, .telegram, .slack:
                summaries.append(try GeneratedAppAdapter(target: target, paths: paths, fileSystem: fileSystemFor(target: target), backupManager: backupManager(for: target), commandExecutor: commandExecutor).apply(palette: palette, dryRun: dryRun))
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
            GeneratedAppAdapter.writeRoots(for: target, paths: paths)
        case .terminal:
            [paths.appSupport, paths.cache]
        case .obsidian:
            [paths.appSupport] + config.adapters.obsidian.vaults.map(URL.init(fileURLWithPath:))
        case .spotify:
            [paths.appSupport, paths.home.appendingPathComponent(".config/spicetify", isDirectory: true)]
        case .safari:
            [paths.appSupport]
        case .system:
            [paths.appSupport, paths.cache]
        case .finder:
            [paths.appSupport] + config.adapters.finder.folders.map(URL.init(fileURLWithPath:))
        }
    }
}
