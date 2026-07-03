import Foundation

public struct GeneratedAppAdapter {
    public let target: MacwalTarget
    public let paths: MacwalPaths
    public let fileSystem: FileSystem
    public let backupManager: BackupManager
    public let commandExecutor: CommandExecutor

    private struct BrowserProfile {
        let root: URL
    }

    public init(
        target: MacwalTarget,
        paths: MacwalPaths,
        fileSystem: FileSystem = FileSystem(),
        backupManager: BackupManager? = nil,
        commandExecutor: CommandExecutor = CommandExecutor()
    ) {
        self.target = target
        self.paths = paths
        self.fileSystem = fileSystem
        self.backupManager = backupManager ?? BackupManager(paths: paths, fileSystem: fileSystem, commandExecutor: commandExecutor)
        self.commandExecutor = commandExecutor
    }

    public func preview() -> AdapterPlan {
        if isBrowserProfileTarget {
            let profiles = browserProfiles()
            return AdapterPlan(
                target: target,
                status: profiles.isEmpty ? "unavailable" : "ready",
                plannedWrites: profiles.flatMap(plannedBrowserWrites(profile:)).map(\.path),
                messages: profiles.isEmpty
                    ? ["No \(target.rawValue) profiles were found."]
                    : ["Writes profile CSS/user.js files. Restart \(displayName) to load changes."]
            )
        }

        return AdapterPlan(
            target: target,
            status: previewStatus,
            plannedWrites: plannedWrites().map(\.path),
            messages: previewMessages
        )
    }

    public func apply(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        if isBrowserProfileTarget {
            return try applyBrowserProfiles(palette: palette, dryRun: dryRun)
        }

        switch target {
        case .alacritty:
            return try applyAlacritty(palette: palette, dryRun: dryRun)
        case .kitty:
            return try applyKitty(palette: palette, dryRun: dryRun)
        case .wezterm:
            return try applyWezTerm(palette: palette, dryRun: dryRun)
        case .ghostty:
            return try applyGhostty(palette: palette, dryRun: dryRun)
        case .iterm2:
            return try applyITerm2(palette: palette, dryRun: dryRun)
        case .vscode:
            return try applyVSCode(palette: palette, dryRun: dryRun)
        case .zed:
            return try writeGeneratedFiles(files: zedFiles(palette), dryRun: dryRun, messages: ["Zed theme file written."])
        case .vim:
            return try applyVim(palette: palette, dryRun: dryRun)
        case .neovim:
            return try applyNeovim(palette: palette, dryRun: dryRun)
        case .tmux:
            return try applyTmux(palette: palette, dryRun: dryRun)
        case .starship:
            return try writeGeneratedFiles(files: starshipFiles(palette), dryRun: dryRun, messages: ["Starship palette fragment written. Add or merge it into starship.toml if you already have a config."])
        case .bat:
            return try applyBat(palette: palette, dryRun: dryRun)
        case .btop:
            return try applyBtop(palette: palette, dryRun: dryRun)
        case .yazi:
            return try writeGeneratedFiles(files: yaziFiles(palette), dryRun: dryRun, messages: ["Yazi theme.toml written."])
        case .fzf:
            return try applyFzf(palette: palette, dryRun: dryRun)
        case .lazygit:
            return try applyLazygit(palette: palette, dryRun: dryRun)
        case .aerospace:
            return try writeGeneratedFiles(files: aerospaceFiles(palette), dryRun: dryRun, messages: ["AeroSpace color fragment written for manual import. AeroSpace does not currently expose broad runtime color theming."])
        case .yabai:
            return try applyCommandTarget(palette: palette, dryRun: dryRun, executable: "yabai", arguments: yabaiCommands(palette), generatedFiles: yabaiFiles(palette))
        case .sketchybar:
            return try applyCommandTarget(palette: palette, dryRun: dryRun, executable: "sketchybar", arguments: sketchybarCommands(palette), generatedFiles: sketchybarFiles(palette))
        case .jankyBorders:
            return try applyCommandTarget(palette: palette, dryRun: dryRun, executable: "borders", arguments: jankyBordersCommands(palette), generatedFiles: jankyBordersFiles(palette))
        case .hammerspoon:
            return try applyHammerspoon(palette: palette, dryRun: dryRun)
        case .raycast, .alfred, .telegram, .slack:
            return try writeGeneratedFiles(files: genericManualFiles(palette), dryRun: dryRun, messages: ["Generated palette assets for \(displayName). Automatic activation is not exposed through stable user dotfiles."])
        case .discord:
            return try applyDiscord(palette: palette, dryRun: dryRun)
        default:
            throw MacwalError.adapterFailed("Generated app adapter does not support target '\(target.rawValue)'.")
        }
    }

    public static func writeRoots(for target: MacwalTarget, paths: MacwalPaths) -> [URL] {
        switch target {
        case .firefox:
            return [paths.appSupport, paths.home.appendingPathComponent("Library/Application Support/Firefox", isDirectory: true)]
        case .librewolf:
            return [paths.appSupport, paths.home.appendingPathComponent("Library/Application Support/LibreWolf", isDirectory: true)]
        case .zen:
            return [
                paths.appSupport,
                paths.home.appendingPathComponent("Library/Application Support/Zen", isDirectory: true),
                paths.home.appendingPathComponent("Library/Application Support/zen", isDirectory: true)
            ]
        case .floorp:
            return [paths.appSupport, paths.home.appendingPathComponent("Library/Application Support/Floorp", isDirectory: true)]
        case .thunderbird:
            return [paths.appSupport, paths.home.appendingPathComponent("Library/Thunderbird", isDirectory: true)]
        case .iterm2, .vscode:
            return [paths.appSupport, paths.home.appendingPathComponent("Library/Application Support", isDirectory: true), paths.home.appendingPathComponent(".vscode", isDirectory: true)]
        default:
            return [paths.appSupport, paths.home.appendingPathComponent(".config", isDirectory: true), paths.home]
        }
    }

    private var isBrowserProfileTarget: Bool {
        switch target {
        case .firefox, .librewolf, .zen, .floorp, .thunderbird:
            true
        default:
            false
        }
    }

    private var displayName: String {
        switch target {
        case .librewolf:
            "LibreWolf"
        case .zen:
            "Zen Browser"
        case .jankyBorders:
            "Janky Borders"
        case .iterm2:
            "iTerm2"
        case .vscode:
            "VS Code"
        default:
            target.rawValue
        }
    }

