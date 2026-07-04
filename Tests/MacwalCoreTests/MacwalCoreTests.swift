import class AppKit.NSColor
import class AppKit.NSColorSpace
import CoreGraphics
import Darwin
import Foundation
import ImageIO
import MacwalCore
import Testing
import UniformTypeIdentifiers

struct MacwalCoreTests {
    @Test func targetListContainsAllPlannedTargets() throws {
        let names = MacwalTarget.allCases.map(\.rawValue)
        #expect(names == expectedTargetNames)
    }

    @Test func unknownTargetFails() throws {
        do {
            _ = try MacwalTarget.parseList("shell,nope", allowPrivate: false)
            #expect(Bool(false), "Expected unknown target to throw.")
        } catch let error as MacwalError {
            #expect(error == .invalidArguments("Unknown target 'nope'. Run 'macwal list-targets' for valid targets."))
        }
    }

    @Test func paletteGeneratorProducesContrastValidatedPalette() throws {
        let temp = try TemporaryWorkspace()
        let image = try temp.writePNG(named: "wallpaper.png", colors: [
            RGBColor(red: 12, green: 30, blue: 44),
            RGBColor(red: 120, green: 165, blue: 180),
            RGBColor(red: 210, green: 125, blue: 78)
        ])

        let palette = try PaletteGenerator(dateProvider: { Date(timeIntervalSince1970: 0) }).generate(
            from: image,
            source: PaletteSource(kind: "image", path: image.path)
        )

        #expect(palette.appearance.contrastValidated)
        #expect(palette.generatedAt == "1970-01-01T00:00:00Z")
        #expect(palette.colors["background"] != nil)
        #expect(palette.colors["foreground"] != nil)
        #expect(ansiKeys.filter { palette.colors[$0] != nil }.count == ansiKeys.count)
    }

    @Test func filesystemGuardAllowsOnlyDeclaredRoots() throws {
        let temp = try TemporaryWorkspace()
        let allowed = temp.root.appendingPathComponent("allowed", isDirectory: true)
        let denied = temp.root.appendingPathComponent("denied", isDirectory: true)
        let fileSystem = FileSystem(allowedWriteRoots: [allowed])

        try fileSystem.atomicWriteString("ok", to: allowed.appendingPathComponent("file.txt"))
        #expect(FileManager.default.fileExists(atPath: allowed.appendingPathComponent("file.txt").path))

        do {
            try fileSystem.atomicWriteString("no", to: denied.appendingPathComponent("file.txt"))
            #expect(Bool(false), "Expected write outside declared roots to fail.")
        } catch let error as MacwalError {
            guard case .permissionDenied = error else {
                #expect(Bool(false), "Expected permissionDenied, got \(error).")
                return
            }
        }
    }

    @Test func paletteJSONMatchesSnapshot() throws {
        #expect(try snapshotPalette().encodedJSON() + "\n" == snapshot(named: "palette.json"))
    }

    @Test func plannedPaletteFixturesMatchSnapshots() throws {
        let fixtures: [PaletteFixture] = [
            PaletteFixture(name: "dark-low-saturation", colors: [
                RGBColor(red: 18, green: 22, blue: 28),
                RGBColor(red: 42, green: 48, blue: 54),
                RGBColor(red: 64, green: 70, blue: 76)
            ]),
            PaletteFixture(name: "bright-low-saturation", colors: [
                RGBColor(red: 220, green: 224, blue: 226),
                RGBColor(red: 186, green: 194, blue: 198),
                RGBColor(red: 244, green: 240, blue: 232)
            ]),
            PaletteFixture(name: "high-saturation", colors: [
                RGBColor(red: 250, green: 50, blue: 40),
                RGBColor(red: 40, green: 210, blue: 110),
                RGBColor(red: 50, green: 120, blue: 250)
            ]),
            PaletteFixture(name: "mostly-red", colors: [
                RGBColor(red: 160, green: 28, blue: 36),
                RGBColor(red: 230, green: 76, blue: 68),
                RGBColor(red: 92, green: 22, blue: 28)
            ]),
            PaletteFixture(name: "mostly-blue-green", colors: [
                RGBColor(red: 8, green: 86, blue: 110),
                RGBColor(red: 24, green: 152, blue: 134),
                RGBColor(red: 74, green: 196, blue: 166)
            ])
        ]

        let generator = PaletteGenerator(dateProvider: { Date(timeIntervalSince1970: 0) })
        for fixture in fixtures {
            let temp = try TemporaryWorkspace()
            let image = try temp.writePNG(named: "\(fixture.name).png", colors: fixture.colors)
            let palette = try generator.generate(
                from: image,
                source: PaletteSource(kind: "image", path: "/fixtures/\(fixture.name).png")
            )
            #expect(try palette.encodedJSON() + "\n" == snapshot(named: "palette-\(fixture.name).json"))
        }
    }

    @Test func shellAndChromeArtifactsMatchSnapshots() throws {
        let temp = try TemporaryWorkspace()
        let paths = MacwalPaths(environment: temp.environment)
        let fileSystem = FileSystem(allowedWriteRoots: [paths.appSupport])
        let palette = snapshotPalette()

        _ = try ShellAdapter(paths: paths, fileSystem: fileSystem).apply(palette: palette, dryRun: false)
        _ = try ChromeAdapter(paths: paths, fileSystem: fileSystem).apply(palette: palette, dryRun: false)

        let colorsSH = paths.generated.appendingPathComponent("shell/colors.sh")
        let manifest = paths.generated.appendingPathComponent("chrome/macwal-theme/manifest.json")

        #expect(try String(contentsOf: colorsSH, encoding: .utf8) == snapshot(named: "shell-colors.sh"))
        #expect(try String(contentsOf: manifest, encoding: .utf8) == snapshot(named: "chrome-manifest.json"))
    }

    @Test func terminalProfileMatchesSnapshot() throws {
        let temp = try TemporaryWorkspace()
        let paths = MacwalPaths(environment: temp.environment)
        let fileSystem = FileSystem(allowedWriteRoots: [paths.appSupport, paths.cache])
        let palette = snapshotPalette()
        var terminalConfig = MacwalConfig.default.adapters.terminal
        terminalConfig.setAsDefault = false

        _ = try TerminalAdapter(paths: paths, config: terminalConfig, fileSystem: fileSystem).apply(palette: palette, dryRun: false)

        let profile = paths.generated.appendingPathComponent("terminal/macwal.terminal")
        #expect(try terminalProfileSnapshot(at: profile).encodedJSON() == snapshot(named: "terminal-profile-summary.json"))
    }

