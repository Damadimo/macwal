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
        #expect(names == ["system", "terminal", "shell", "obsidian", "chrome", "safari", "spotify", "finder"])
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

        _ = try TerminalAdapter(paths: paths, fileSystem: fileSystem).apply(palette: palette, dryRun: false)

        let profile = paths.generated.appendingPathComponent("terminal/macwal.terminal")
        #expect(try terminalProfileSnapshot(at: profile).encodedJSON() == snapshot(named: "terminal-profile-summary.json"))
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
        let spotifyINI = paths.home.appendingPathComponent(".config/spicetify/Themes/macwal/color.ini")

        #expect(try String(contentsOf: obsidianCSS, encoding: .utf8) == snapshot(named: "obsidian-macwal.css"))
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
        #expect(targets.count == 8)
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
    @Test func terminalSetAsDefaultRequiresAllowPrivateForApply() throws {
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

        #expect(result.exitCode == 3)
        let data = try #require(result.stdout.data(using: .utf8))
        let response = try JSONDecoder().decode(CommandResponse.self, from: data)
        #expect(!response.success)
        let terminalProfile = temp.appSupport.appendingPathComponent("generated/terminal/macwal.terminal")
        #expect(!FileManager.default.fileExists(atPath: terminalProfile.path))
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
        let css = try String(contentsOf: snippet, encoding: .utf8)
        #expect(css.contains("--background-primary"))
        #expect(css.contains("Enable this snippet once"))

        let restore = runner.run(arguments: [
            "restore",
            "--targets", "obsidian"
        ])

        #expect(restore.exitCode == 0)
        #expect(!FileManager.default.fileExists(atPath: snippet.path))
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

    private var ansiKeys: [String] {
        [
            "black", "red", "green", "yellow", "blue", "magenta", "cyan", "white",
            "brightBlack", "brightRed", "brightGreen", "brightYellow", "brightBlue",
            "brightMagenta", "brightCyan", "brightWhite"
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