    private var previewStatus: String {
        switch target {
        case .yabai, .sketchybar, .jankyBorders:
            return commandExecutor.executablePath(target.requiresExternalTool ?? target.rawValue) == nil ? "unavailable" : "ready"
        default:
            return "ready"
        }
    }

    private var previewMessages: [String] {
        switch target {
        case .raycast, .alfred, .telegram, .slack:
            return ["Generates palette assets only; automatic activation is not exposed through stable user dotfiles."]
        case .chrome:
            return ["Chrome is handled by ChromeAdapter."]
        default:
            return ["Writes generated \(displayName) theme configuration."]
        }
    }

    private func plannedWrites() -> [URL] {
        switch target {
        case .alacritty:
            return [alacrittyThemeURL, alacrittyConfigURL]
        case .kitty:
            return [kittyThemeURL, kittyConfigURL]
        case .wezterm:
            return [weztermThemeURL, weztermConfigURL]
        case .ghostty:
            return [ghosttyThemeURL, ghosttyConfigURL]
        case .iterm2:
            return [itermDynamicProfileURL]
        case .vscode:
            return vscodeFiles(nil).map(\.url)
        case .zed:
            return zedFiles(nil).map(\.url)
        case .vim:
            return [vimThemeURL, vimrcURL]
        case .neovim:
            return [neovimThemeURL, neovimInitURL]
        case .tmux:
            return [tmuxThemeURL, tmuxConfigURL]
        case .starship:
            return starshipFiles(nil).map(\.url)
        case .bat:
            return [batThemeURL, batConfigURL]
        case .btop:
            return [btopThemeURL, btopConfigURL]
        case .yazi:
            return yaziFiles(nil).map(\.url)
        case .fzf:
            return [fzfScriptURL, zshrcURL, bashrcURL]
        case .lazygit:
            return [lazygitConfigURL]
        case .aerospace:
            return aerospaceFiles(nil).map(\.url)
        case .yabai:
            return yabaiFiles(nil).map(\.url)
        case .sketchybar:
            return sketchybarFiles(nil).map(\.url)
        case .jankyBorders:
            return jankyBordersFiles(nil).map(\.url)
        case .hammerspoon:
            return [hammerspoonThemeURL, hammerspoonInitURL]
        case .raycast, .alfred, .telegram, .slack:
            return genericManualFiles(nil).map(\.url)
        case .discord:
            return discordFiles(nil).map(\.url)
        default:
            return []
        }
    }

    private func plannedBrowserWrites(profile: BrowserProfile) -> [URL] {
        let chrome = profile.root.appendingPathComponent("chrome", isDirectory: true)
        return [
            chrome.appendingPathComponent("macwal.css"),
            chrome.appendingPathComponent("userChrome.css"),
            chrome.appendingPathComponent("userContent.css"),
            profile.root.appendingPathComponent("user.js")
        ]
    }

    private func applyBrowserProfiles(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        let profiles = browserProfiles()
        guard !profiles.isEmpty else {
            throw MacwalError.missingPrerequisite("No \(target.rawValue) profiles were found.")
        }

        let changed = profiles.flatMap(plannedBrowserWrites(profile:))
        if dryRun {
            return AdapterApplySummary(target: target, changedPaths: changed.map(\.path), messages: ["Dry run: no \(displayName) profile files were written."])
        }

        for profile in profiles {
            let chrome = profile.root.appendingPathComponent("chrome", isDirectory: true)
            let cssURL = chrome.appendingPathComponent("macwal.css")
            let userChromeURL = chrome.appendingPathComponent("userChrome.css")
            let userContentURL = chrome.appendingPathComponent("userContent.css")
            let userJSURL = profile.root.appendingPathComponent("user.js")

            try backupManager.backupFileBeforeWrite(cssURL, adapter: target, dryRun: false)
            try backupManager.backupFileBeforeWrite(userChromeURL, adapter: target, dryRun: false)
            try backupManager.backupFileBeforeWrite(userContentURL, adapter: target, dryRun: false)
            try backupManager.backupFileBeforeWrite(userJSURL, adapter: target, dryRun: false)
            try fileSystem.atomicWriteString(try renderFirefoxCSS(palette), to: cssURL)
            try fileSystem.atomicWriteString(upsertManagedBlock(
                in: userChromeURL,
                body: "@import url(\"macwal.css\");",
                commentPrefix: "/*",
                commentSuffix: "*/"
            ), to: userChromeURL)
            try fileSystem.atomicWriteString(upsertManagedBlock(
                in: userContentURL,
                body: "@import url(\"macwal.css\");",
                commentPrefix: "/*",
                commentSuffix: "*/"
            ), to: userContentURL)
            try fileSystem.atomicWriteString(upsertManagedBlock(
                in: userJSURL,
                body: "user_pref(\"toolkit.legacyUserProfileCustomizations.stylesheets\", true);",
                commentPrefix: "//",
                commentSuffix: ""
            ), to: userJSURL)
        }

        return AdapterApplySummary(
            target: target,
            changedPaths: changed.map(\.path),
            messages: ["\(displayName) profile CSS written. Restart \(displayName) to load userChrome/userContent changes."]
        )
    }

    private func browserProfiles() -> [BrowserProfile] {
        var profiles: [BrowserProfile] = []
        for root in browserRoots() {
            let ini = root.appendingPathComponent("profiles.ini")
            if fileSystem.fileExists(ini), let parsed = parseProfilesINI(root: root, ini: ini), !parsed.isEmpty {
                profiles.append(contentsOf: parsed)
                continue
            }

            let profilesDirectory = root.appendingPathComponent("Profiles", isDirectory: true)
            if let children = try? FileManager.default.contentsOfDirectory(at: profilesDirectory, includingPropertiesForKeys: nil) {
                profiles.append(contentsOf: children.filter { $0.hasDirectoryPath }.map(BrowserProfile.init(root:)))
            }
        }
        return profiles
    }

    private func browserRoots() -> [URL] {
        switch target {
        case .firefox:
            [paths.home.appendingPathComponent("Library/Application Support/Firefox", isDirectory: true)]
        case .librewolf:
            [paths.home.appendingPathComponent("Library/Application Support/LibreWolf", isDirectory: true)]
        case .zen:
            [
                paths.home.appendingPathComponent("Library/Application Support/Zen", isDirectory: true),
                paths.home.appendingPathComponent("Library/Application Support/zen", isDirectory: true)
            ]
        case .floorp:
            [paths.home.appendingPathComponent("Library/Application Support/Floorp", isDirectory: true)]
        case .thunderbird:
            [paths.home.appendingPathComponent("Library/Thunderbird", isDirectory: true)]
        default:
            []
        }
    }