    @Test func terminalProfileBackgroundIsTranslucent() throws {
        let temp = try TemporaryWorkspace()
        let paths = MacwalPaths(environment: temp.environment)
        let fileSystem = FileSystem(allowedWriteRoots: [paths.appSupport, paths.cache])
        let palette = snapshotPalette()
        var terminalConfig = MacwalConfig.default.adapters.terminal
        terminalConfig.setAsDefault = false

        _ = try TerminalAdapter(paths: paths, config: terminalConfig, fileSystem: fileSystem, opacity: 0.85).apply(palette: palette, dryRun: false)

        let profile = paths.generated.appendingPathComponent("terminal/macwal.terminal")
        let plist = try #require(try PropertyListSerialization.propertyList(from: Data(contentsOf: profile), format: nil) as? [String: Any])
        // Terminal.app translucency is the alpha channel of BackgroundColor;
        // every other color must stay fully opaque.
        let backgroundData = try #require(plist["BackgroundColor"] as? Data)
        let textData = try #require(plist["TextColor"] as? Data)
        let decodedBackground = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: backgroundData)
        let decodedText = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: textData)
        let backgroundAlpha = try #require(decodedBackground).alphaComponent
        let textAlpha = try #require(decodedText).alphaComponent
        #expect(abs(backgroundAlpha - 0.85) < 0.01)
        #expect(abs(textAlpha - 1.0) < 0.01)
    }

    @Test func configDecodesWithoutTerminalOpacity() throws {
        // A config.json written before terminalOpacity existed must still load,
        // defaulting the missing key to 0.85.
        let json = """
        {
          "schemaVersion": 1,
          "defaultTargets": ["shell"],
          "allowPrivateByDefault": false,
          "palette": { "mode": "auto", "minimumForegroundContrast": 7.0, "minimumAccentContrast": 3.0 },
          "adapters": {
            "terminal": { "profileName": "macwal", "setAsDefault": true },
            "obsidian": { "vaults": [] },
            "spotify": { "enabled": false, "spicetifyPath": "spicetify" },
            "system": { "setAppearanceMode": false, "setAccentColor": false, "setHighlightColor": false },
            "finder": { "setFolderTint": false, "folders": [] }
          }
        }
        """
        let config = try JSONDecoder().decode(MacwalConfig.self, from: Data(json.utf8))
        #expect(config.adapters.terminalOpacity == 0.85)
    }

    @Test func obsidianAndSpotifyArtifactsMatchSnapshots() throws {
        let temp = try TemporaryWorkspace()
        let vault = temp.root.appendingPathComponent("Vault", isDirectory: true)
        try FileManager.default.createDirectory(
            at: vault.appendingPathComponent(".obsidian", isDirectory: true),
            withIntermediateDirectories: true
        )
        let fakeBin = try temp.writeExecutable(
            named: "spicetify",
            contents: """
            #!/bin/sh
            exit 0
            """
        )
        let paths = MacwalPaths(environment: temp.environment)
        let obsidianFileSystem = FileSystem(allowedWriteRoots: [paths.appSupport, vault])
        let spotifyFileSystem = FileSystem(allowedWriteRoots: [
            paths.appSupport,
            paths.home.appendingPathComponent(".config/spicetify", isDirectory: true)
        ])
        var environment = temp.environment.environment
        environment["PATH"] = fakeBin.deletingLastPathComponent().path
        let commandExecutor = CommandExecutor(environment: environment)
        let palette = snapshotPalette()

        var obsidianConfig = MacwalConfig.default.adapters.obsidian
        obsidianConfig.vaults = [vault.path]
        var spotifyConfig = MacwalConfig.default.adapters.spotify
        spotifyConfig.enabled = true
        spotifyConfig.spicetifyPath = "spicetify"

        _ = try ObsidianAdapter(
            paths: paths,
            config: obsidianConfig,
            fileSystem: obsidianFileSystem
        ).apply(palette: palette, dryRun: false)
        _ = try SpotifyAdapter(
            paths: paths,
            config: spotifyConfig,
            fileSystem: spotifyFileSystem,
            backupManager: BackupManager(paths: paths, fileSystem: spotifyFileSystem, commandExecutor: commandExecutor),
            commandExecutor: commandExecutor
        ).apply(palette: palette, dryRun: false)

        let obsidianCSS = vault.appendingPathComponent(".obsidian/snippets/macwal.css")
        let obsidianAppearance = vault.appendingPathComponent(".obsidian/appearance.json")
        let spotifyINI = paths.home.appendingPathComponent(".config/spicetify/Themes/macwal/color.ini")

        #expect(try String(contentsOf: obsidianCSS, encoding: .utf8) == snapshot(named: "obsidian-macwal.css"))
        let appearanceJSON = try JSONSerialization.jsonObject(with: Data(contentsOf: obsidianAppearance)) as? [String: Any]
        #expect(appearanceJSON?["enabledCssSnippets"] as? [String] == ["macwal"])
        #expect(try String(contentsOf: spotifyINI, encoding: .utf8) == snapshot(named: "spotify-color.ini"))
    }

    @MainActor
    @Test func listTargetsJSONIncludesAllTargets() throws {
        let temp = try TemporaryWorkspace()
        let runner = CommandRunner(environment: temp.environment)

        let result = runner.run(arguments: ["list-targets", "--json"])

        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        let data = try #require(result.stdout.data(using: .utf8))
        let response = try JSONDecoder().decode(CommandResponse.self, from: data)
        #expect(response.success)
        #expect(response.command == "list-targets")
        let responseData = try #require(response.data)
        guard case .object(let root) = responseData,
              case .array(let targets)? = root["targets"] else {
            #expect(Bool(false), "Missing targets JSON.")
            return
        }
        #expect(targets.count == expectedTargetNames.count)
    }

    @MainActor
    @Test func previewAllSkipsUnavailableTargets() throws {
        let temp = try TemporaryWorkspace()
        let image = try temp.writePNG(named: "wallpaper.png", colors: [
            RGBColor(red: 30, green: 40, blue: 70),
            RGBColor(red: 90, green: 170, blue: 190)
        ])
        let runner = CommandRunner(environment: temp.environment)

        let result = runner.run(arguments: [
            "preview",
            "--image", image.path,
            "--targets", "all",
            "--json"
        ])

        #expect(result.exitCode == 0)
        let data = try #require(result.stdout.data(using: .utf8))
        let response = try JSONDecoder().decode(CommandResponse.self, from: data)
        let responseData = try #require(response.data)
        guard case .object(let root) = responseData,
              case .array(let targets)? = root["targets"] else {
            #expect(Bool(false), "Missing preview targets.")
            return
        }
        let names = targets.compactMap { value -> String? in
            guard case .object(let object) = value,
                  case .string(let target)? = object["target"] else {
                return nil
            }
            return target
        }
        #expect(names == ["terminal", "shell", "chrome", "safari"])
    }

    @MainActor
    @Test func applyAndRestoreFirefoxProfileDotfiles() throws {
        let temp = try TemporaryWorkspace()
        let firefoxRoot = temp.root.appendingPathComponent("Library/Application Support/Firefox", isDirectory: true)
        let profile = firefoxRoot.appendingPathComponent("Profiles/abc.default-release", isDirectory: true)
        try FileManager.default.createDirectory(at: profile, withIntermediateDirectories: true)
        try """
        [Profile0]
        Name=default-release
        IsRelative=1
        Path=Profiles/abc.default-release
        Default=1
        """.data(using: .utf8)?.write(to: firefoxRoot.appendingPathComponent("profiles.ini"))

        let image = try temp.writePNG(named: "wallpaper.png", colors: [
            RGBColor(red: 18, green: 26, blue: 36),
            RGBColor(red: 80, green: 150, blue: 170),
            RGBColor(red: 210, green: 120, blue: 80)
        ])
        let runner = CommandRunner(environment: temp.environment)

        let apply = runner.run(arguments: [
            "apply",
            "--image", image.path,
            "--targets", "firefox",
            "--json"
        ])

        #expect(apply.exitCode == 0)
        let chrome = profile.appendingPathComponent("chrome", isDirectory: true)
        let macwalCSS = chrome.appendingPathComponent("macwal.css")
        let userChrome = chrome.appendingPathComponent("userChrome.css")
        let userContent = chrome.appendingPathComponent("userContent.css")
        let userJS = profile.appendingPathComponent("user.js")

        #expect(try String(contentsOf: macwalCSS, encoding: .utf8).contains("--toolbar-bgcolor"))
        // New tab / home / blank page background is themed via a content-sheet block.
        #expect(try String(contentsOf: macwalCSS, encoding: .utf8).contains("--newtab-background-color"))
        #expect(try String(contentsOf: macwalCSS, encoding: .utf8).contains("about:newtab"))
        // Cleaner new tab: default logo/stories/sponsored clutter is hidden.
        #expect(try String(contentsOf: macwalCSS, encoding: .utf8).contains(".logo-and-wordmark"))
        #expect(try String(contentsOf: macwalCSS, encoding: .utf8).contains("display: none"))
        #expect(try String(contentsOf: macwalCSS, encoding: .utf8).contains("data-section-id=\"topstories\""))
        #expect(try String(contentsOf: userChrome, encoding: .utf8).contains("@import url(\"macwal.css\");"))
        #expect(try String(contentsOf: userContent, encoding: .utf8).contains("@import url(\"macwal.css\");"))
        #expect(try String(contentsOf: userJS, encoding: .utf8).contains("toolkit.legacyUserProfileCustomizations.stylesheets"))

        let restore = runner.run(arguments: [
            "restore",
            "--targets", "firefox"
        ])

        #expect(restore.exitCode == 0)
        #expect(!FileManager.default.fileExists(atPath: macwalCSS.path))
        #expect(!FileManager.default.fileExists(atPath: userChrome.path))
        #expect(!FileManager.default.fileExists(atPath: userContent.path))
        #expect(!FileManager.default.fileExists(atPath: userJS.path))
    }

    @MainActor
    @Test func applyAndRestoreGeneratedApplicationConfigs() throws {
        let temp = try TemporaryWorkspace(extraEnvironment: ["PATH": "/tmp/macwal-tests-no-tools"])
        let image = try temp.writePNG(named: "wallpaper.png", colors: [
            RGBColor(red: 18, green: 24, blue: 34),
            RGBColor(red: 90, green: 170, blue: 188),
            RGBColor(red: 210, green: 145, blue: 72)
        ])
        let runner = CommandRunner(environment: temp.environment)
        let targets = [
            "alacritty", "kitty", "wezterm", "ghostty", "iterm2", "vscode", "zed",
            "vim", "neovim", "tmux", "starship", "bat", "btop", "yazi", "fzf",
            "lazygit", "aerospace", "yabai", "sketchybar", "janky-borders",
            "hammerspoon", "raycast", "alfred", "discord", "telegram", "slack"
        ].joined(separator: ",")

        let apply = runner.run(arguments: [
            "apply",
            "--image", image.path,
            "--targets", targets,
            "--json"
        ])

        #expect(apply.exitCode == 0)
        let home = temp.root
        #expect(try String(contentsOf: home.appendingPathComponent(".config/alacritty/macwal.toml"), encoding: .utf8).contains("[colors.primary]"))
        #expect(try String(contentsOf: home.appendingPathComponent(".config/alacritty/alacritty.toml"), encoding: .utf8).contains("macwal.toml"))
        #expect(try String(contentsOf: home.appendingPathComponent(".config/kitty/macwal.conf"), encoding: .utf8).contains("color0"))
        #expect(try String(contentsOf: home.appendingPathComponent(".config/kitty/kitty.conf"), encoding: .utf8).contains("include macwal.conf"))
        #expect(try String(contentsOf: home.appendingPathComponent(".config/wezterm/macwal.lua"), encoding: .utf8).contains("return {"))
        #expect(try String(contentsOf: home.appendingPathComponent(".config/ghostty/themes/macwal"), encoding: .utf8).contains("palette = 0="))
        #expect(try String(contentsOf: home.appendingPathComponent("Library/Application Support/iTerm2/DynamicProfiles/macwal.json"), encoding: .utf8).contains("\"Profiles\""))
        // Terminal translucency (default opacity 0.85) is applied to every terminal.
        #expect(try String(contentsOf: home.appendingPathComponent(".config/alacritty/macwal.toml"), encoding: .utf8).contains("opacity = 0.85"))
        #expect(try String(contentsOf: home.appendingPathComponent(".config/kitty/macwal.conf"), encoding: .utf8).contains("background_opacity 0.85"))
        #expect(try String(contentsOf: home.appendingPathComponent(".config/ghostty/config"), encoding: .utf8).contains("background-opacity = 0.85"))
        #expect(try String(contentsOf: home.appendingPathComponent(".config/wezterm/wezterm.lua"), encoding: .utf8).contains("window_background_opacity = 0.85"))
        #expect(try String(contentsOf: home.appendingPathComponent("Library/Application Support/iTerm2/DynamicProfiles/macwal.json"), encoding: .utf8).contains("Transparency"))
        #expect(try String(contentsOf: home.appendingPathComponent(".vscode/extensions/macwal-theme/package.json"), encoding: .utf8).contains("\"macwal-theme\""))
        #expect(try String(contentsOf: home.appendingPathComponent("Library/Application Support/Code/User/settings.json"), encoding: .utf8).contains("workbench.colorTheme"))
        #expect(try String(contentsOf: home.appendingPathComponent(".config/zed/themes/macwal.json"), encoding: .utf8).contains("\"themes\""))
        #expect(try String(contentsOf: home.appendingPathComponent(".vimrc"), encoding: .utf8).contains("colorscheme macwal"))
        #expect(try String(contentsOf: home.appendingPathComponent(".config/nvim/init.vim"), encoding: .utf8).contains("colorscheme macwal"))
        #expect(try String(contentsOf: home.appendingPathComponent(".config/tmux/tmux.conf"), encoding: .utf8).contains("source-file ~/.config/tmux/macwal.tmux"))
        #expect(try String(contentsOf: home.appendingPathComponent(".config/starship.toml"), encoding: .utf8).contains("[palettes.macwal]"))
        #expect(try String(contentsOf: home.appendingPathComponent(".config/starship.toml"), encoding: .utf8).contains("palette = \"macwal\""))
        #expect(try String(contentsOf: home.appendingPathComponent(".config/bat/config"), encoding: .utf8).contains("--theme=macwal"))
        #expect(try String(contentsOf: home.appendingPathComponent(".config/btop/btop.conf"), encoding: .utf8).contains("color_theme = \"macwal\""))
        #expect(try String(contentsOf: home.appendingPathComponent(".config/yazi/flavors/macwal.flavor/flavor.toml"), encoding: .utf8).contains("[mgr]"))
        #expect(try String(contentsOf: home.appendingPathComponent(".config/yazi/theme.toml"), encoding: .utf8).contains("dark = \"macwal\""))
        #expect(try String(contentsOf: home.appendingPathComponent(".config/macwal/fzf.sh"), encoding: .utf8).contains("FZF_DEFAULT_OPTS"))
        #expect(try String(contentsOf: home.appendingPathComponent("Library/Application Support/lazygit/config.yml"), encoding: .utf8).contains("activeBorderColor"))
        #expect(try String(contentsOf: home.appendingPathComponent(".config/aerospace/macwal.toml"), encoding: .utf8).contains("[macwal]"))
        #expect(try String(contentsOf: home.appendingPathComponent("Library/Application Support/macwal/generated/yabai/macwal.sh"), encoding: .utf8).contains("yabai -m config"))
        #expect(try String(contentsOf: home.appendingPathComponent("Library/Application Support/macwal/generated/sketchybar/macwal.sh"), encoding: .utf8).contains("sketchybar --bar"))
        #expect(try String(contentsOf: home.appendingPathComponent("Library/Application Support/macwal/generated/janky-borders/macwal.sh"), encoding: .utf8).contains("borders active_color"))
        #expect(try String(contentsOf: home.appendingPathComponent(".hammerspoon/init.lua"), encoding: .utf8).contains("dofile"))
        #expect(try String(contentsOf: home.appendingPathComponent("Library/Application Support/macwal/generated/raycast/colors.json"), encoding: .utf8).contains("\"accent\""))
        #expect(try String(contentsOf: home.appendingPathComponent("Library/Application Support/macwal/generated/alfred/colors.json"), encoding: .utf8).contains("\"accent\""))
        #expect(try String(contentsOf: home.appendingPathComponent(".config/Vencord/themes/macwal.css"), encoding: .utf8).contains("@name macwal"))
        #expect(try String(contentsOf: home.appendingPathComponent("Library/Application Support/macwal/generated/telegram/colors.json"), encoding: .utf8).contains("\"accent\""))
        #expect(try String(contentsOf: home.appendingPathComponent("Library/Application Support/macwal/generated/slack/colors.json"), encoding: .utf8).contains("\"accent\""))

        let restore = runner.run(arguments: [
            "restore",
            "--targets", targets
        ])

        #expect(restore.exitCode == 0)
        #expect(!FileManager.default.fileExists(atPath: home.appendingPathComponent(".config/alacritty/macwal.toml").path))
        #expect(!FileManager.default.fileExists(atPath: home.appendingPathComponent(".config/kitty/macwal.conf").path))
        #expect(!FileManager.default.fileExists(atPath: home.appendingPathComponent(".config/wezterm/macwal.lua").path))
        #expect(!FileManager.default.fileExists(atPath: home.appendingPathComponent(".config/Vencord/themes/macwal.css").path))
    }

    @MainActor
    @Test func applyShellDryRunDoesNotWriteAppSupport() throws {
        let temp = try TemporaryWorkspace()
        let image = try temp.writePNG(named: "wallpaper.png", colors: [
            RGBColor(red: 40, green: 60, blue: 90),
            RGBColor(red: 180, green: 95, blue: 45)
        ])
        let runner = CommandRunner(environment: temp.environment)

        let result = runner.run(arguments: [
            "apply",
            "--image", image.path,
            "--targets", "shell",
            "--dry-run",
            "--json"
        ])

        #expect(result.exitCode == 0)
        #expect(!FileManager.default.fileExists(atPath: temp.appSupport.path))
    }

    @MainActor
    @Test func applyAndRestoreShellGeneratedFiles() throws {
        let temp = try TemporaryWorkspace()
        let image = try temp.writePNG(named: "wallpaper.png", colors: [
            RGBColor(red: 15, green: 28, blue: 38),
            RGBColor(red: 92, green: 150, blue: 160),
            RGBColor(red: 220, green: 170, blue: 70)
        ])
        let runner = CommandRunner(environment: temp.environment)

        let apply = runner.run(arguments: [
            "apply",
            "--image", image.path,
            "--targets", "shell"
        ])

        #expect(apply.exitCode == 0)
        let shellDirectory = temp.appSupport.appendingPathComponent("generated/shell", isDirectory: true)
        let colorsSH = shellDirectory.appendingPathComponent("colors.sh")
        let colorsJSON = shellDirectory.appendingPathComponent("colors.json")
        let colorsCSS = shellDirectory.appendingPathComponent("colors.css")
        let colorsXresources = shellDirectory.appendingPathComponent("colors.Xresources")

        #expect(FileManager.default.fileExists(atPath: colorsSH.path))
        #expect(FileManager.default.fileExists(atPath: colorsJSON.path))
        #expect(FileManager.default.fileExists(atPath: colorsCSS.path))
        #expect(FileManager.default.fileExists(atPath: colorsXresources.path))

        let shellText = try String(contentsOf: colorsSH, encoding: .utf8)
        #expect(shellText.contains("MACWAL_COLOR_BACKGROUND"))
        #expect(shellText.contains("MACWAL_COLOR_BRIGHT_BLACK"))

        let restore = runner.run(arguments: [
            "restore",
            "--targets", "shell"
        ])

        #expect(restore.exitCode == 0)
        #expect(!FileManager.default.fileExists(atPath: colorsSH.path))
        #expect(!FileManager.default.fileExists(atPath: colorsJSON.path))
        #expect(!FileManager.default.fileExists(atPath: colorsCSS.path))
        #expect(!FileManager.default.fileExists(atPath: colorsXresources.path))
    }

    @MainActor
    @Test func restoreShellPreservesPreExistingGeneratedFile() throws {
        let temp = try TemporaryWorkspace()
        let shellDirectory = temp.appSupport.appendingPathComponent("generated/shell", isDirectory: true)
        let colorsSH = shellDirectory.appendingPathComponent("colors.sh")
        try FileManager.default.createDirectory(at: shellDirectory, withIntermediateDirectories: true)
        try "original\n".write(to: colorsSH, atomically: true, encoding: .utf8)

        let image = try temp.writePNG(named: "wallpaper.png", colors: [
            RGBColor(red: 15, green: 28, blue: 38),
            RGBColor(red: 92, green: 150, blue: 160),
            RGBColor(red: 220, green: 170, blue: 70)
        ])
        let runner = CommandRunner(environment: temp.environment)

        let apply = runner.run(arguments: [
            "apply",
            "--image", image.path,
            "--targets", "shell"
        ])
        #expect(apply.exitCode == 0)
        #expect(try String(contentsOf: colorsSH, encoding: .utf8) != "original\n")

        let restore = runner.run(arguments: [
            "restore",
            "--targets", "shell"
        ])
        #expect(restore.exitCode == 0)
        #expect(try String(contentsOf: colorsSH, encoding: .utf8) == "original\n")
    }

    @MainActor
    @Test func applyTerminalAndChromeGeneratedFiles() throws {
        let temp = try TemporaryWorkspace()
        let image = try temp.writePNG(named: "wallpaper.png", colors: [
            RGBColor(red: 18, green: 32, blue: 48),
            RGBColor(red: 80, green: 155, blue: 175),
            RGBColor(red: 225, green: 148, blue: 75)
        ])
        let runner = CommandRunner(environment: temp.environment)

        let apply = runner.run(arguments: [
            "apply",
            "--image", image.path,
            "--targets", "terminal,chrome"
        ])

        #expect(apply.exitCode == 0)

        let terminalProfile = temp.appSupport.appendingPathComponent("generated/terminal/macwal.terminal")
        let terminalData = try Data(contentsOf: terminalProfile)
        let terminalPlist = try PropertyListSerialization.propertyList(from: terminalData, format: nil) as? [String: Any]
        let terminal = try #require(terminalPlist)
        #expect(terminal["name"] as? String == "macwal")
        #expect(terminal["ANSIRedColor"] is Data)
        #expect(terminal["BackgroundColor"] is Data)

        let manifest = temp.appSupport.appendingPathComponent("generated/chrome/macwal-theme/manifest.json")
        let manifestData = try Data(contentsOf: manifest)
        let manifestJSON = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any]
        let chrome = try #require(manifestJSON)
        #expect(chrome["manifest_version"] as? Int == 3)
        let theme = try #require(chrome["theme"] as? [String: Any])
        let colors = try #require(theme["colors"] as? [String: Any])
        #expect(colors["frame"] is [Int])
        #expect(colors["button_background"] is [Int])

        let restore = runner.run(arguments: [
            "restore",
            "--targets", "terminal,chrome"
        ])

        #expect(restore.exitCode == 0)
        #expect(!FileManager.default.fileExists(atPath: terminalProfile.path))
        #expect(!FileManager.default.fileExists(atPath: manifest.path))
    }

    @MainActor
    @Test func terminalSetAsDefaultDryRunReportsPreferenceWrites() throws {
        let temp = try TemporaryWorkspace()
        var config = MacwalConfig.default
        config.adapters.terminal.setAsDefault = true
        config.adapters.terminal.profileName = "macwal-test"
        try temp.writeConfig(config)

        let image = try temp.writePNG(named: "wallpaper.png", colors: [
            RGBColor(red: 18, green: 32, blue: 48),
            RGBColor(red: 80, green: 155, blue: 175)
        ])
        let runner = CommandRunner(environment: temp.environment)

        let result = runner.run(arguments: [
            "apply",
            "--image", image.path,
            "--targets", "terminal",
            "--dry-run",
            "--json"
        ])

        #expect(result.exitCode == 0)
        let data = try #require(result.stdout.data(using: .utf8))
        let response = try JSONDecoder().decode(CommandResponse.self, from: data)
        let responseData = try #require(response.data)
        guard case .object(let root) = responseData,
              case .array(let targets)? = root["targets"],
              case .object(let terminal)? = targets.first,
              case .array(let changed)? = terminal["changedPaths"] else {
            #expect(Bool(false), "Missing Terminal changed paths.")
            return
        }

        #expect(changed.contains(.string("com.apple.Terminal:Window Settings")))
        #expect(changed.contains(.string("com.apple.Terminal:Default Window Settings")))
        #expect(changed.contains(.string("com.apple.Terminal:Startup Window Settings")))
    }

    @MainActor
    @Test func terminalSetAsDefaultAppliesWithoutAllowPrivate() throws {
        let temp = try TemporaryWorkspace()
        var config = MacwalConfig.default
        config.adapters.terminal.setAsDefault = true
        try temp.writeConfig(config)

        let image = try temp.writePNG(named: "wallpaper.png", colors: [
            RGBColor(red: 18, green: 32, blue: 48),
            RGBColor(red: 80, green: 155, blue: 175)
        ])
        let runner = CommandRunner(environment: temp.environment)

        let result = runner.run(arguments: [
            "apply",
            "--image", image.path,
            "--targets", "terminal",
            "--json"
        ])

        #expect(result.exitCode == 0)
        let data = try #require(result.stdout.data(using: .utf8))
        let response = try JSONDecoder().decode(CommandResponse.self, from: data)
        #expect(response.success)
        let terminalProfile = temp.appSupport.appendingPathComponent("generated/terminal/macwal.terminal")
        #expect(FileManager.default.fileExists(atPath: terminalProfile.path))

        let restore = runner.run(arguments: [
            "restore",
            "--targets", "terminal"
        ])
        #expect(restore.exitCode == 0)
        #expect(!FileManager.default.fileExists(atPath: terminalProfile.path))

        let paths = MacwalPaths(environment: temp.environment)
        let fileSystem = FileSystem(allowedWriteRoots: [paths.appSupport, paths.cache])
        let defaults = DefaultsClient(
            paths: paths,
            executor: CommandExecutor(environment: temp.environment.environment),
            fileSystem: fileSystem
        )
        #expect(try defaults.readValue(domain: "com.apple.Terminal", key: "Window Settings") == nil)
        #expect(try defaults.readValue(domain: "com.apple.Terminal", key: "Default Window Settings") == nil)
        #expect(try defaults.readValue(domain: "com.apple.Terminal", key: "Startup Window Settings") == nil)
    }

    @MainActor
    @Test func terminalRestorePreservesExistingDefaultsKeys() throws {
        let temp = try TemporaryWorkspace()
        let paths = MacwalPaths(environment: temp.environment)
        let fileSystem = FileSystem(allowedWriteRoots: [paths.appSupport, paths.cache])
        let commandExecutor = CommandExecutor(environment: temp.environment.environment)
        let defaults = DefaultsClient(paths: paths, executor: commandExecutor, fileSystem: fileSystem)

        try defaults.setValue(
            ["Basic": ["name": "Basic"]],
            domain: "com.apple.Terminal",
            key: "Window Settings"
        )
        try defaults.setValue("Basic", domain: "com.apple.Terminal", key: "Default Window Settings")
        try defaults.setValue("Basic", domain: "com.apple.Terminal", key: "Startup Window Settings")

        var config = MacwalConfig.default
        config.adapters.terminal.profileName = "macwal"
        config.adapters.terminal.setAsDefault = true
        try temp.writeConfig(config)

        let image = try temp.writePNG(named: "wallpaper.png", colors: [
            RGBColor(red: 18, green: 32, blue: 48),
            RGBColor(red: 80, green: 155, blue: 175)
        ])
        let runner = CommandRunner(environment: temp.environment, commandExecutor: commandExecutor)

        let apply = runner.run(arguments: [
            "apply",
            "--image", image.path,
            "--targets", "terminal"
        ])
        #expect(apply.exitCode == 0)
        #expect(try defaults.readValue(domain: "com.apple.Terminal", key: "Default Window Settings") as? String == "macwal")
        #expect(try defaults.readValue(domain: "com.apple.Terminal", key: "Startup Window Settings") as? String == "macwal")

        let restore = runner.run(arguments: [
            "restore",
            "--targets", "terminal"
        ])
        #expect(restore.exitCode == 0)
        #expect(try defaults.readValue(domain: "com.apple.Terminal", key: "Default Window Settings") as? String == "Basic")
        #expect(try defaults.readValue(domain: "com.apple.Terminal", key: "Startup Window Settings") as? String == "Basic")

        let windowSettings = try defaults.readValue(domain: "com.apple.Terminal", key: "Window Settings") as? [String: Any]
        let basic = try #require(windowSettings?["Basic"] as? [String: Any])
        #expect(basic["name"] as? String == "Basic")
        #expect(windowSettings?["macwal"] == nil)
    }

    @MainActor
    @Test func applyAndRestoreObsidianSnippet() throws {
        let temp = try TemporaryWorkspace()
        let vault = temp.root.appendingPathComponent("Vault", isDirectory: true)
        try FileManager.default.createDirectory(
            at: vault.appendingPathComponent(".obsidian", isDirectory: true),
            withIntermediateDirectories: true
        )

        var config = MacwalConfig.default
        config.defaultTargets = ["obsidian"]
        config.adapters.obsidian.vaults = [vault.path]
        try temp.writeConfig(config)

        let image = try temp.writePNG(named: "wallpaper.png", colors: [
            RGBColor(red: 25, green: 35, blue: 60),
            RGBColor(red: 165, green: 95, blue: 150)
        ])
        let runner = CommandRunner(environment: temp.environment)

        let apply = runner.run(arguments: [
            "apply",
            "--image", image.path,
            "--targets", "obsidian"
        ])

        #expect(apply.exitCode == 0)
        let snippet = vault.appendingPathComponent(".obsidian/snippets/macwal.css")
        let appearance = vault.appendingPathComponent(".obsidian/appearance.json")
        let css = try String(contentsOf: snippet, encoding: .utf8)
        #expect(css.contains("--background-primary"))
        #expect(!css.contains("Enable this snippet once"))

        let appearanceJSON = try JSONSerialization.jsonObject(with: Data(contentsOf: appearance)) as? [String: Any]
        let enabledSnippets = try #require(appearanceJSON?["enabledCssSnippets"] as? [String])
        #expect(enabledSnippets == ["macwal"])

        let restore = runner.run(arguments: [
            "restore",
            "--targets", "obsidian"
        ])

        #expect(restore.exitCode == 0)
        #expect(!FileManager.default.fileExists(atPath: snippet.path))
        #expect(!FileManager.default.fileExists(atPath: appearance.path))
    }

    @MainActor
    @Test func obsidianRestorePreservesExistingAppearanceJSON() throws {
        let temp = try TemporaryWorkspace()
        let vault = temp.root.appendingPathComponent("Vault", isDirectory: true)
        let obsidianDirectory = vault.appendingPathComponent(".obsidian", isDirectory: true)
        try FileManager.default.createDirectory(at: obsidianDirectory, withIntermediateDirectories: true)
        let appearance = obsidianDirectory.appendingPathComponent("appearance.json")
        let originalAppearance = """
        {
          "baseFontSize" : 16,
          "enabledCssSnippets" : [
            "existing"
          ]
        }
        """
        try originalAppearance.write(to: appearance, atomically: true, encoding: .utf8)

        var config = MacwalConfig.default
        config.defaultTargets = ["obsidian"]
        config.adapters.obsidian.vaults = [vault.path]
        try temp.writeConfig(config)

        let image = try temp.writePNG(named: "wallpaper.png", colors: [
            RGBColor(red: 25, green: 35, blue: 60),
            RGBColor(red: 165, green: 95, blue: 150)
        ])
        let runner = CommandRunner(environment: temp.environment)

        let apply = runner.run(arguments: [
            "apply",
            "--image", image.path,
            "--targets", "obsidian"
        ])
        #expect(apply.exitCode == 0)

        let appliedJSON = try JSONSerialization.jsonObject(with: Data(contentsOf: appearance)) as? [String: Any]
        let enabledSnippets = try #require(appliedJSON?["enabledCssSnippets"] as? [String])
        #expect(enabledSnippets == ["existing", "macwal"])
        #expect(appliedJSON?["baseFontSize"] as? Int == 16)

        let restore = runner.run(arguments: [
            "restore",
            "--targets", "obsidian"
        ])
        #expect(restore.exitCode == 0)
        #expect(try String(contentsOf: appearance, encoding: .utf8) == originalAppearance)
    }

    @MainActor
    @Test func privateSystemTargetRequiresAllowPrivate() throws {
        let temp = try TemporaryWorkspace()
        let image = try temp.writePNG(named: "wallpaper.png", colors: [
            RGBColor(red: 30, green: 30, blue: 45),
            RGBColor(red: 190, green: 80, blue: 110)
        ])
        let runner = CommandRunner(environment: temp.environment)

        let result = runner.run(arguments: [
            "apply",
            "--image", image.path,
            "--targets", "system",
            "--json"
        ])

        #expect(result.exitCode == 3)
        #expect(result.stderr.isEmpty)
        let data = try #require(result.stdout.data(using: .utf8))
        let response = try JSONDecoder().decode(CommandResponse.self, from: data)
        #expect(!response.success)
    }

    @MainActor
    @Test func systemDryRunWithAllowPrivateReportsPreferenceWrites() throws {
        let temp = try TemporaryWorkspace()
        var config = MacwalConfig.default
        config.adapters.system.setAppearanceMode = true
        config.adapters.system.setAccentColor = true
        config.adapters.system.setHighlightColor = true
        try temp.writeConfig(config)

        let image = try temp.writePNG(named: "wallpaper.png", colors: [
            RGBColor(red: 20, green: 40, blue: 70),
            RGBColor(red: 230, green: 160, blue: 80)
        ])
        let runner = CommandRunner(environment: temp.environment)

        let result = runner.run(arguments: [
            "apply",
            "--image", image.path,
            "--targets", "system",
            "--allow-private",
            "--dry-run",
            "--json"
        ])

        #expect(result.exitCode == 0)
        let data = try #require(result.stdout.data(using: .utf8))
        let response = try JSONDecoder().decode(CommandResponse.self, from: data)
        #expect(response.success)
        let responseData = try #require(response.data)
        guard case .object(let root) = responseData,
              case .array(let targets)? = root["targets"],
              case .object(let system)? = targets.first,
              case .array(let changed)? = system["changedPaths"] else {
            #expect(Bool(false), "Missing system changed paths.")
            return
        }
        #expect(changed.contains(.string("-globalDomain:AppleAccentColor")))
        #expect(changed.contains(.string("-globalDomain:AppleHighlightColor")))
    }

    @MainActor
    @Test func privateSystemDryRunDoesNotRequireAllowPrivate() throws {
        let temp = try TemporaryWorkspace()
        var config = MacwalConfig.default
        config.adapters.system.setAccentColor = true
        try temp.writeConfig(config)

        let image = try temp.writePNG(named: "wallpaper.png", colors: [
            RGBColor(red: 20, green: 40, blue: 70),
            RGBColor(red: 230, green: 160, blue: 80)
        ])
        let runner = CommandRunner(environment: temp.environment)

        let result = runner.run(arguments: [
            "apply",
            "--image", image.path,
            "--targets", "system",
            "--dry-run",
            "--json"
        ])

        #expect(result.exitCode == 0)
        #expect(!FileManager.default.fileExists(atPath: temp.appSupport.appendingPathComponent("backups/index.json").path))
        let data = try #require(result.stdout.data(using: .utf8))
        let response = try JSONDecoder().decode(CommandResponse.self, from: data)
        #expect(response.success)
    }

    @MainActor
    @Test func applySpotifyWithFakeSpicetifyWritesThemeAndRunsCommands() throws {
        let temp = try TemporaryWorkspace()
        let fakeBin = try temp.writeExecutable(
            named: "spicetify",
            contents: """
            #!/bin/sh
            echo "$@" >> "\(temp.root.path)/spicetify.log"
            exit 0
            """
        )

        var config = MacwalConfig.default
        config.adapters.spotify.enabled = true
        config.adapters.spotify.spicetifyPath = "spicetify"
        try temp.writeConfig(config)

        var env = temp.environment.environment
        env["PATH"] = fakeBin.deletingLastPathComponent().path
        let environment = RuntimeEnvironment(homeDirectory: temp.root, currentDirectory: temp.root, environment: env)
        let runner = CommandRunner(environment: environment)

        let image = try temp.writePNG(named: "wallpaper.png", colors: [
            RGBColor(red: 12, green: 22, blue: 40),
            RGBColor(red: 80, green: 180, blue: 200)
        ])

        let apply = runner.run(arguments: [
            "apply",
            "--image", image.path,
            "--targets", "spotify"
        ])

        #expect(apply.exitCode == 0)
        let theme = temp.root.appendingPathComponent(".config/spicetify/Themes/macwal", isDirectory: true)
        let colorINI = theme.appendingPathComponent("color.ini")
        let userCSS = theme.appendingPathComponent("user.css")
        #expect(FileManager.default.fileExists(atPath: colorINI.path))
        #expect(FileManager.default.fileExists(atPath: userCSS.path))

        let log = try String(contentsOf: temp.root.appendingPathComponent("spicetify.log"), encoding: .utf8)
        #expect(log.contains("config current_theme macwal"))
        #expect(log.contains("apply"))

        let restore = runner.run(arguments: ["restore", "--targets", "spotify"])
        #expect(restore.exitCode == 0)
        #expect(!FileManager.default.fileExists(atPath: colorINI.path))
        #expect(!FileManager.default.fileExists(atPath: userCSS.path))

        let restoredLog = try String(contentsOf: temp.root.appendingPathComponent("spicetify.log"), encoding: .utf8)
        #expect(restoredLog.components(separatedBy: "\n").filter { $0 == "apply" }.count == 2)
    }

    @MainActor
    @Test func applyAndRestoreFinderTagXattr() throws {
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 else {
            return
        }

        let temp = try TemporaryWorkspace()
        let folder = temp.root.appendingPathComponent("Tinted", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        var config = MacwalConfig.default
        config.adapters.finder.setFolderTint = true
        config.adapters.finder.folders = [folder.path]
        try temp.writeConfig(config)

        let image = try temp.writePNG(named: "wallpaper.png", colors: [
            RGBColor(red: 8, green: 32, blue: 50),
            RGBColor(red: 0, green: 122, blue: 255)
        ])
        let runner = CommandRunner(environment: temp.environment)

        let apply = runner.run(arguments: [
            "apply",
            "--image", image.path,
            "--targets", "finder",
            "--allow-private"
        ])

        #expect(apply.exitCode == 0)
        let tags = try readFinderTags(from: folder)
        #expect(tags.contains(where: { $0.hasPrefix("macwal\n") }))

        let restore = runner.run(arguments: [
            "restore",
            "--targets", "finder"
        ])

        #expect(restore.exitCode == 0)
        #expect(try readFinderTags(from: folder).isEmpty)
    }

    @MainActor
    @Test func watchInstallAndUninstallWritesLaunchAgent() throws {
        let temp = try TemporaryWorkspace(extraEnvironment: [
            "MACWAL_SKIP_LAUNCHCTL": "1",
            "MACWAL_EXECUTABLE": "/tmp/macwal"
        ])
        let runner = CommandRunner(environment: temp.environment)

        let install = runner.run(arguments: [
            "watch",
            "install",
            "--targets", "shell",
            "--json"
        ])

        #expect(install.exitCode == 0)
        let plistData = try Data(contentsOf: temp.root.appendingPathComponent("Library/LaunchAgents/io.macwal.watch.plist"))
        let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
        let launchAgent = try #require(plist)
        #expect(launchAgent["Label"] as? String == "io.macwal.watch")
        let args = try #require(launchAgent["ProgramArguments"] as? [String])
        #expect(args.contains("watch"))
        #expect(args.contains("run"))
        #expect(args.contains("shell"))

        let uninstall = runner.run(arguments: ["watch", "uninstall"])
        #expect(uninstall.exitCode == 0)
        #expect(!FileManager.default.fileExists(atPath: temp.root.appendingPathComponent("Library/LaunchAgents/io.macwal.watch.plist").path))
    }

    @MainActor
    @Test func watchRunSkipsWhenSignatureHasNotChanged() throws {
        let temp = try TemporaryWorkspace()
        let image = try temp.writePNG(named: "wallpaper.png", colors: [
            RGBColor(red: 20, green: 40, blue: 60),
            RGBColor(red: 100, green: 180, blue: 190)
        ])
        let runner = CommandRunner(environment: temp.environment)

        let first = runner.run(arguments: [
            "watch",
            "run",
            "--image", image.path,
            "--targets", "shell"
        ])
        let second = runner.run(arguments: [
            "watch",
            "run",
            "--image", image.path,
            "--targets", "shell"
        ])

        #expect(first.exitCode == 0)
        #expect(second.exitCode == 0)
        #expect(second.stdout.contains("No wallpaper or target changes detected"))
    }

    @MainActor
    @Test func setAppliesTargetsAndReportsWallpaper() throws {
        let temp = try TemporaryWorkspace()
        let image = try temp.writePNG(named: "wall.png", colors: [
            RGBColor(red: 16, green: 26, blue: 40),
            RGBColor(red: 90, green: 170, blue: 190),
            RGBColor(red: 214, green: 150, blue: 78)
        ])
        let runner = CommandRunner(environment: temp.environment)

        // Explicit --targets keeps this deterministic (installed-detection would
        // otherwise depend on what is installed on the test machine). Wallpaper
        // setting is a no-op because TemporaryWorkspace sets MACWAL_SKIP_WALLPAPER.
        let result = runner.run(arguments: [
            "set",
            "--image", image.path,
            "--targets", "shell,chrome",
            "--json"
        ])

        #expect(result.exitCode == 0)
        let data = try #require(result.stdout.data(using: .utf8))
        let response = try JSONDecoder().decode(CommandResponse.self, from: data)
        #expect(response.success)
        #expect(response.command == "set")
        let responseData = try #require(response.data)
        guard case .object(let root) = responseData,
              case .string(let wallpaper)? = root["wallpaper"],
              case .bool(let wallpaperChanged)? = root["wallpaperChanged"] else {
            #expect(Bool(false), "Missing set wallpaper fields.")
            return
        }
        #expect(wallpaper == image.path)
        #expect(wallpaperChanged == false) // skipped by MACWAL_SKIP_WALLPAPER
        #expect(response.messages.contains { $0.text.contains("Skipped setting wallpaper") })

        // The theme was actually written for the requested targets.
        let colorsSH = temp.appSupport.appendingPathComponent("generated/shell/colors.sh")
        let manifest = temp.appSupport.appendingPathComponent("generated/chrome/macwal-theme/manifest.json")
        #expect(FileManager.default.fileExists(atPath: colorsSH.path))
        #expect(FileManager.default.fileExists(atPath: manifest.path))
    }

    @MainActor
    @Test func setPicksRandomImageFromFolder() throws {
        let temp = try TemporaryWorkspace()
        let folder = temp.root.appendingPathComponent("Walls", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var expectedPaths: Set<String> = []
        for name in ["a.png", "b.png", "c.png"] {
            let url = try temp.writePNG(named: "Walls/\(name)", colors: [
                RGBColor(red: 20, green: 30, blue: 40),
                RGBColor(red: 120, green: 160, blue: 180)
            ])
            expectedPaths.insert(url.standardizedFileURL.path)
        }
        let runner = CommandRunner(environment: temp.environment)

        let result = runner.run(arguments: [
            "set",
            "--image", folder.path,
            "--targets", "shell",
            "--json"
        ])

        #expect(result.exitCode == 0)
        let data = try #require(result.stdout.data(using: .utf8))
        let response = try JSONDecoder().decode(CommandResponse.self, from: data)
        let responseData = try #require(response.data)
        guard case .object(let root) = responseData,
              case .string(let wallpaper)? = root["wallpaper"] else {
            #expect(Bool(false), "Missing chosen wallpaper.")
            return
        }
        // The chosen wallpaper must be one of the images in the folder.
        #expect(expectedPaths.contains(wallpaper))
    }

    @MainActor
    @Test func setWithMissingImageFolderFails() throws {
        let temp = try TemporaryWorkspace()
        let empty = temp.root.appendingPathComponent("Empty", isDirectory: true)
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        let runner = CommandRunner(environment: temp.environment)

        let result = runner.run(arguments: [
            "set",
            "--image", empty.path,
            "--targets", "shell",
            "--json"
        ])

        #expect(result.exitCode != 0)
    }

    @Test func installedSupportedTargetsReflectsConfigAndExcludesSafari() throws {
        let temp = try TemporaryWorkspace()
        let paths = MacwalPaths(environment: temp.environment)
        // Empty PATH so CLI-based detection is deterministic (no tools found).
        var env = temp.environment.environment
        env["PATH"] = "/tmp/macwal-tests-no-tools"
        let commandExecutor = CommandExecutor(environment: env)

        var config = MacwalConfig.default
        config.adapters.obsidian.vaults = []
        let registryNoVault = AdapterRegistry(paths: paths, config: config, commandExecutor: commandExecutor)
        // Always-available targets are detected; safari is never in the set.
        #expect(registryNoVault.isInstalled(.system))
        #expect(registryNoVault.isInstalled(.shell))
        #expect(registryNoVault.isInstalled(.terminal))
        #expect(registryNoVault.isInstalled(.obsidian) == false)
        #expect(registryNoVault.isInstalled(.spotify) == false) // spicetify not on PATH
        #expect(registryNoVault.installedSupportedTargets(allowPrivate: false).contains(.safari) == false)
        // Private targets require allowPrivate.
        #expect(registryNoVault.installedSupportedTargets(allowPrivate: false).contains(.system) == false)
        #expect(registryNoVault.installedSupportedTargets(allowPrivate: true).contains(.system))

        config.adapters.obsidian.vaults = [temp.root.appendingPathComponent("Vault").path]
        let registryWithVault = AdapterRegistry(paths: paths, config: config, commandExecutor: commandExecutor)
        #expect(registryWithVault.isInstalled(.obsidian))
    }

    private var ansiKeys: [String] {
        [
            "black", "red", "green", "yellow", "blue", "magenta", "cyan", "white",
            "brightBlack", "brightRed", "brightGreen", "brightYellow", "brightBlue",
            "brightMagenta", "brightCyan", "brightWhite"
        ]
    }

    private var expectedTargetNames: [String] {
        [
            "system", "terminal", "shell", "obsidian", "chrome", "firefox",
            "librewolf", "zen", "floorp", "safari", "spotify", "alacritty",
            "kitty", "wezterm", "ghostty", "iterm2", "vscode", "zed", "vim",
            "neovim", "tmux", "starship", "bat", "btop", "yazi", "fzf",
            "lazygit", "aerospace", "yabai", "sketchybar", "janky-borders",
            "hammerspoon", "raycast", "alfred", "discord", "thunderbird",
            "telegram", "slack", "finder"
        ]
    }

    private func snapshotPalette() -> PaletteDocument {
        PaletteDocument(
            generatedAt: "1970-01-01T00:00:00Z",
            source: PaletteSource(kind: "image", path: "/fixtures/wallpaper.png"),
            appearance: PaletteAppearance(
                recommendedMode: "dark",
                wallpaperLuminance: 0.2375,
                contrastValidated: true
            ),
            colors: [
                "accent": "#5aa9bc",
                "accentAlt": "#8ec6d3",
                "background": "#101820",
                "black": "#101820",
                "blue": "#588bca",
                "brightBlack": "#51575b",
                "brightBlue": "#7eb1e6",
                "brightCyan": "#7bbaca",
                "brightGreen": "#90be87",
                "brightMagenta": "#cc99da",
                "brightRed": "#ee7070",
                "brightWhite": "#ffffff",
                "brightYellow": "#e6c76c",
                "cursor": "#f6f2ea",
                "cyan": "#5aa9bc",
                "foreground": "#f6f2ea",
                "green": "#70a069",
                "magenta": "#b074c2",
                "red": "#d75252",
                "selection": "#2f6f86",
                "white": "#dfdcd5",
                "yellow": "#caa44a"
            ]
        )
    }

    private func snapshot(named name: String) throws -> String {
        let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Snapshots")
            ?? Bundle.module.url(forResource: name, withExtension: nil)
        guard let url else {
            throw MacwalError.adapterFailed("Missing test snapshot: \(name)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func terminalProfileSnapshot(at url: URL) throws -> TerminalProfileSnapshot {
        let data = try Data(contentsOf: url)
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw MacwalError.adapterFailed("Could not read Terminal profile plist.")
        }

        let colorKeys = [
            "ANSIBlackColor",
            "ANSIRedColor",
            "ANSIGreenColor",
            "ANSIYellowColor",
            "ANSIBlueColor",
            "ANSIMagentaColor",
            "ANSICyanColor",
            "ANSIWhiteColor",
            "ANSIBrightBlackColor",
            "ANSIBrightRedColor",
            "ANSIBrightGreenColor",
            "ANSIBrightYellowColor",
            "ANSIBrightBlueColor",
            "ANSIBrightMagentaColor",
            "ANSIBrightCyanColor",
            "ANSIBrightWhiteColor",
            "BackgroundColor",
            "CursorColor",
            "SelectionColor",
            "TextBoldColor",
            "TextColor"
        ]

        var colors: [String: String] = [:]
        for key in colorKeys {
            guard let colorData = plist[key] as? Data else {
                throw MacwalError.adapterFailed("Missing Terminal color key: \(key)")
            }
            colors[key] = try decodedColorHex(from: colorData)
        }

        return TerminalProfileSnapshot(
            colors: colors,
            settings: [
                "BackgroundBlur": stringValue(plist["BackgroundBlur"]),
                "BackgroundBlurInactive": stringValue(plist["BackgroundBlurInactive"]),
                "DynamicANSIForegroundColors": stringValue(plist["DynamicANSIForegroundColors"]),
                "FontAntialias": stringValue(plist["FontAntialias"]),
                "ProfileCurrentVersion": stringValue(plist["ProfileCurrentVersion"]),
                "columnCount": stringValue(plist["columnCount"]),
                "name": stringValue(plist["name"]),
                "rowCount": stringValue(plist["rowCount"]),
                "type": stringValue(plist["type"])
            ]
        )
    }

    private func decodedColorHex(from data: Data) throws -> String {
        guard let color = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) else {
            throw MacwalError.adapterFailed("Could not decode archived Terminal color.")
        }
        return RGBColor(
            red: UInt8(max(0, min(255, round(color.redComponent * 255)))),
            green: UInt8(max(0, min(255, round(color.greenComponent * 255)))),
            blue: UInt8(max(0, min(255, round(color.blueComponent * 255))))
        ).hex
    }

    private func stringValue(_ value: Any?) -> String {
        switch value {
        case let value as Bool:
            value ? "true" : "false"
        case let value as NSNumber:
            value.stringValue
        case let value as String:
            value
        default:
            ""
        }
    }
}

private struct PaletteFixture {
    let name: String
    let colors: [RGBColor]
}

private struct TerminalProfileSnapshot: Codable, Equatable {
    let colors: [String: String]
    let settings: [String: String]

    func encodedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return String(decoding: try encoder.encode(self), as: UTF8.self) + "\n"
    }
}

