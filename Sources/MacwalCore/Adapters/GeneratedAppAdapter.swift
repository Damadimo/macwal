import Foundation

public struct GeneratedAppAdapter {
    public let target: MacwalTarget
    public let paths: MacwalPaths
    public let fileSystem: FileSystem
    public let backupManager: BackupManager
    public let commandExecutor: CommandExecutor
    /// Background opacity for generated terminal themes (0.0…1.0).
    public let terminalOpacity: Double

    private struct BrowserProfile {
        let root: URL
    }

    public init(
        target: MacwalTarget,
        paths: MacwalPaths,
        fileSystem: FileSystem = FileSystem(),
        backupManager: BackupManager? = nil,
        commandExecutor: CommandExecutor = CommandExecutor(),
        terminalOpacity: Double = 0.85
    ) {
        self.target = target
        self.paths = paths
        self.fileSystem = fileSystem
        self.backupManager = backupManager ?? BackupManager(paths: paths, fileSystem: fileSystem, commandExecutor: commandExecutor)
        self.commandExecutor = commandExecutor
        self.terminalOpacity = terminalOpacity
    }

    /// Opacity clamped to the valid [0, 1] range.
    var clampedTerminalOpacity: Double { min(max(terminalOpacity, 0), 1) }

    /// Clamped opacity formatted for config files, e.g. "0.85" or "1".
    func opacityString() -> String { String(format: "%g", clampedTerminalOpacity) }

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
            return try applyZed(palette: palette, dryRun: dryRun)
        case .vim:
            return try applyVim(palette: palette, dryRun: dryRun)
        case .neovim:
            return try applyNeovim(palette: palette, dryRun: dryRun)
        case .tmux:
            return try applyTmux(palette: palette, dryRun: dryRun)
        case .starship:
            return try applyStarship(palette: palette, dryRun: dryRun)
        case .bat:
            return try applyBat(palette: palette, dryRun: dryRun)
        case .btop:
            return try applyBtop(palette: palette, dryRun: dryRun)
        case .yazi:
            return try applyYazi(palette: palette, dryRun: dryRun)
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
        case .raycast:
            return try applyRaycast(palette: palette, dryRun: dryRun)
        case .alfred, .telegram, .slack:
            return try writeGeneratedFiles(files: genericManualFiles(palette), dryRun: dryRun, messages: ["Generated palette assets for \(displayName). Automatic activation is not exposed through stable user dotfiles."])
        case .discord:
            return try applyDiscord(palette: palette, dryRun: dryRun)
        default:
            throw MacwalError.adapterFailed("Generated app adapter does not support target '\(target.rawValue)'.")
        }
    }

    /// Precise per-target write sandbox. Every target lists exactly the
    /// directories (and, for dotfiles that live directly under `$HOME`, exact
    /// files) it writes to. This deliberately no longer includes `paths.home`
    /// itself — a root of the whole home directory defeated the sandbox. Browser
    /// profiles discovered at absolute paths are added at apply time via
    /// `FileSystem.allowingAdditional`.
    public static func writeRoots(for target: MacwalTarget, paths: MacwalPaths, environment: [String: String] = [:]) -> [URL] {
        func home(_ path: String, isDirectory: Bool = true) -> URL {
            paths.home.appendingPathComponent(path, isDirectory: isDirectory)
        }
        var roots: [URL] = [paths.appSupport]

        switch target {
        case .firefox:
            roots.append(home("Library/Application Support/Firefox"))
        case .librewolf:
            roots.append(home("Library/Application Support/LibreWolf"))
        case .zen:
            roots.append(home("Library/Application Support/Zen"))
            roots.append(home("Library/Application Support/zen"))
        case .floorp:
            roots.append(home("Library/Application Support/Floorp"))
        case .thunderbird:
            roots.append(home("Library/Thunderbird"))
        case .alacritty:
            roots.append(home(".config/alacritty"))
        case .kitty:
            roots.append(home(".config/kitty"))
        case .wezterm:
            roots.append(home(".config/wezterm"))
        case .ghostty:
            roots.append(home(".config/ghostty"))
        case .iterm2:
            roots.append(home("Library/Application Support/iTerm2"))
        case .vscode:
            roots.append(home(".vscode"))
            roots.append(home("Library/Application Support/Code/User"))
        case .zed:
            roots.append(home(".config/zed"))
        case .vim:
            roots.append(home(".vim"))
            roots.append(home(".vimrc", isDirectory: false))
        case .neovim:
            roots.append(home(".config/nvim"))
        case .tmux:
            roots.append(home(".config/tmux"))
            roots.append(home(".tmux.conf", isDirectory: false))
        case .starship:
            roots.append(home(".config/starship.toml", isDirectory: false))
        case .bat:
            roots.append(home(".config/bat"))
        case .btop:
            roots.append(home(".config/btop"))
        case .yazi:
            roots.append(home(".config/yazi"))
        case .fzf:
            roots.append(home(".config/macwal"))
            roots.append(home(".zshrc", isDirectory: false))
            roots.append(home(".bashrc", isDirectory: false))
        case .lazygit:
            roots.append(home(".config/lazygit"))
            roots.append(home("Library/Application Support/lazygit"))
            if let xdg = environment["XDG_CONFIG_HOME"], !xdg.isEmpty {
                roots.append(MacwalPaths.resolve(xdg, home: paths.home).appendingPathComponent("lazygit", isDirectory: true))
            }
        case .aerospace:
            roots.append(home(".config/aerospace"))
        case .hammerspoon:
            roots.append(home(".hammerspoon"))
        case .discord:
            roots.append(home(".config/Vencord"))
            roots.append(home("Library/Application Support/BetterDiscord"))
        case .yabai, .sketchybar, .jankyBorders, .raycast, .alfred, .telegram, .slack:
            // These only write generated assets under macwal's app support.
            break
        default:
            break
        }
        return roots
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
            return vscodeFiles(nil).map(\.url) + [vscodeSettingsURL]
        case .zed:
            return zedFiles(nil).map(\.url) + [zedSettingsURL]
        case .vim:
            return [vimThemeURL, vimrcURL]
        case .neovim:
            return [neovimThemeURL, neovimInitURL]
        case .tmux:
            return [tmuxThemeURL, tmuxConfigURL]
        case .starship:
            return [starshipConfigURL]
        case .bat:
            return [batThemeURL, batConfigURL]
        case .btop:
            return [btopThemeURL, btopConfigURL]
        case .yazi:
            return [yaziFlavorURL, yaziThemeURL]
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
        case .raycast:
            return genericManualFiles(nil).map(\.url) + [paths.generated.appendingPathComponent("raycast/macwal.raycasttheme")]
        case .alfred, .telegram, .slack:
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

        // Profiles can live at absolute paths declared in profiles.ini
        // (IsRelative=0). Widen the sandbox to those discovered roots so writing
        // to a non-standard profile location is not refused.
        let fs = fileSystem.allowingAdditional(profiles.map(\.root))

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
            try fs.atomicWriteString(try renderFirefoxCSS(palette), to: cssURL)
            // `@import` must precede all other rules, so prepend these blocks.
            try fs.atomicWriteString(upsertManagedBlock(
                in: userChromeURL,
                body: "@import url(\"macwal.css\");",
                commentPrefix: "/*",
                commentSuffix: "*/",
                prepend: true
            ), to: userChromeURL)
            try fs.atomicWriteString(upsertManagedBlock(
                in: userContentURL,
                body: "@import url(\"macwal.css\");",
                commentPrefix: "/*",
                commentSuffix: "*/",
                prepend: true
            ), to: userContentURL)
            try fs.atomicWriteString(upsertManagedBlock(
                in: userJSURL,
                body: "user_pref(\"toolkit.legacyUserProfileCustomizations.stylesheets\", true);",
                commentPrefix: "//",
                commentSuffix: ""
            ), to: userJSURL)
        }

        var messages = ["\(displayName) profile CSS written and enabled."]
        messages.append(restartMessageForCurrentTarget())
        return AdapterApplySummary(
            target: target,
            changedPaths: changed.map(\.path),
            messages: messages
        )
    }

    /// Auto-restart map for targets whose theme is only read at launch. Returns a
    /// status line (restarted / not running / skipped / manual) for the current
    /// target, or nil for targets that reload live.
    private func restartMessageForCurrentTarget() -> String {
        let restarter = AppRestarter(commandExecutor: commandExecutor)
        switch target {
        case .firefox:
            return restarter.restart(appName: "Firefox", processName: "firefox")
        case .librewolf:
            return restarter.restart(appName: "LibreWolf", processName: "librewolf")
        case .zen:
            return restarter.restart(appName: "Zen", processName: "zen")
        case .floorp:
            return restarter.restart(appName: "Floorp", processName: "floorp")
        case .thunderbird:
            return restarter.restart(appName: "Thunderbird", processName: "thunderbird")
        default:
            return "Restart \(displayName) to load the new theme."
        }
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

    /// Insert (or refresh) a delimited macwal block in `url`. When `prepend` is
    /// true the block is written *before* any existing content — required for CSS
    /// `@import` rules, which browsers ignore unless they precede every other
    /// rule.
    private func upsertManagedBlock(in url: URL, body: String, commentPrefix: String, commentSuffix: String, prepend: Bool = false) -> String {
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let begin = "\(commentPrefix) BEGIN macwal\(commentSuffix)"
        let end = "\(commentPrefix) END macwal\(commentSuffix)"
        let block = "\(begin)\n\(body)\n\(end)"
        let stripped = removeManagedBlock(from: existing, begin: begin, end: end)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if stripped.isEmpty {
            return block + "\n"
        }
        return prepend ? block + "\n\n" + stripped + "\n" : stripped + "\n\n" + block + "\n"
    }

    /// Remove every macwal-delimited block, not just the first. Re-applying used
    /// to leave earlier blocks behind whenever more than one had accumulated.
    private func removeManagedBlock(from content: String, begin: String, end: String) -> String {
        var result = content
        while let beginRange = result.range(of: begin),
              let endRange = result.range(of: end, range: beginRange.upperBound..<result.endIndex) {
            result.removeSubrange(beginRange.lowerBound..<endRange.upperBound)
        }
        return result
    }

    /// Set a top-level `"key": "value"` string entry in a JSON-with-comments
    /// file (VS Code / Zed settings), preserving the user's comments and
    /// formatting. `JSONSerialization` cannot parse JSONC, so a strict parse used
    /// to silently drop the update and the theme was written but never selected.
    /// Returns the new file contents, or nil if the existing file is unreadable.
    private func upsertJSONCStringValue(in url: URL, key: String, value: String) -> String? {
        let entry = "\"\(key)\": \"\(value)\""
        guard fileSystem.fileExists(url) else {
            return "{\n  \(entry)\n}\n"
        }
        guard let existing = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        let trimmed = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "{}" {
            return "{\n  \(entry)\n}\n"
        }

        // Replace an existing value in place (string value, or a small object
        // value such as Zed's {mode,light,dark}).
        let escapedKey = NSRegularExpression.escapedPattern(for: key)
        let pattern = "\"\(escapedKey)\"\\s*:\\s*(?:\"[^\"]*\"|\\{[^{}]*\\})"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(existing.startIndex..<existing.endIndex, in: existing)
            if regex.firstMatch(in: existing, range: range) != nil {
                let template = NSRegularExpression.escapedTemplate(for: entry)
                return regex.stringByReplacingMatches(in: existing, range: range, withTemplate: template)
            }
        }

        // No existing key: insert right after the first `{`. A trailing comma is
        // tolerated by the JSONC parsers VS Code and Zed use.
        guard let braceIndex = existing.firstIndex(of: "{") else {
            return nil
        }
        let insertOffset = existing.distance(from: existing.startIndex, to: existing.index(after: braceIndex))
        var result = existing
        let insertIndex = result.index(result.startIndex, offsetBy: insertOffset)
        result.insert(contentsOf: "\n  \(entry),", at: insertIndex)
        return result
    }

    private func applyAlacritty(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        var files = [GeneratedFile(url: alacrittyThemeURL, content: try renderAlacritty(palette))]
        files.append(GeneratedFile(url: alacrittyConfigURL, content: alacrittyConfigWithImport()))
        // Alacritty reloads its config on save (live_config_reload defaults on),
        // so no restart is required.
        return try writeGeneratedFiles(files: files, dryRun: dryRun, messages: ["Alacritty theme written and imported from alacritty.toml (reloads live)."])
    }

    private func alacrittyConfigWithImport() -> String {
        let importPath = "~/.config/alacritty/macwal.toml"
        let existing = (try? String(contentsOf: alacrittyConfigURL, encoding: .utf8)) ?? ""
        if existing.contains("macwal.toml") {
            return existing
        }
        // If the user already declares an `import = [ ... ]` array, splice our
        // path into it. A second top-level `import` key is a TOML duplicate-key
        // error that breaks the whole config.
        if let merged = insertIntoTOMLArray(existing, key: "import", element: "\"\(importPath)\"") {
            return merged
        }
        let importLine = "import = [\"\(importPath)\"]"
        if existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return importLine + "\n"
        }
        return importLine + "\n\n" + existing
    }

    /// Splice `element` into the first top-level `key = [ ... ]` TOML array in
    /// `content`, returning nil when no such array assignment exists. Handles
    /// arrays that span multiple lines and tolerates the resulting trailing
    /// comma (valid TOML).
    private func insertIntoTOMLArray(_ content: String, key: String, element: String) -> String? {
        // Find a line that assigns the top-level `key`.
        var lineStart = content.startIndex
        var assignmentStart: String.Index?
        while lineStart < content.endIndex {
            let lineEnd = content[lineStart...].firstIndex(of: "\n") ?? content.endIndex
            let trimmed = content[lineStart..<lineEnd].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(key) {
                let rest = trimmed.dropFirst(key.count).trimmingCharacters(in: .whitespaces)
                if rest.hasPrefix("=") {
                    assignmentStart = lineStart
                    break
                }
            }
            if lineEnd == content.endIndex { break }
            lineStart = content.index(after: lineEnd)
        }
        guard let assignStart = assignmentStart,
              let openBracket = content[assignStart...].firstIndex(of: "[") else {
            return nil
        }
        let insertOffset = content.distance(from: content.startIndex, to: content.index(after: openBracket))
        var result = content
        let insertIndex = result.index(result.startIndex, offsetBy: insertOffset)
        result.insert(contentsOf: "\(element), ", at: insertIndex)
        return result
    }

    private func applyKitty(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        let include = upsertManagedBlock(in: kittyConfigURL, body: "include macwal.conf", commentPrefix: "#", commentSuffix: "")
        let files = [
            GeneratedFile(url: kittyThemeURL, content: try renderKitty(palette)),
            GeneratedFile(url: kittyConfigURL, content: include)
        ]
        var summary = try writeGeneratedFiles(files: files, dryRun: dryRun, messages: ["Kitty theme written and included from kitty.conf."])
        if !dryRun {
            var applied = false
            if commandExecutor.executablePath("kitty") != nil {
                let result = try? commandExecutor.run(executable: "kitty", arguments: ["@", "set-colors", "--all", "--configured", kittyThemeURL.path])
                if result?.exitCode == 0 {
                    summary = AdapterApplySummary(target: target, changedPaths: summary.changedPaths, messages: summary.messages + ["Ran kitty @ set-colors."])
                    applied = true
                }
            }
            // Remote control may be disabled; SIGUSR1 makes kitty re-read its
            // config (which now includes macwal.conf) with no remote control.
            if !applied {
                let reload = AppRestarter(commandExecutor: commandExecutor).signal("USR1", processName: "kitty", appName: "kitty")
                summary = AdapterApplySummary(target: target, changedPaths: summary.changedPaths, messages: summary.messages + [reload])
            }
        }
        return summary
    }

    private func applyWezTerm(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        // A color scheme cannot carry window_background_opacity (that is a
        // top-level setting), so translucency only lands when we generate the
        // config. Existing wezterm.lua files are never rewritten.
        let configExists = fileSystem.fileExists(weztermConfigURL)
        var files = [GeneratedFile(url: weztermThemeURL, content: try renderWezTerm(palette))]
        if !configExists {
            files.append(GeneratedFile(url: weztermConfigURL, content: weztermDefaultConfig()))
        }
        let message = configExists
            ? "WezTerm color scheme written. Existing wezterm.lua is left intact; require macwal.lua and add `window_background_opacity = \(opacityString())` for the theme and translucency."
            : "WezTerm color scheme and config written (translucent at opacity \(opacityString()))."
        return try writeGeneratedFiles(files: files, dryRun: dryRun, messages: [message])
    }

    private func applyGhostty(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        let config = upsertManagedBlock(in: ghosttyConfigURL, body: "theme = macwal\nbackground-opacity = \(opacityString())", commentPrefix: "#", commentSuffix: "")
        var summary = try writeGeneratedFiles(
            files: [
                GeneratedFile(url: ghosttyThemeURL, content: try renderGhostty(palette)),
                GeneratedFile(url: ghosttyConfigURL, content: config)
            ],
            dryRun: dryRun,
            messages: ["Ghostty theme written and selected from config."]
        )
        if !dryRun {
            // Ghostty only reads the theme at launch; restart it (unless it is
            // hosting this command — TERM_PROGRAM=ghostty).
            let restart = AppRestarter(commandExecutor: commandExecutor).restart(
                appName: "Ghostty",
                processName: "ghostty",
                selfTermProgram: "ghostty"
            )
            summary = AdapterApplySummary(target: target, changedPaths: summary.changedPaths, messages: summary.messages + [restart])
        }
        return summary
    }

    private func applyITerm2(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        var summary = try writeGeneratedFiles(files: [GeneratedFile(url: itermDynamicProfileURL, content: try renderITerm2(palette))], dryRun: dryRun, messages: ["iTerm2 Dynamic Profile written (loaded automatically)."])
        if !dryRun {
            // Make macwal the default profile so new windows use it. iTerm2 reads
            // this preference at launch, so already-open windows keep their profile.
            let defaults = DefaultsClient(paths: paths, executor: commandExecutor, fileSystem: fileSystem)
            let domain = "com.googlecode.iterm2"
            let key = "Default Bookmark Guid"
            try? backupManager.backupDefaultsBeforeWrite(domain: domain, key: key, value: try? defaults.readValue(domain: domain, key: key), adapter: target, dryRun: false)
            if (try? defaults.setValue("macwal", domain: domain, key: key)) != nil {
                summary = AdapterApplySummary(target: target, changedPaths: summary.changedPaths + ["\(domain):\(key)"], messages: summary.messages + ["Set macwal as the default iTerm2 profile; open a new window (or restart iTerm2) to use it."])
            } else {
                summary = AdapterApplySummary(target: target, changedPaths: summary.changedPaths, messages: summary.messages + ["Select the macwal profile in iTerm2 for new sessions."])
            }
        }
        return summary
    }

    private func applyVSCode(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        var files = vscodeFiles(palette)
        if let settings = upsertJSONCStringValue(in: vscodeSettingsURL, key: "workbench.colorTheme", value: "macwal") {
            files.append(GeneratedFile(url: vscodeSettingsURL, content: settings))
        }
        // VS Code hot-applies workbench.colorTheme on save; no restart needed.
        return try writeGeneratedFiles(files: files, dryRun: dryRun, messages: ["VS Code theme extension written and selected via settings.json (workbench.colorTheme)."])
    }

    private func applyZed(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        var files = zedFiles(palette)
        if let settings = upsertJSONCStringValue(in: zedSettingsURL, key: "theme", value: "macwal") {
            files.append(GeneratedFile(url: zedSettingsURL, content: settings))
        }
        // Zed watches settings.json and hot-reloads the theme; no restart needed.
        return try writeGeneratedFiles(files: files, dryRun: dryRun, messages: ["Zed theme written and selected via settings.json (reloads live)."])
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

    private func applyStarship(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        // Starship re-reads its config for every prompt, so this activates live
        // in new prompts once written.
        let content = try starshipConfigWith(palette)
        return try writeGeneratedFiles(
            files: [GeneratedFile(url: starshipConfigURL, content: content)],
            dryRun: dryRun,
            messages: ["Starship palette written to starship.toml and activated (palette = \"macwal\")."]
        )
    }

    private func starshipConfigWith(_ palette: PaletteDocument) throws -> String {
        var existing = (try? String(contentsOf: starshipConfigURL, encoding: .utf8)) ?? ""
        // The top-level `palette` selector must precede any table header, so
        // upsert it above the first `[section]`.
        existing = upsertTopLevelTOMLKey(existing, key: "palette", value: "\"macwal\"")

        let begin = "# BEGIN macwal"
        let end = "# END macwal"
        let table = """
        \(begin)
        [palettes.macwal]
        black = "\(try color(palette, "black"))"
        red = "\(try color(palette, "red"))"
        green = "\(try color(palette, "green"))"
        yellow = "\(try color(palette, "yellow"))"
        blue = "\(try color(palette, "blue"))"
        purple = "\(try color(palette, "magenta"))"
        cyan = "\(try color(palette, "cyan"))"
        white = "\(try color(palette, "white"))"
        \(end)
        """
        let stripped = removeManagedBlock(from: existing, begin: begin, end: end)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? table + "\n" : stripped + "\n\n" + table + "\n"
    }

    /// Set a bare top-level `key = value` in `content`, replacing an existing
    /// top-level assignment or inserting one before the first table header (bare
    /// keys after a `[table]` header belong to that table, not the document root).
    private func upsertTopLevelTOMLKey(_ content: String, key: String, value: String) -> String {
        var out: [String] = []
        var replaced = false
        var sawTable = false
        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !sawTable && trimmed.hasPrefix("[") {
                sawTable = true
            }
            if !sawTable && !replaced && (trimmed.hasPrefix("\(key) ") || trimmed.hasPrefix("\(key)=")) {
                out.append("\(key) = \(value)")
                replaced = true
            } else {
                out.append(line)
            }
        }
        if replaced {
            return out.joined(separator: "\n")
        }
        if let tableIndex = out.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("[") }) {
            out.insert("\(key) = \(value)", at: tableIndex)
        } else {
            out.insert("\(key) = \(value)", at: 0)
        }
        return out.joined(separator: "\n")
    }

    private var starshipConfigURL: URL { paths.home.appendingPathComponent(".config/starship.toml") }

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

    private func applyYazi(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        // Write the theme as a self-contained flavor and reference it from
        // theme.toml, rather than overwriting the user's whole theme.toml.
        var files = [GeneratedFile(url: yaziFlavorURL, content: try renderYaziFlavor(palette))]
        var messages = ["Yazi flavor written to flavors/macwal.flavor/."]

        let existingTheme = (try? String(contentsOf: yaziThemeURL, encoding: .utf8)) ?? ""
        let strippedTheme = existingTheme.trimmingCharacters(in: .whitespacesAndNewlines)
        // TOML forbids duplicate `[flavor]` tables. If the user already has their
        // own, leave theme.toml untouched and tell them how to point it at us.
        if strippedTheme.contains("[flavor]") && !strippedTheme.contains("# BEGIN macwal") {
            messages.append("theme.toml already has a [flavor] table; set dark = \"macwal\" / light = \"macwal\" there to activate it.")
        } else {
            files.append(GeneratedFile(url: yaziThemeURL, content: yaziThemeReferencingFlavor(existing: existingTheme)))
            messages.append("Selected the macwal flavor in theme.toml. Restart yazi to load it.")
        }

        return try writeGeneratedFiles(files: files, dryRun: dryRun, messages: messages)
    }

    private func yaziThemeReferencingFlavor(existing: String) -> String {
        let begin = "# BEGIN macwal"
        let end = "# END macwal"
        let block = "\(begin)\n[flavor]\ndark = \"macwal\"\nlight = \"macwal\"\n\(end)"
        let stripped = removeManagedBlock(from: existing, begin: begin, end: end)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // The [flavor] table must own the end of the file so it does not swallow
        // the user's other tables; append it last.
        return stripped.isEmpty ? block + "\n" : stripped + "\n\n" + block + "\n"
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
        // A failing live command must not abort the whole run (which, under
        // `set`, would skip every remaining app). Collect a warning and keep going.
        var ran = 0
        for commandArguments in arguments {
            let result = try? commandExecutor.run(executable: executable, arguments: commandArguments)
            if let result, result.exitCode == 0 {
                ran += 1
            } else {
                let detail = result.map { $0.stderrText.trimmingCharacters(in: .whitespacesAndNewlines) } ?? "could not launch"
                messages.append("\(executable) \(commandArguments.joined(separator: " ")) did not succeed\(detail.isEmpty ? "" : ": \(detail)"); generated files are available.")
            }
        }
        messages.append("Ran \(ran) of \(arguments.count) \(executable) command(s).")
        return AdapterApplySummary(target: target, changedPaths: summary.changedPaths, messages: messages)
    }

    private func applyHammerspoon(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        // Hammerspoon has no global theme concept — colors only matter where your
        // own Lua uses them. Expose the palette as `hs.macwalColors` (instead of
        // dofile'ing and discarding it) so config can reference it, and be honest
        // that nothing changes visually until it does.
        let initBody = "hs.macwalColors = dofile(os.getenv(\"HOME\") .. \"/.hammerspoon/macwal.lua\")"
        var summary = try writeGeneratedFiles(files: [
            GeneratedFile(url: hammerspoonThemeURL, content: try renderHammerspoon(palette)),
            GeneratedFile(url: hammerspoonInitURL, content: upsertManagedBlock(in: hammerspoonInitURL, body: initBody, commentPrefix: "--", commentSuffix: ""))
        ], dryRun: dryRun, messages: ["Hammerspoon palette written and exposed as hs.macwalColors. Reference it in your config to apply colors — Hammerspoon has no global theme API."])
        if !dryRun, commandExecutor.executablePath("hs") != nil {
            let result = try? commandExecutor.run(executable: "hs", arguments: ["-c", "hs.reload()"])
            if result?.exitCode == 0 {
                summary = AdapterApplySummary(target: target, changedPaths: summary.changedPaths, messages: summary.messages + ["Reloaded Hammerspoon."])
            }
        }
        return summary
    }

    private func applyRaycast(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        let themeURL = paths.generated.appendingPathComponent("raycast/macwal.raycasttheme")
        var files = genericManualFiles(palette)
        files.append(GeneratedFile(url: themeURL, content: try renderRaycastTheme(palette)))
        let summary = try writeGeneratedFiles(files: files, dryRun: dryRun, messages: ["Raycast theme written to \(themeURL.lastPathComponent)."])
        guard !dryRun else {
            return summary
        }

        // Best effort: opening a .raycasttheme file hands it to Raycast's import
        // flow. Gated on MACWAL_SKIP_RESTART so tests/smoke never poke a real
        // Raycast, and only attempted when Raycast is actually running.
        let restarter = AppRestarter(commandExecutor: commandExecutor)
        let skip = commandExecutor.environment["MACWAL_SKIP_RESTART"] != nil
        if !skip, restarter.isRunning(processName: "Raycast") {
            let opened = try? commandExecutor.run(executable: "/usr/bin/open", arguments: [themeURL.path])
            let message = opened?.exitCode == 0
                ? "Opened the theme in Raycast — confirm the import, then choose it under Raycast Settings → Appearance."
                : "Import \(themeURL.lastPathComponent) via Raycast Settings → Appearance → Add theme."
            return AdapterApplySummary(target: target, changedPaths: summary.changedPaths, messages: summary.messages + [message])
        }
        return AdapterApplySummary(
            target: target,
            changedPaths: summary.changedPaths,
            messages: summary.messages + ["Import \(themeURL.lastPathComponent) via Raycast Settings → Appearance → Add theme."]
        )
    }

    func renderRaycastTheme(_ palette: PaletteDocument) throws -> String {
        let theme: [String: Any] = [
            "author": "macwal",
            "name": "macwal",
            "version": "1",
            "appearance": palette.appearance.recommendedMode == "light" ? "light" : "dark",
            "colors": [
                "background": try color(palette, "background"),
                "backgroundSecondary": try color(palette, "black"),
                "text": try color(palette, "foreground"),
                "selection": try color(palette, "selection"),
                "loader": try color(palette, "accent"),
                "red": try color(palette, "red"),
                "orange": try color(palette, "brightYellow"),
                "yellow": try color(palette, "yellow"),
                "green": try color(palette, "green"),
                "blue": try color(palette, "blue"),
                "purple": try color(palette, "magenta"),
                "magenta": try color(palette, "brightMagenta")
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: theme, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self) + "\n"
    }

    private func applyDiscord(palette: PaletteDocument, dryRun: Bool) throws -> AdapterApplySummary {
        // Vencord is the dominant Discord client mod and its theme folder is a
        // plain directory of CSS, so always write + enable it (creating the
        // folder if needed). This is the "just make it work" path — the file is
        // harmless if the user has not installed Vencord yet, and active the
        // moment they do.
        let css = discordCSS(palette)
        var files: [GeneratedFile] = [
            GeneratedFile(url: vencordThemesDirectory.appendingPathComponent("macwal.css"), content: css),
            GeneratedFile(url: vencordSettingsURL, content: vencordSettingsEnablingTheme())
        ]
        var messages = ["Vencord theme written and enabled (enabledThemes). If Discord is running, reload it (Cmd+R) to load it."]

        // Only touch BetterDiscord when the user actually runs it — don't
        // fabricate a competing client's folder.
        if fileSystem.isDirectory(betterDiscordThemesDirectory) {
            files.append(GeneratedFile(url: betterDiscordThemesDirectory.appendingPathComponent("macwal.theme.css"), content: css))
            messages.append("BetterDiscord theme written; toggle 'macwal' on under BetterDiscord → Themes.")
        }

        return try writeGeneratedFiles(files: files, dryRun: dryRun, messages: messages)
    }

    /// Enable macwal.css in Vencord's settings.json (strict JSON) so it activates
    /// without the user toggling it. Merges into an existing settings file, or
    /// creates a minimal one when none exists.
    private func vencordSettingsEnablingTheme() -> String {
        var object: [String: Any] = [:]
        if fileSystem.fileExists(vencordSettingsURL),
           let data = try? Data(contentsOf: vencordSettingsURL),
           let existing = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            object = existing
        }
        var enabled = (object["enabledThemes"] as? [String]) ?? []
        if !enabled.contains("macwal.css") {
            enabled.append("macwal.css")
        }
        object["enabledThemes"] = enabled
        guard let out = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else {
            return "{\n  \"enabledThemes\" : [\n    \"macwal.css\"\n  ]\n}\n"
        }
        return String(decoding: out, as: UTF8.self) + "\n"
    }

    private var vencordThemesDirectory: URL { paths.home.appendingPathComponent(".config/Vencord/themes", isDirectory: true) }
    private var vencordSettingsURL: URL { paths.home.appendingPathComponent(".config/Vencord/settings/settings.json") }
    private var betterDiscordThemesDirectory: URL { paths.home.appendingPathComponent("Library/Application Support/BetterDiscord/themes", isDirectory: true) }

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
    private var zedSettingsURL: URL { paths.home.appendingPathComponent(".config/zed/settings.json") }
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
    private var lazygitConfigURL: URL {
        // lazygit reads $XDG_CONFIG_HOME/lazygit/config.yml when XDG_CONFIG_HOME
        // is set, and otherwise ~/Library/Application Support/lazygit on macOS.
        // Many users set XDG_CONFIG_HOME or keep a ~/.config/lazygit, so honor
        // both before falling back to the macOS default.
        if let xdg = commandExecutor.environment["XDG_CONFIG_HOME"], !xdg.isEmpty {
            return MacwalPaths.resolve(xdg, home: paths.home).appendingPathComponent("lazygit/config.yml")
        }
        let xdgDefault = paths.home.appendingPathComponent(".config/lazygit/config.yml")
        if fileSystem.fileExists(xdgDefault) {
            return xdgDefault
        }
        return paths.home.appendingPathComponent("Library/Application Support/lazygit/config.yml")
    }
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

        /*
         * New tab / home / blank page. These are content documents, so the
         * rules only take effect through userContent.css (macwal.css is imported
         * into both userChrome.css and userContent.css); they are inert in the
         * chrome sheet.
         */
        @-moz-document url("about:home"), url("about:newtab"), url("about:blank") {
          :root {
            --newtab-background-color: \(try color(palette, "background")) !important;
            --newtab-background-color-secondary: \(try color(palette, "black")) !important;
            --newtab-text-primary-color: \(try color(palette, "foreground")) !important;
            --in-content-page-background: \(try color(palette, "background")) !important;
            --in-content-page-color: \(try color(palette, "foreground")) !important;
          }
          body,
          .outer-wrapper,
          .activity-stream,
          main {
            background-color: \(try color(palette, "background")) !important;
            color: \(try color(palette, "foreground")) !important;
          }
        }

        """
    }

    func renderAlacritty(_ palette: PaletteDocument) throws -> String {
        """
        # Generated by macwal. Do not edit by hand.

        [window]
        opacity = \(opacityString())

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
            "selection_foreground \(try color(palette, "foreground"))",
            "background_opacity \(opacityString())"
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
          window_background_opacity = \(opacityString()),
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
            // iTerm2 expresses translucency as transparency (0 = opaque),
            // the inverse of the opacity the other terminals use.
            "Transparency": 1.0 - clampedTerminalOpacity,
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

    // Yazi renamed the `[manager]` table to `[mgr]`; the old key is ignored by
    // current releases. This renders a flavor's flavor.toml with the modern
    // schema.
    private func renderYaziFlavor(_ palette: PaletteDocument) throws -> String {
        """
        # Generated by macwal. Do not edit by hand.
        [mgr]
        cwd = { fg = "\(try color(palette, "accent"))" }
        hovered = { fg = "\(try color(palette, "foreground"))", bg = "\(try color(palette, "selection"))" }
        preview_hovered = { fg = "\(try color(palette, "foreground"))", bg = "\(try color(palette, "brightBlack"))" }
        find_keyword = { fg = "\(try color(palette, "yellow"))", bold = true }
        marker_copied = { fg = "\(try color(palette, "green"))", bg = "\(try color(palette, "green"))" }
        marker_cut = { fg = "\(try color(palette, "red"))", bg = "\(try color(palette, "red"))" }
        marker_selected = { fg = "\(try color(palette, "accent"))", bg = "\(try color(palette, "accent"))" }

        [status]
        separator_open = ""
        separator_close = ""
        mode_normal = { fg = "\(try color(palette, "background"))", bg = "\(try color(palette, "accent"))", bold = true }
        mode_select = { fg = "\(try color(palette, "background"))", bg = "\(try color(palette, "green"))", bold = true }
        mode_unset = { fg = "\(try color(palette, "background"))", bg = "\(try color(palette, "magenta"))", bold = true }

        """
    }

    private var yaziFlavorURL: URL { paths.home.appendingPathComponent(".config/yazi/flavors/macwal.flavor/flavor.toml") }
    private var yaziThemeURL: URL { paths.home.appendingPathComponent(".config/yazi/theme.toml") }

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
        sketchybar --default label.color=0xff\(noHash(palette, "foreground")) icon.color=0xff\(noHash(palette, "foreground"))

        """)]
    }

    func sketchybarCommands(_ palette: PaletteDocument) -> [[String]] {
        // `--set /` targets a nonexistent item and errors; `--default` applies to
        // the bar's items without needing to know their names.
        [
            ["--bar", "color=0xff\(noHash(Optional(palette), "background"))"],
            ["--default", "label.color=0xff\(noHash(Optional(palette), "foreground"))", "icon.color=0xff\(noHash(Optional(palette), "foreground"))"]
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

    func discordCSS(_ palette: PaletteDocument?) -> String {
        """
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
    }

    // Candidate destinations for preview/plannedWrites; apply() only writes to
    // the ones whose client is actually installed.
    private func discordFiles(_ palette: PaletteDocument?) -> [GeneratedFile] {
        let css = discordCSS(palette)
        return [
            GeneratedFile(url: paths.home.appendingPathComponent(".config/Vencord/themes/macwal.css"), content: css),
            GeneratedFile(url: paths.home.appendingPathComponent("Library/Application Support/BetterDiscord/themes/macwal.theme.css"), content: css)
        ]
    }
}