    private func parseProfilesINI(root: URL, ini: URL) -> [BrowserProfile]? {
        guard let content = try? String(contentsOf: ini, encoding: .utf8) else {
            return nil
        }

        var profiles: [BrowserProfile] = []
        var current: [String: String] = [:]
        func flush() {
            guard let rawPath = current["Path"] else {
                current = [:]
                return
            }
            let isRelative = current["IsRelative"] == "1"
            let url = isRelative ? root.appendingPathComponent(rawPath) : URL(fileURLWithPath: rawPath)
            profiles.append(BrowserProfile(root: url))
            current = [:]
        }

        for rawLine in content.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("[") {
                flush()
                continue
            }
            guard let separator = line.firstIndex(of: "=") else {
                continue
            }
            let key = String(line[..<separator])
            let value = String(line[line.index(after: separator)...])
            current[key] = value
        }
        flush()
        return profiles
    }

    private struct GeneratedFile {
        let url: URL
        let content: String
    }

    private func writeGeneratedFiles(files: [GeneratedFile], dryRun: Bool, messages: [String]) throws -> AdapterApplySummary {
        if dryRun {
            return AdapterApplySummary(target: target, changedPaths: files.map(\.url.path), messages: ["Dry run: no \(displayName) files were written."] + messages)
        }

        for file in files {
            try write(file.content, to: file.url)
        }
        return AdapterApplySummary(target: target, changedPaths: files.map(\.url.path), messages: messages)
    }

    private func write(_ content: String, to url: URL) throws {
        try backupManager.backupFileBeforeWrite(url, adapter: target, dryRun: false)
        try fileSystem.atomicWriteString(content, to: url)
    }

    private func upsertManagedBlock(in url: URL, body: String, commentPrefix: String, commentSuffix: String) -> String {
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let begin = "\(commentPrefix) BEGIN macwal\(commentSuffix)"
        let end = "\(commentPrefix) END macwal\(commentSuffix)"
        let block = "\(begin)\n\(body)\n\(end)"
        let stripped = removeManagedBlock(from: existing, begin: begin, end: end)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? block + "\n" : stripped + "\n\n" + block + "\n"
    }

    private func removeManagedBlock(from content: String, begin: String, end: String) -> String {
        guard let beginRange = content.range(of: begin),
              let endRange = content.range(of: end, range: beginRange.upperBound..<content.endIndex) else {
            return content
        }
        var result = content
        result.removeSubrange(beginRange.lowerBound..<endRange.upperBound)
        return result
    }

    private func applyAlacritty(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        var files = [GeneratedFile(url: alacrittyThemeURL, content: try renderAlacritty(palette))]
        files.append(GeneratedFile(url: alacrittyConfigURL, content: alacrittyConfigWithImport()))
        return try writeGeneratedFiles(files: files, dryRun: dryRun, messages: ["Alacritty theme written and imported from alacritty.toml. Restart Alacritty or reload config to apply."])
    }

    private func alacrittyConfigWithImport() -> String {
        let importLine = "import = [\"~/.config/alacritty/macwal.toml\"]"
        let existing = (try? String(contentsOf: alacrittyConfigURL, encoding: .utf8)) ?? ""
        if existing.contains("macwal.toml") {
            return existing
        }
        if existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return importLine + "\n"
        }
        return importLine + "\n\n" + existing
    }

    private func applyKitty(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        let include = upsertManagedBlock(in: kittyConfigURL, body: "include macwal.conf", commentPrefix: "#", commentSuffix: "")
        let files = [
            GeneratedFile(url: kittyThemeURL, content: try renderKitty(palette)),
            GeneratedFile(url: kittyConfigURL, content: include)
        ]
        var summary = try writeGeneratedFiles(files: files, dryRun: dryRun, messages: ["Kitty theme written and included from kitty.conf."])
        if !dryRun, commandExecutor.executablePath("kitty") != nil {
            let result = try? commandExecutor.run(executable: "kitty", arguments: ["@", "set-colors", "--all", "--configured", kittyThemeURL.path])
            if result?.exitCode == 0 {
                summary = AdapterApplySummary(target: target, changedPaths: summary.changedPaths, messages: summary.messages + ["Ran kitty @ set-colors."])
            }
        }
        return summary
    }

    private func applyWezTerm(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        var files = [GeneratedFile(url: weztermThemeURL, content: try renderWezTerm(palette))]
        if !fileSystem.fileExists(weztermConfigURL) {
            files.append(GeneratedFile(url: weztermConfigURL, content: weztermDefaultConfig()))
        }
        return try writeGeneratedFiles(files: files, dryRun: dryRun, messages: ["WezTerm color scheme written. Existing wezterm.lua files are left intact; require macwal.lua from your config if needed."])
    }

    private func applyGhostty(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        let config = upsertManagedBlock(in: ghosttyConfigURL, body: "theme = macwal", commentPrefix: "#", commentSuffix: "")
        return try writeGeneratedFiles(
            files: [
                GeneratedFile(url: ghosttyThemeURL, content: try renderGhostty(palette)),
                GeneratedFile(url: ghosttyConfigURL, content: config)
            ],
            dryRun: dryRun,
            messages: ["Ghostty theme written and selected from config."]
        )
    }

    private func applyITerm2(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        return try writeGeneratedFiles(files: [GeneratedFile(url: itermDynamicProfileURL, content: try renderITerm2(palette))], dryRun: dryRun, messages: ["iTerm2 Dynamic Profile written. iTerm2 loads DynamicProfiles automatically; select the macwal profile for new sessions."])
    }

    private func applyVSCode(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        var files = vscodeFiles(palette)
        if let settings = try? vscodeSettingsWithTheme() {
            files.append(GeneratedFile(url: vscodeSettingsURL, content: settings))
        }
        return try writeGeneratedFiles(files: files, dryRun: dryRun, messages: ["VS Code theme extension written. settings.json was updated when it was valid JSON or absent."])
    }

    private func applyVim(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        let vimrc = upsertManagedBlock(in: vimrcURL, body: "colorscheme macwal", commentPrefix: "\"", commentSuffix: "")
        return try writeGeneratedFiles(files: [
            GeneratedFile(url: vimThemeURL, content: try renderVimColors(palette)),
            GeneratedFile(url: vimrcURL, content: vimrc)
        ], dryRun: dryRun, messages: ["Vim colorscheme written and enabled from .vimrc."])
    }

    private func applyNeovim(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        let initURL = neovimInitURL
        let body = initURL.pathExtension == "lua" ? "vim.cmd.colorscheme(\"macwal\")" : "colorscheme macwal"
        let prefix = initURL.pathExtension == "lua" ? "--" : "\""
        let initContent = upsertManagedBlock(in: initURL, body: body, commentPrefix: prefix, commentSuffix: "")
        return try writeGeneratedFiles(files: [
            GeneratedFile(url: neovimThemeURL, content: try renderVimColors(palette)),
            GeneratedFile(url: initURL, content: initContent)
        ], dryRun: dryRun, messages: ["Neovim colorscheme written and enabled from \(initURL.lastPathComponent)."])
    }

    private func applyTmux(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        let config = upsertManagedBlock(in: tmuxConfigURL, body: "source-file ~/.config/tmux/macwal.tmux", commentPrefix: "#", commentSuffix: "")
        var summary = try writeGeneratedFiles(files: [
            GeneratedFile(url: tmuxThemeURL, content: try renderTmux(palette)),
            GeneratedFile(url: tmuxConfigURL, content: config)
        ], dryRun: dryRun, messages: ["tmux theme written and sourced from tmux.conf."])
        if !dryRun, commandExecutor.executablePath("tmux") != nil {
            let result = try? commandExecutor.run(executable: "tmux", arguments: ["source-file", tmuxThemeURL.path])
            if result?.exitCode == 0 {
                summary = AdapterApplySummary(target: target, changedPaths: summary.changedPaths, messages: summary.messages + ["Ran tmux source-file."])
            }
        }
        return summary
    }

    private func applyBat(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        let config = upsertManagedBlock(in: batConfigURL, body: "--theme=macwal", commentPrefix: "#", commentSuffix: "")
        var summary = try writeGeneratedFiles(files: [
            GeneratedFile(url: batThemeURL, content: try renderBatTheme(palette)),
            GeneratedFile(url: batConfigURL, content: config)
        ], dryRun: dryRun, messages: ["bat theme written and selected from bat config."])
        if !dryRun, commandExecutor.executablePath("bat") != nil {
            let result = try? commandExecutor.run(executable: "bat", arguments: ["cache", "--build"])
            if result?.exitCode == 0 {
                summary = AdapterApplySummary(target: target, changedPaths: summary.changedPaths, messages: summary.messages + ["Ran bat cache --build."])
            }
        }
        return summary
    }

    private func applyBtop(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        let config = updateLineConfig(at: btopConfigURL, key: "color_theme", value: "\"macwal\"")
        return try writeGeneratedFiles(files: [
            GeneratedFile(url: btopThemeURL, content: try renderBtop(palette)),
            GeneratedFile(url: btopConfigURL, content: config)
        ], dryRun: dryRun, messages: ["btop theme written and selected from btop.conf."])
    }

    private func applyFzf(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        let script = try renderFzf(palette)
        var files = [GeneratedFile(url: fzfScriptURL, content: script)]
        files.append(GeneratedFile(url: zshrcURL, content: upsertManagedBlock(in: zshrcURL, body: "[ -f ~/.config/macwal/fzf.sh ] && . ~/.config/macwal/fzf.sh", commentPrefix: "#", commentSuffix: "")))
        if fileSystem.fileExists(bashrcURL) {
            files.append(GeneratedFile(url: bashrcURL, content: upsertManagedBlock(in: bashrcURL, body: "[ -f ~/.config/macwal/fzf.sh ] && . ~/.config/macwal/fzf.sh", commentPrefix: "#", commentSuffix: "")))
        }
        return try writeGeneratedFiles(files: files, dryRun: dryRun, messages: ["fzf color exports written and sourced from shell rc files. Open a new shell to load them."])
    }

    private func applyLazygit(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        if fileSystem.fileExists(lazygitConfigURL) {
            return try writeGeneratedFiles(files: [GeneratedFile(url: paths.generated.appendingPathComponent("lazygit/config.yml"), content: try renderLazygit(palette))], dryRun: dryRun, messages: ["Existing Lazygit config was not overwritten. Generated config under macwal app support for manual merge."])
        }
        return try writeGeneratedFiles(files: [GeneratedFile(url: lazygitConfigURL, content: try renderLazygit(palette))], dryRun: dryRun, messages: ["Lazygit theme config written."])
    }

    private func applyCommandTarget(palette: PaletteDocument, dryRun: Bool, executable: String, arguments: [[String]], generatedFiles: [GeneratedFile]) throws -> AdapterApplySummary {
        var messages = ["Generated \(displayName) command/color reference files."]
        if commandExecutor.executablePath(executable) == nil {
            return try writeGeneratedFiles(files: generatedFiles, dryRun: dryRun, messages: messages + ["\(executable) was not found on PATH."])
        }
        let summary = try writeGeneratedFiles(files: generatedFiles, dryRun: dryRun, messages: messages)
        guard !dryRun else {
            return summary
        }
        for commandArguments in arguments {
            let result = try commandExecutor.run(executable: executable, arguments: commandArguments)
            guard result.exitCode == 0 else {
                throw MacwalError.adapterFailed("\(executable) \(commandArguments.joined(separator: " ")) failed: \(result.stderrText)")
            }
        }
        messages.append("Ran \(arguments.count) \(executable) command(s).")
        return AdapterApplySummary(target: target, changedPaths: summary.changedPaths, messages: messages)
    }

    private func applyHammerspoon(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        let initBody = "dofile(os.getenv(\"HOME\") .. \"/.hammerspoon/macwal.lua\")"
        var summary = try writeGeneratedFiles(files: [
            GeneratedFile(url: hammerspoonThemeURL, content: try renderHammerspoon(palette)),
            GeneratedFile(url: hammerspoonInitURL, content: upsertManagedBlock(in: hammerspoonInitURL, body: initBody, commentPrefix: "--", commentSuffix: ""))
        ], dryRun: dryRun, messages: ["Hammerspoon colors written and loaded from init.lua."])
        if !dryRun, commandExecutor.executablePath("hs") != nil {
            let result = try? commandExecutor.run(executable: "hs", arguments: ["-c", "hs.reload()"])
            if result?.exitCode == 0 {
                summary = AdapterApplySummary(target: target, changedPaths: summary.changedPaths, messages: summary.messages + ["Reloaded Hammerspoon."])
            }
        }
        return summary
    }

    private func applyDiscord(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        let files = discordFiles(palette)
        return try writeGeneratedFiles(files: files, dryRun: dryRun, messages: ["Discord CSS theme files written for Vencord/BetterDiscord when those theme folders exist. Enable the theme in your client if it is not already enabled."])
    }

    private func updateLineConfig(at url: URL, key: String, value: String) -> String {
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        var found = false
        let lines = existing.components(separatedBy: .newlines).map { line -> String in
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("\(key) ") || line.trimmingCharacters(in: .whitespaces).hasPrefix("\(key)=") {
                found = true
                return "\(key) = \(value)"
            }
            return line
        }
        if found {
            return lines.joined(separator: "\n")
        }
        return existing.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\(key) = \(value)\n"
    }

    private var alacrittyThemeURL: URL { paths.home.appendingPathComponent(".config/alacritty/macwal.toml") }
    private var alacrittyConfigURL: URL { paths.home.appendingPathComponent(".config/alacritty/alacritty.toml") }
    private var kittyThemeURL: URL { paths.home.appendingPathComponent(".config/kitty/macwal.conf") }
    private var kittyConfigURL: URL { paths.home.appendingPathComponent(".config/kitty/kitty.conf") }
    private var weztermThemeURL: URL { paths.home.appendingPathComponent(".config/wezterm/macwal.lua") }
    private var weztermConfigURL: URL { paths.home.appendingPathComponent(".config/wezterm/wezterm.lua") }
    private var ghosttyThemeURL: URL { paths.home.appendingPathComponent(".config/ghostty/themes/macwal") }
    private var ghosttyConfigURL: URL { paths.home.appendingPathComponent(".config/ghostty/config") }
    private var itermDynamicProfileURL: URL { paths.home.appendingPathComponent("Library/Application Support/iTerm2/DynamicProfiles/macwal.json") }
    private var vscodeExtensionDirectory: URL { paths.home.appendingPathComponent(".vscode/extensions/macwal-theme") }
    private var vscodeSettingsURL: URL { paths.home.appendingPathComponent("Library/Application Support/Code/User/settings.json") }
    private var vimThemeURL: URL { paths.home.appendingPathComponent(".vim/colors/macwal.vim") }
    private var vimrcURL: URL { paths.home.appendingPathComponent(".vimrc") }
    private var neovimThemeURL: URL { paths.home.appendingPathComponent(".config/nvim/colors/macwal.vim") }
    private var neovimInitURL: URL {
        let lua = paths.home.appendingPathComponent(".config/nvim/init.lua")
        return fileSystem.fileExists(lua) ? lua : paths.home.appendingPathComponent(".config/nvim/init.vim")
    }
    private var tmuxThemeURL: URL { paths.home.appendingPathComponent(".config/tmux/macwal.tmux") }
    private var tmuxConfigURL: URL { fileSystem.fileExists(paths.home.appendingPathComponent(".tmux.conf")) ? paths.home.appendingPathComponent(".tmux.conf") : paths.home.appendingPathComponent(".config/tmux/tmux.conf") }
    private var batThemeURL: URL { paths.home.appendingPathComponent(".config/bat/themes/macwal.tmTheme") }
    private var batConfigURL: URL { paths.home.appendingPathComponent(".config/bat/config") }
    private var btopThemeURL: URL { paths.home.appendingPathComponent(".config/btop/themes/macwal.theme") }
    private var btopConfigURL: URL { paths.home.appendingPathComponent(".config/btop/btop.conf") }
    private var fzfScriptURL: URL { paths.home.appendingPathComponent(".config/macwal/fzf.sh") }
    private var zshrcURL: URL { paths.home.appendingPathComponent(".zshrc") }
    private var bashrcURL: URL { paths.home.appendingPathComponent(".bashrc") }
    private var lazygitConfigURL: URL { paths.home.appendingPathComponent("Library/Application Support/lazygit/config.yml") }
    private var hammerspoonThemeURL: URL { paths.home.appendingPathComponent(".hammerspoon/macwal.lua") }
    private var hammerspoonInitURL: URL { paths.home.appendingPathComponent(".hammerspoon/init.lua") }
}