private struct TemporaryWorkspace {
    let root: URL
    let appSupport: URL
    let environment: RuntimeEnvironment

    init(extraEnvironment: [String: String] = [:]) throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("macwal-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        appSupport = root.appendingPathComponent("Library/Application Support/macwal", isDirectory: true)
        var env = ProcessInfo.processInfo.environment
        env["HOME"] = root.path
        env["MACWAL_HOME"] = root.path
        env["MACWAL_DEFAULTS_STORE"] = root.appendingPathComponent("Library/Application Support/macwal/test-defaults", isDirectory: true).path
        // Never touch the real machine from tests: no app restarts/signals, no
        // launchd (un)load, and no desktop wallpaper changes.
        env["MACWAL_SKIP_RESTART"] = "1"
        env["MACWAL_SKIP_LAUNCHCTL"] = "1"
        env["MACWAL_SKIP_WALLPAPER"] = "1"
        for (key, value) in extraEnvironment {
            env[key] = value
        }
        environment = RuntimeEnvironment(
            homeDirectory: root,
            currentDirectory: root,
            environment: env
        )
    }

    func writePNG(named name: String, colors: [RGBColor]) throws -> URL {
        let url = root.appendingPathComponent(name)
        let width = 48
        let height = 48
        var bytes = [UInt8](repeating: 255, count: width * height * 4)

        for y in 0..<height {
            for x in 0..<width {
                let color = colors[(x + y) % colors.count]
                let index = (y * width + x) * 4
                bytes[index] = color.red
                bytes[index + 1] = color.green
                bytes[index + 2] = color.blue
                bytes[index + 3] = 255
            }
        }

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let image = bytes.withUnsafeMutableBytes { rawBuffer -> CGImage? in
            guard let context = CGContext(
                data: rawBuffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return nil
            }
            return context.makeImage()
        }

        guard let image,
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw MacwalError.paletteGenerationFailed("Could not create PNG fixture.")
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw MacwalError.paletteGenerationFailed("Could not write PNG fixture.")
        }

        return url
    }

    func writeConfig(_ config: MacwalConfig) throws {
        try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: appSupport.appendingPathComponent("config.json"))
    }

    func writeExecutable(named name: String, contents: String) throws -> URL {
        let bin = root.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let executable = bin.appendingPathComponent(name)
        try contents.data(using: .utf8)?.write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        return executable
    }
}

private func readFinderTags(from url: URL) throws -> [String] {
    let name = "com.apple.metadata:_kMDItemUserTags"
    let size = getxattr(url.path, name, nil, 0, 0, 0)
    if size < 0 {
        if errno == ENOATTR {
            return []
        }
        throw MacwalError.adapterFailed("Could not read test xattr: errno \(errno)")
    }

    var data = Data(count: size)
    let readSize = data.withUnsafeMutableBytes { buffer in
        getxattr(url.path, name, buffer.baseAddress, size, 0, 0)
    }
    if readSize < 0 {
        throw MacwalError.adapterFailed("Could not read test xattr: errno \(errno)")
    }
    return try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String] ?? []
}