private extension GeneratedAppAdapter {
    func color(_ palette: PaletteDocument, _ key: String) throws -> String {
        guard let value = palette.colors[key] else {
            throw MacwalError.adapterFailed("Palette is missing required color '\(key)'.")
        }
        return value
    }

    func color(_ palette: PaletteDocument?, _ key: String) -> String {
        palette?.colors[key] ?? "#000000"
    }

    func noHash(_ palette: PaletteDocument, _ key: String) throws -> String {
        try color(palette, key).replacingOccurrences(of: "#", with: "")
    }

    func noHash(_ palette: PaletteDocument?, _ key: String) -> String {
        color(palette, key).replacingOccurrences(of: "#", with: "")
    }

    var ansiKeys: [String] {
        [
            "black", "red", "green", "yellow", "blue", "magenta", "cyan", "white",
            "brightBlack", "brightRed", "brightGreen", "brightYellow", "brightBlue",
            "brightMagenta", "brightCyan", "brightWhite"
        ]
    }

    func renderFirefoxCSS(_ palette: PaletteDocument) throws -> String {
        """
        /* Generated by macwal. Do not edit by hand. */
        :root {
          --macwal-background: \(try color(palette, "background")) !important;
          --macwal-foreground: \(try color(palette, "foreground")) !important;
          --macwal-accent: \(try color(palette, "accent")) !important;
          --macwal-accent-alt: \(try color(palette, "accentAlt")) !important;
          --toolbar-bgcolor: \(try color(palette, "background")) !important;
          --toolbar-color: \(try color(palette, "foreground")) !important;
          --lwt-accent-color: \(try color(palette, "background")) !important;
          --lwt-text-color: \(try color(palette, "foreground")) !important;
          --lwt-selected-tab-background-color: \(try color(palette, "brightBlack")) !important;
          --tab-selected-bgcolor: \(try color(palette, "brightBlack")) !important;
          --urlbar-box-bgcolor: \(try color(palette, "black")) !important;
          --urlbar-box-text-color: \(try color(palette, "foreground")) !important;
          --button-bgcolor: \(try color(palette, "accent")) !important;
          --button-color: \(try color(palette, "foreground")) !important;
        }

        #navigator-toolbox,
        #TabsToolbar,
        #nav-bar,
        #PersonalToolbar,
        #titlebar {
          background-color: \(try color(palette, "background")) !important;
          color: \(try color(palette, "foreground")) !important;
          border-color: \(try color(palette, "brightBlack")) !important;
        }

        .tab-background[selected],
        #urlbar-background,
        #searchbar {
          background-color: \(try color(palette, "brightBlack")) !important;
          color: \(try color(palette, "foreground")) !important;
        }

        toolbarbutton,
        .toolbarbutton-icon,
        .toolbarbutton-text {
          color: \(try color(palette, "foreground")) !important;
          fill: \(try color(palette, "foreground")) !important;
        }

        """
    }

    func renderAlacritty(_ palette: PaletteDocument) throws -> String {
        """
        # Generated by macwal. Do not edit by hand.

        [colors.primary]
        background = "\(try color(palette, "background"))"
        foreground = "\(try color(palette, "foreground"))"

        [colors.cursor]
        text = "\(try color(palette, "background"))"
        cursor = "\(try color(palette, "cursor"))"

        [colors.selection]
        text = "\(try color(palette, "foreground"))"
        background = "\(try color(palette, "selection"))"

        [colors.normal]
        black = "\(try color(palette, "black"))"
        red = "\(try color(palette, "red"))"
        green = "\(try color(palette, "green"))"
        yellow = "\(try color(palette, "yellow"))"
        blue = "\(try color(palette, "blue"))"
        magenta = "\(try color(palette, "magenta"))"
        cyan = "\(try color(palette, "cyan"))"
        white = "\(try color(palette, "white"))"

        [colors.bright]
        black = "\(try color(palette, "brightBlack"))"
        red = "\(try color(palette, "brightRed"))"
        green = "\(try color(palette, "brightGreen"))"
        yellow = "\(try color(palette, "brightYellow"))"
        blue = "\(try color(palette, "brightBlue"))"
        magenta = "\(try color(palette, "brightMagenta"))"
        cyan = "\(try color(palette, "brightCyan"))"
        white = "\(try color(palette, "brightWhite"))"

        """
    }

    func renderKitty(_ palette: PaletteDocument) throws -> String {
        var lines = [
            "# Generated by macwal. Do not edit by hand.",
            "background \(try color(palette, "background"))",
            "foreground \(try color(palette, "foreground"))",
            "cursor \(try color(palette, "cursor"))",
            "selection_background \(try color(palette, "selection"))",
            "selection_foreground \(try color(palette, "foreground"))"
        ]
        for (index, key) in ansiKeys.enumerated() {
            lines.append("color\(index) \(try color(palette, key))")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    func renderWezTerm(_ palette: PaletteDocument) throws -> String {
        var lines = [
            "-- Generated by macwal. Do not edit by hand.",
            "return {",
            "  foreground = '\(try color(palette, "foreground"))',",
            "  background = '\(try color(palette, "background"))',",
            "  cursor_bg = '\(try color(palette, "cursor"))',",
            "  cursor_fg = '\(try color(palette, "background"))',",
            "  selection_bg = '\(try color(palette, "selection"))',",
            "  selection_fg = '\(try color(palette, "foreground"))',",
            "  ansi = {"
        ]
        lines.append("    " + ansiKeys.prefix(8).map { "'\(palette.colors[$0] ?? "#000000")'" }.joined(separator: ", ") + ",")
        lines.append("  },")
        lines.append("  brights = {")
        lines.append("    " + ansiKeys.dropFirst(8).map { "'\(palette.colors[$0] ?? "#000000")'" }.joined(separator: ", ") + ",")
        lines.append("  },")
        lines.append("}")
        return lines.joined(separator: "\n") + "\n"
    }

    func weztermDefaultConfig() -> String {
        """
        -- Generated by macwal because no wezterm.lua existed.
        local wezterm = require 'wezterm'
        return {
          color_schemes = {
            macwal = require 'macwal',
          },
          color_scheme = 'macwal',
        }

        """
    }

    func renderGhostty(_ palette: PaletteDocument) throws -> String {
        var lines = [
            "# Generated by macwal. Do not edit by hand.",
            "background = \(try color(palette, "background"))",
            "foreground = \(try color(palette, "foreground"))",
            "cursor-color = \(try color(palette, "cursor"))",
            "selection-background = \(try color(palette, "selection"))",
            "selection-foreground = \(try color(palette, "foreground"))"
        ]
        for (index, key) in ansiKeys.enumerated() {
            lines.append("palette = \(index)=\(try color(palette, key))")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    func renderITerm2(_ palette: PaletteDocument) throws -> String {
        func component(_ hex: String) throws -> [String: Double] {
            let rgb = try RGBColor(hex: hex)
            return [
                "Red Component": Double(rgb.red) / 255.0,
                "Green Component": Double(rgb.green) / 255.0,
                "Blue Component": Double(rgb.blue) / 255.0,
                "Alpha Component": 1.0
            ]
        }

        var profile: [String: Any] = [
            "Name": "macwal",
            "Guid": "macwal",
            "Dynamic Profile Parent Name": "Default",
            "Normal Font": "Menlo-Regular 12",
            "Background Color": try component(try color(palette, "background")),
            "Foreground Color": try component(try color(palette, "foreground")),
            "Cursor Color": try component(try color(palette, "cursor")),
            "Selection Color": try component(try color(palette, "selection")),
            "Selected Text Color": try component(try color(palette, "foreground"))
        ]
        for (index, key) in ansiKeys.enumerated() {
            profile["Ansi \(index) Color"] = try component(try color(palette, key))
        }

        let data = try JSONSerialization.data(withJSONObject: ["Profiles": [profile]], options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self) + "\n"
    }

    private func vscodeFiles(_ palette: PaletteDocument?) -> [GeneratedFile] {
        [
            GeneratedFile(url: vscodeExtensionDirectory.appendingPathComponent("package.json"), content: vscodePackageJSON()),
            GeneratedFile(url: vscodeExtensionDirectory.appendingPathComponent("themes/macwal-color-theme.json"), content: renderVSCodeTheme(palette))
        ]
    }

    func vscodePackageJSON() -> String {
        """
        {
          "name": "macwal-theme",
          "displayName": "macwal",
          "version": "0.1.0",
          "publisher": "macwal",
          "engines": {
            "vscode": "^1.80.0"
          },
          "contributes": {
            "themes": [
              {
                "label": "macwal",
                "uiTheme": "vs-dark",
                "path": "./themes/macwal-color-theme.json"
              }
            ]
          }
        }

        """
    }

    func renderVSCodeTheme(_ palette: PaletteDocument?) -> String {
        let object: [String: Any] = [
            "name": "macwal",
            "type": "dark",
            "colors": [
                "editor.background": color(palette, "background"),
                "editor.foreground": color(palette, "foreground"),
                "editor.selectionBackground": color(palette, "selection"),
                "activityBar.background": color(palette, "black"),
                "sideBar.background": color(palette, "background"),
                "statusBar.background": color(palette, "black"),
                "statusBar.foreground": color(palette, "foreground"),
                "tab.activeBackground": color(palette, "brightBlack"),
                "tab.activeForeground": color(palette, "foreground"),
                "focusBorder": color(palette, "accent")
            ],
            "tokenColors": [
                ["scope": "comment", "settings": ["foreground": color(palette, "white")]],
                ["scope": "string", "settings": ["foreground": color(palette, "green")]],
                ["scope": "keyword", "settings": ["foreground": color(palette, "magenta")]],
                ["scope": "constant.numeric", "settings": ["foreground": color(palette, "yellow")]],
                ["scope": "entity.name.function", "settings": ["foreground": color(palette, "blue")]]
            ]
        ]
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])) ?? Data("{}".utf8)
        return String(decoding: data, as: UTF8.self) + "\n"
    }

    func vscodeSettingsWithTheme() throws -> String {
        var settings: [String: Any] = [:]
        if fileSystem.fileExists(vscodeSettingsURL) {
            let data = try Data(contentsOf: vscodeSettingsURL)
            settings = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        }
        settings["workbench.colorTheme"] = "macwal"
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self) + "\n"
    }

    private func zedFiles(_ palette: PaletteDocument?) -> [GeneratedFile] {
        let content: [String: Any] = [
            "$schema": "https://zed.dev/schema/themes/v0.2.0.json",
            "name": "macwal",
            "author": "macwal",
            "themes": [[
                "name": "macwal",
                "appearance": "dark",
                "style": [
                    "background": color(palette, "background"),
                    "text": color(palette, "foreground"),
                    "editor.background": color(palette, "background"),
                    "editor.foreground": color(palette, "foreground"),
                    "accent": color(palette, "accent")
                ]
            ]]
        ]
        let data = (try? JSONSerialization.data(withJSONObject: content, options: [.prettyPrinted, .sortedKeys])) ?? Data("{}".utf8)
        return [GeneratedFile(url: paths.home.appendingPathComponent(".config/zed/themes/macwal.json"), content: String(decoding: data, as: UTF8.self) + "\n")]
    }

    func renderVimColors(_ palette: PaletteDocument) throws -> String {
        """
        " Generated by macwal. Do not edit by hand.
        set background=\(palette.appearance.recommendedMode == "light" ? "light" : "dark")
        highlight clear
        if exists("syntax_on")
          syntax reset
        endif
        let g:colors_name = "macwal"
        highlight Normal guifg=\(try color(palette, "foreground")) guibg=\(try color(palette, "background")) ctermfg=15 ctermbg=0
        highlight Comment guifg=\(try color(palette, "white")) gui=italic
        highlight Constant guifg=\(try color(palette, "yellow"))
        highlight String guifg=\(try color(palette, "green"))
        highlight Identifier guifg=\(try color(palette, "blue"))
        highlight Statement guifg=\(try color(palette, "magenta"))
        highlight PreProc guifg=\(try color(palette, "cyan"))
        highlight Type guifg=\(try color(palette, "brightYellow"))
        highlight Special guifg=\(try color(palette, "accent"))
        highlight Visual guifg=\(try color(palette, "foreground")) guibg=\(try color(palette, "selection"))
        highlight Cursor guifg=\(try color(palette, "background")) guibg=\(try color(palette, "cursor"))
        highlight LineNr guifg=\(try color(palette, "white")) guibg=\(try color(palette, "background"))

        """
    }

    func renderTmux(_ palette: PaletteDocument) throws -> String {
        """
        # Generated by macwal. Do not edit by hand.
        set -g status-style "fg=\(try color(palette, "foreground")),bg=\(try color(palette, "background"))"
        set -g window-status-current-style "fg=\(try color(palette, "background")),bg=\(try color(palette, "accent"))"
        set -g pane-border-style "fg=\(try color(palette, "brightBlack"))"
        set -g pane-active-border-style "fg=\(try color(palette, "accent"))"
        set -g message-style "fg=\(try color(palette, "foreground")),bg=\(try color(palette, "selection"))"

        """
    }

    private func starshipFiles(_ palette: PaletteDocument?) -> [GeneratedFile] {
        [GeneratedFile(url: paths.home.appendingPathComponent(".config/starship-macwal.toml"), content: """
        # Generated by macwal. Merge into starship.toml to activate.
        palette = "macwal"

        [palettes.macwal]
        black = "\(color(palette, "black"))"
        red = "\(color(palette, "red"))"
        green = "\(color(palette, "green"))"
        yellow = "\(color(palette, "yellow"))"
        blue = "\(color(palette, "blue"))"
        purple = "\(color(palette, "magenta"))"
        cyan = "\(color(palette, "cyan"))"
        white = "\(color(palette, "white"))"

        """)]
    }

    func renderBatTheme(_ palette: PaletteDocument) throws -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0">
        <dict>
          <key>name</key><string>macwal</string>
          <key>settings</key>
          <array>
            <dict>
              <key>settings</key>
              <dict>
                <key>background</key><string>\(try color(palette, "background"))</string>
                <key>foreground</key><string>\(try color(palette, "foreground"))</string>
                <key>caret</key><string>\(try color(palette, "cursor"))</string>
                <key>selection</key><string>\(try color(palette, "selection"))</string>
              </dict>
            </dict>
          </array>
        </dict>
        </plist>

        """
    }

    func renderBtop(_ palette: PaletteDocument) throws -> String {
        """
        # Generated by macwal. Do not edit by hand.
        theme[main_bg]="\(try color(palette, "background"))"
        theme[main_fg]="\(try color(palette, "foreground"))"
        theme[title]="\(try color(palette, "accent"))"
        theme[hi_fg]="\(try color(palette, "brightWhite"))"
        theme[selected_bg]="\(try color(palette, "selection"))"
        theme[selected_fg]="\(try color(palette, "foreground"))"
        theme[inactive_fg]="\(try color(palette, "white"))"
        theme[graph_text]="\(try color(palette, "foreground"))"
        theme[meter_bg]="\(try color(palette, "brightBlack"))"
        theme[proc_misc]="\(try color(palette, "cyan"))"
        theme[cpu_box]="\(try color(palette, "blue"))"
        theme[mem_box]="\(try color(palette, "magenta"))"
        theme[net_box]="\(try color(palette, "green"))"
        theme[proc_box]="\(try color(palette, "yellow"))"

        """
    }

    private func yaziFiles(_ palette: PaletteDocument?) -> [GeneratedFile] {
        [GeneratedFile(url: paths.home.appendingPathComponent(".config/yazi/theme.toml"), content: """
        # Generated by macwal. Do not edit by hand.
        [manager]
        cwd = { fg = "\(color(palette, "accent"))" }
        hovered = { fg = "\(color(palette, "foreground"))", bg = "\(color(palette, "selection"))" }
        preview_hovered = { fg = "\(color(palette, "foreground"))", bg = "\(color(palette, "brightBlack"))" }

        [status]
        separator_open = ""
        separator_close = ""
        mode_normal = { fg = "\(color(palette, "background"))", bg = "\(color(palette, "accent"))", bold = true }

        """)]
    }

    func renderFzf(_ palette: PaletteDocument) throws -> String {
        """
        # Generated by macwal. Do not edit by hand.
        export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --color=fg:\(try color(palette, "foreground")),bg:\(try color(palette, "background")),hl:\(try color(palette, "accent")),fg+:\(try color(palette, "foreground")),bg+:\(try color(palette, "selection")),hl+:\(try color(palette, "brightCyan")),info:\(try color(palette, "yellow")),prompt:\(try color(palette, "accent")),pointer:\(try color(palette, "magenta")),marker:\(try color(palette, "green")),spinner:\(try color(palette, "cyan")),header:\(try color(palette, "white"))"

        """
    }

    func renderLazygit(_ palette: PaletteDocument) throws -> String {
        """
        gui:
          theme:
            activeBorderColor:
              - "\(try color(palette, "accent"))"
              - bold
            inactiveBorderColor:
              - "\(try color(palette, "brightBlack"))"
            selectedLineBgColor:
              - "\(try color(palette, "selection"))"
            optionsTextColor:
              - "\(try color(palette, "blue"))"

        """
    }

    private func aerospaceFiles(_ palette: PaletteDocument?) -> [GeneratedFile] {
        [GeneratedFile(url: paths.home.appendingPathComponent(".config/aerospace/macwal.toml"), content: """
        # Generated by macwal. AeroSpace has limited visual theme surface.
        # Import or copy these values into scripts that drive borders/status bars.
        [macwal]
        background = "\(color(palette, "background"))"
        foreground = "\(color(palette, "foreground"))"
        accent = "\(color(palette, "accent"))"
        selection = "\(color(palette, "selection"))"

        """)]
    }

    private func yabaiFiles(_ palette: PaletteDocument?) -> [GeneratedFile] {
        [GeneratedFile(url: paths.generated.appendingPathComponent("yabai/macwal.sh"), content: """
        #!/bin/sh
        yabai -m config active_window_border_color 0xff\(noHash(palette, "accent"))
        yabai -m config normal_window_border_color 0xff\(noHash(palette, "brightBlack"))

        """)]
    }

    func yabaiCommands(_ palette: PaletteDocument) -> [[String]] {
        [
            ["-m", "config", "active_window_border_color", "0xff\(noHash(Optional(palette), "accent"))"],
            ["-m", "config", "normal_window_border_color", "0xff\(noHash(Optional(palette), "brightBlack"))"]
        ]
    }

    private func sketchybarFiles(_ palette: PaletteDocument?) -> [GeneratedFile] {
        [GeneratedFile(url: paths.generated.appendingPathComponent("sketchybar/macwal.sh"), content: """
        #!/bin/sh
        sketchybar --bar color=0xff\(noHash(palette, "background"))
        sketchybar --set / label.color=0xff\(noHash(palette, "foreground")) icon.color=0xff\(noHash(palette, "foreground"))

        """)]
    }

    func sketchybarCommands(_ palette: PaletteDocument) -> [[String]] {
        [
            ["--bar", "color=0xff\(noHash(Optional(palette), "background"))"],
            ["--set", "/", "label.color=0xff\(noHash(Optional(palette), "foreground"))", "icon.color=0xff\(noHash(Optional(palette), "foreground"))"]
        ]
    }

    private func jankyBordersFiles(_ palette: PaletteDocument?) -> [GeneratedFile] {
        [GeneratedFile(url: paths.generated.appendingPathComponent("janky-borders/macwal.sh"), content: """
        #!/bin/sh
        borders active_color=0xff\(noHash(palette, "accent")) inactive_color=0xff\(noHash(palette, "brightBlack"))

        """)]
    }

    func jankyBordersCommands(_ palette: PaletteDocument) -> [[String]] {
        [["active_color=0xff\(noHash(Optional(palette), "accent"))", "inactive_color=0xff\(noHash(Optional(palette), "brightBlack"))"]]
    }

    func renderHammerspoon(_ palette: PaletteDocument) throws -> String {
        var lines = ["-- Generated by macwal. Do not edit by hand.", "return {"]
        for key in palette.colors.keys.sorted() {
            lines.append("  \(key) = '\(palette.colors[key] ?? "#000000")',")
        }
        lines.append("}")
        return lines.joined(separator: "\n") + "\n"
    }

    private func genericManualFiles(_ palette: PaletteDocument?) -> [GeneratedFile] {
        let colors = palette?.colors ?? [:]
        let data = (try? JSONSerialization.data(withJSONObject: colors, options: [.prettyPrinted, .sortedKeys])) ?? Data("{}".utf8)
        return [
            GeneratedFile(url: paths.generated.appendingPathComponent("\(target.rawValue)/colors.json"), content: String(decoding: data, as: UTF8.self) + "\n"),
            GeneratedFile(url: paths.generated.appendingPathComponent("\(target.rawValue)/colors.css"), content: genericCSS(palette))
        ]
    }

    func genericCSS(_ palette: PaletteDocument?) -> String {
        var lines = ["/* Generated by macwal. Do not edit by hand. */", ":root {"]
        let keys = palette?.colors.keys.sorted() ?? []
        for key in keys {
            lines.append("  --macwal-\(key): \(palette?.colors[key] ?? "#000000");")
        }
        lines.append("}")
        return lines.joined(separator: "\n") + "\n"
    }

    private func discordFiles(_ palette: PaletteDocument?) -> [GeneratedFile] {
        let css = """
        /**
         * @name macwal
         * @description Generated by macwal.
         */
        \(genericCSS(palette))
        .theme-dark,
        .theme-light {
          --background-primary: \(color(palette, "background"));
          --background-secondary: \(color(palette, "black"));
          --text-normal: \(color(palette, "foreground"));
          --interactive-active: \(color(palette, "foreground"));
          --brand-experiment: \(color(palette, "accent"));
        }

        """
        return [
            GeneratedFile(url: paths.home.appendingPathComponent(".config/Vencord/themes/macwal.css"), content: css),
            GeneratedFile(url: paths.home.appendingPathComponent("Library/Application Support/BetterDiscord/themes/macwal.theme.css"), content: css)
        ]
    }
}
