# macwal Implementation Plan

## Objective

Build `macwal`, a macOS command-line tool inspired by `pywal`, that reads the user's current wallpaper or an explicit image file, extracts a usable color palette, and applies that palette across supported macOS and app-level appearance surfaces.

The tool must be honest about macOS limitations. Every target adapter must be classified as one of:

- `supported`: Uses a public API or a documented app configuration surface.
- `private`: Uses undocumented macOS preferences, notifications, extended attributes, or UI scripting.
- `external`: Requires a third-party tool or app-specific extension system.
- `manual`: Generates assets/configuration, but the user must install or enable them manually.

The product goal is not to disable SIP, patch sealed system files, modify Apple app bundles, or replace protected OS assets. Those are non-goals.

## Project Name

- CLI binary: `macwal`
- Swift package: `Macwal`
- Bundle/launch identifier prefix: `io.macwal`
- Project directory: `/Users/damadimo/projects/macwal`

## Baseline Platform

- Core target: macOS 15 Sequoia and newer.
- Enhanced target: macOS 26 Tahoe and newer for icon, widget, folder, and Liquid Glass related appearance options.
- Architecture: Apple Silicon and Intel macOS, unless a dependency proves otherwise.
- Implementation language: Swift.
- Build system: Swift Package Manager.

## Key Constraints

1. `macwal` must never require SIP to be disabled.
2. `macwal` must never write into `/System`, `/Applications/*.app`, or sealed system volumes.
3. `macwal` must not modify protected app bundles directly.
4. `macwal` must back up every preference file, generated file, or app config it modifies before first modification.
5. `macwal restore` must be implemented before any adapter that writes persistent user configuration is considered complete.
6. Any adapter using private macOS behavior must require `--allow-private` unless the command is a dry run.
7. Any adapter requiring an external tool must fail with an actionable message if the tool is missing.
8. All generated palettes must pass contrast checks before being applied.
9. The CLI must support `--dry-run` for every write-capable command.
10. The CLI must produce machine-readable JSON output with `--json`.

## Research Summary

### Reliable System-Level Surfaces

- Wallpaper can be read per screen with AppKit `NSWorkspace.desktopImageURL(for:)`.
- Wallpaper can be set per screen with AppKit `NSWorkspace.setDesktopImageURL(_:for:options:)`.
- There is no public API to set desktop images across all Spaces for a screen.
- Current accent color can be read through `NSColor.controlAccentColor`.
- System color changes can be observed through `NSColor.systemColorsDidChangeNotification`.
- Appearance settings expose user-facing controls for light/dark mode, system color, text highlight color, icon and widget style, folder color, and wallpaper tinting.

### Private or Fragile macOS Surfaces

- System accent/theme color and text highlight color can be manipulated through global defaults such as `AppleAccentColor` and `AppleHighlightColor`, but this is undocumented.
- Applying accent color immediately may require posting CoreUI-related distributed notifications and/or restarting affected apps.
- Per-app accent overrides can be written to an app preference domain with `AppleAccentColor`, but this is undocumented.
- Tahoe folder customization can be affected through extended attributes such as `com.apple.icon.folder#S`, but this is undocumented and must remain opt-in.

### App-Level Surfaces

- Terminal.app profiles are configurable and can represent background, foreground, cursor, selection, and ANSI colors.
- Obsidian supports CSS snippets in each vault's `.obsidian/snippets` folder and applies changes after snippets are enabled.
- Chrome supports theme extensions using a Manifest V3 `theme` manifest.
- Safari does not expose a practical browser chrome theming API comparable to Chrome themes. Safari mostly follows system appearance and website `theme-color` behavior.
- Spotify does not officially expose desktop themes. Spicetify can theme Spotify through its CLI and theme files, so Spotify support must be classified as `external`.

## Primary Commands

The first stable CLI must expose these commands exactly:

```bash
macwal palette [--image PATH] [--screen INDEX] [--json]
macwal preview [--image PATH] [--targets TARGETS] [--json]
macwal apply [--image PATH] [--targets TARGETS] [--allow-private] [--dry-run] [--json]
macwal restore [--targets TARGETS] [--dry-run] [--json]
macwal watch install [--targets TARGETS] [--allow-private]
macwal watch uninstall
macwal doctor [--json]
macwal list-targets [--json]
```

`TARGETS` must be a comma-separated list from this set:

```text
system,terminal,shell,obsidian,chrome,firefox,librewolf,zen,floorp,safari,spotify,
alacritty,kitty,wezterm,ghostty,iterm2,vscode,zed,vim,neovim,tmux,starship,bat,
btop,yazi,fzf,lazygit,aerospace,yabai,sketchybar,janky-borders,hammerspoon,
raycast,alfred,discord,thunderbird,telegram,slack,finder
```

`all` must expand to every adapter whose prerequisites are available, excluding `private` adapters unless `--allow-private` is present.

## Target Classification Matrix

| Target | Classification | Default Enabled | Requires `--allow-private` | Requires External Tool | Notes |
| --- | --- | --- | --- | --- | --- |
| `shell` | supported | yes | no | no | Writes generated shell/theme files under app support only. |
| `terminal` | supported/private mixed | yes | no | no | Generates and installs a `.terminal` profile as the default profile, with backup and restore. |
| `obsidian` | supported app config | yes when vaults found | no | no | Writes CSS snippet files and enables the generated snippet in `appearance.json`. |
| `chrome` | manual | yes | no | no | Generates MV3 theme folder. Chrome has no supported per-user silent activation API for unpacked themes. |
| `firefox`, `librewolf`, `zen`, `floorp`, `thunderbird` | supported app config | no | no | no | Writes profile chrome CSS and `user.js`; restart required. |
| `spotify` | external | no | no | `spicetify` | Writes Spicetify theme and runs `spicetify apply`. |
| `alacritty`, `kitty`, `wezterm`, `ghostty`, `iterm2` | supported / supported app config | no | no | optional app CLIs | Writes terminal color configs; reloads where a stable command exists. |
| `vscode`, `zed`, `vim`, `neovim` | supported / supported app config | no | no | no | Writes editor theme files and managed config imports where safe. |
| `tmux`, `starship`, `bat`, `btop`, `yazi`, `fzf`, `lazygit` | supported / supported app config | no | no | optional app CLIs | Writes TUI/CLI theme files and imports where safe. |
| `aerospace`, `yabai`, `sketchybar`, `janky-borders`, `hammerspoon` | supported / external | no | no | optional app CLIs | Writes desktop-tool color fragments and runs available runtime commands. |
| `raycast`, `alfred`, `discord`, `telegram`, `slack` | manual | no | no | no | Generates palette assets or mod-client CSS where silent activation is not stable. |
| `safari` | supported system inheritance only | no | no | no | No direct Safari chrome theming. Reports inherited system effects. |
| `system` | private | no | yes | no | Writes accent/highlight/light-dark preferences and posts notifications. |
| `finder` | private | no | yes | no | Tahoe folder defaults and selected folder xattrs only. |

## Data Model

### Palette JSON

Every palette generation must produce a JSON document matching this shape:

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-07-03T00:00:00Z",
  "source": {
    "kind": "wallpaper",
    "path": "/absolute/path/to/image.jpg",
    "screenIndex": 0,
    "displayID": 1
  },
  "appearance": {
    "recommendedMode": "dark",
    "wallpaperLuminance": 0.25,
    "contrastValidated": true
  },
  "colors": {
    "background": "#101214",
    "foreground": "#F4F1EA",
    "cursor": "#F4F1EA",
    "selection": "#3D5A66",
    "accent": "#7FB7BE",
    "accentAlt": "#C99768",
    "black": "#101214",
    "red": "#D95F5F",
    "green": "#7AA874",
    "yellow": "#D9B45F",
    "blue": "#6A9FD8",
    "magenta": "#B982C9",
    "cyan": "#7FB7BE",
    "white": "#F4F1EA",
    "brightBlack": "#4B5358",
    "brightRed": "#EF7777",
    "brightGreen": "#94C58C",
    "brightYellow": "#E9C978",
    "brightBlue": "#83B7EA",
    "brightMagenta": "#CFA0DE",
    "brightCyan": "#99D4D9",
    "brightWhite": "#FFFFFF"
  }
}
```

### Contrast Rules

Palette generation must enforce these minimum contrast ratios:

- `foreground` on `background`: at least 7.0:1.
- `selection` on `foreground`: at least 3.0:1 when used as selected text background.
- `accent` on `background`: at least 3.0:1.
- `brightWhite` on `background`: at least 7.0:1.
- ANSI colors on `background`: at least 2.0:1, except `black` and `brightBlack`.

If extracted colors fail, the palette engine must adjust lightness and saturation in a deterministic way and mark `contrastValidated` as `true` only after passing.

## File Layout

The final repository must use this structure:

```text
macwal/
  IMPLEMENTATION_PLAN.md
  README.md
  Package.swift
  Sources/
    MacwalCLI/
      main.swift
      Commands/
      Output/
    MacwalCore/
      Palette/
      Wallpaper/
      Config/
      Backup/
      Adapters/
      Watch/
  Tests/
    MacwalCoreTests/
      Fixtures/
  docs/
    adapters/
  scripts/
```

Generated user data must be stored under:

```text
~/Library/Application Support/macwal/
  config.json
  palettes/
  generated/
  backups/
  logs/
```

Temporary files must be stored under:

```text
~/Library/Caches/macwal/
```

The watcher LaunchAgent must be:

```text
~/Library/LaunchAgents/io.macwal.watch.plist
```

## Configuration File

`~/Library/Application Support/macwal/config.json` must use this shape:

```json
{
  "schemaVersion": 1,
  "defaultTargets": ["shell", "terminal", "obsidian", "chrome"],
  "allowPrivateByDefault": false,
  "palette": {
    "mode": "auto",
    "minimumForegroundContrast": 7.0,
    "minimumAccentContrast": 3.0
  },
  "adapters": {
    "terminal": {
      "profileName": "macwal",
      "setAsDefault": true
    },
    "obsidian": {
      "vaults": []
    },
    "chrome": {
      "profiles": []
    },
    "spotify": {
      "enabled": false,
      "spicetifyPath": "spicetify"
    },
    "system": {
      "setAppearanceMode": false,
      "setAccentColor": false,
      "setHighlightColor": false
    },
    "finder": {
      "setFolderTint": false,
      "folders": []
    }
  }
}
```

If `config.json` is missing, `macwal` must create it with defaults when a command needs configuration.

## Milestone 0: Repository Scaffold

### Work

1. Create `Package.swift` with two products:
   - executable product `macwal`
   - library product `MacwalCore`
2. Create empty module directories.
3. Add `README.md` with project objective, safety model, and current adapter matrix.
4. Add a basic CLI entry point that prints help and exits successfully.
5. Add initial unit test target.

### Acceptance Criteria

- `swift build` exits with status `0`.
- `swift test` exits with status `0`.
- `.build/debug/macwal --help` exits with status `0`.
- `.build/debug/macwal --help` lists every primary command named in this plan.
- `README.md` includes the four adapter classifications exactly: `supported`, `private`, `external`, `manual`.
- No command writes outside `/Users/damadimo/projects/macwal` during this milestone.

## Milestone 1: CLI Contract and Output Layer

### Work

1. Implement command parsing for all primary commands.
2. Implement target parsing for comma-separated targets and `all`.
3. Implement a shared result model for text and JSON output.
4. Implement consistent error codes:
   - `0`: success
   - `1`: invalid arguments
   - `2`: missing prerequisite
   - `3`: permission denied
   - `4`: adapter failed
   - `5`: palette generation failed
   - `6`: restore failed
5. Implement `--dry-run` plumbing for `apply` and `restore`.
6. Implement `--json` for `palette`, `preview`, `apply`, `restore`, `doctor`, and `list-targets`.

### Acceptance Criteria

- `macwal list-targets --json` returns valid JSON.
- `macwal list-targets --json` includes every target listed in the target classification matrix.
- Passing an unknown target such as `macwal apply --targets nope` exits with status `1`.
- Passing `--allow-private` to a command that does not use private adapters is accepted and reported in JSON metadata.
- `macwal apply --targets system --dry-run` does not write any file or preference.
- All JSON outputs include `schemaVersion`, `command`, `success`, and `messages`.

## Milestone 2: Configuration and Filesystem Safety

### Work

1. Implement app support path resolution.
2. Implement cache path resolution.
3. Implement `config.json` load, validation, default creation, and schema migration placeholder.
4. Implement atomic file writes using temporary files and rename.
5. Implement a filesystem guard that prevents writes outside allowed locations unless an adapter explicitly declares the path.
6. Implement backup path naming.

### Acceptance Criteria

- Running `macwal doctor` creates `~/Library/Application Support/macwal/config.json` if it does not exist.
- Created `config.json` validates against the schema in this plan.
- Atomic writes leave no partial file when a simulated write error is injected in tests.
- Unit tests prove that paths outside declared write roots are rejected.
- Every write operation logs the target path in dry-run mode without modifying it.
- `macwal doctor --json` reports app support, cache, and launch agent paths as absolute paths.

## Milestone 3: Wallpaper Reader

### Work

1. Implement `WallpaperProvider`.
2. Read wallpaper URL for each `NSScreen` using `NSWorkspace.desktopImageURL(for:)`.
3. Support `--screen INDEX`.
4. Support explicit `--image PATH`.
5. Resolve symlinks and validate that image paths exist.
6. Record source metadata in the palette JSON.

### Acceptance Criteria

- `macwal palette --image Tests/MacwalCoreTests/Fixtures/wallpaper.jpg --json` uses the explicit image path and does not call the wallpaper provider.
- `macwal palette --screen 0 --json` reports `source.kind` as `wallpaper` when a desktop image URL exists.
- Passing a nonexistent image path exits with status `5`.
- Passing a screen index outside available screens exits with status `1`.
- Unit tests cover explicit image path, missing image path, and mocked wallpaper source.
- The wallpaper reader does not attempt to change the wallpaper in this milestone.

## Milestone 4: Palette Extraction Engine

### Work

1. Load image files using ImageIO/CoreGraphics.
2. Downsample large images to a deterministic analysis size.
3. Extract candidate colors with a deterministic quantization algorithm.
4. Score candidate colors by saturation, frequency, contrast, and luminance.
5. Generate dark and light palettes.
6. Choose recommended mode from wallpaper luminance unless overridden by config.
7. Generate 16 ANSI colors.
8. Implement WCAG contrast calculation.
9. Implement deterministic color repair for failed contrast.

### Acceptance Criteria

- Same image and same config produce byte-for-byte identical palette JSON, excluding `generatedAt`.
- `foreground` on `background` contrast is at least 7.0:1 for every fixture.
- `accent` on `background` contrast is at least 3.0:1 for every fixture.
- ANSI palette contains exactly 16 named ANSI colors.
- Unit tests include at least five fixtures:
  - dark low-saturation wallpaper
  - bright low-saturation wallpaper
  - high-saturation wallpaper
  - mostly red wallpaper
  - mostly blue/green wallpaper
- Each fixture has a checked-in expected palette snapshot.
- `macwal palette --json` outputs the exact Palette JSON shape defined in this plan.

## Milestone 5: Preview Renderer

### Work

1. Implement terminal preview output with color blocks and ANSI labels.
2. Implement JSON preview output that includes adapter plans.
3. Add `macwal preview --targets TARGETS`.
4. Preview must show which adapters will write, which cannot be silently activated, which require `--allow-private`, and which are unavailable.

### Acceptance Criteria

- `macwal preview --image FIXTURE --targets shell,terminal --json` includes a `plannedWrites` array for each target.
- `macwal preview --targets system --json` marks `system` as `blocked` unless `--allow-private` is supplied.
- `macwal preview --targets spotify --json` marks `spotify` as `unavailable` when `spicetify` is not found.
- Text preview includes at least background, foreground, accent, selection, and all 16 ANSI colors.
- Preview never writes files or preferences.

## Milestone 6: Backup and Restore Core

### Work

1. Implement a backup registry in `~/Library/Application Support/macwal/backups/index.json`.
2. Every adapter write must register:
   - adapter name
   - original path or preference domain/key
   - backup artifact path
   - timestamp
   - command invocation ID
3. Implement file backup.
4. Implement preference backup abstraction.
5. Implement restore plan preview.
6. Implement idempotent restore behavior.

### Acceptance Criteria

- `macwal restore --dry-run --json` reports what would be restored without writing anything.
- Restoring twice produces success both times and does not corrupt files.
- Backup index survives process interruption in tests.
- If a file did not exist before `macwal` created it, restore deletes that file.
- If a file existed before `macwal` changed it, restore returns the original bytes.
- No adapter is allowed to write until it calls the backup API in tests.

## Milestone 7: Shell Adapter

### Work

1. Generate shell exports for POSIX shells.
2. Generate JSON, CSS, and Xresources-compatible files.
3. Store generated files under:

```text
~/Library/Application Support/macwal/generated/shell/
```

4. Emit:
   - `colors.sh`
   - `colors.json`
   - `colors.css`
   - `colors.Xresources`

### Acceptance Criteria

- `macwal apply --targets shell --image FIXTURE` writes all four files.
- `colors.sh` exports every color as `MACWAL_COLOR_<NAME>`.
- `colors.css` defines every color as `--macwal-color-<name>`.
- `colors.json` matches the Palette JSON `colors` object.
- `macwal restore --targets shell` removes generated files if they did not exist before.
- No external tools are required.

## Milestone 8: Terminal.app Adapter

### Work

1. Generate a `.terminal` profile named `macwal.terminal`.
2. Include background, foreground, cursor, selection, and ANSI colors.
3. Store generated profile under:

```text
~/Library/Application Support/macwal/generated/terminal/macwal.terminal
```

4. Implement direct install into Terminal preferences only after backup.
5. Implement optional `setAsDefault` so users can disable direct preference mutation.
6. Keep generated `.terminal` profile output available for inspection and restore.

### Acceptance Criteria

- `macwal apply --targets terminal --dry-run --json` lists the `.terminal` profile path and Terminal defaults keys when `setAsDefault` is true.
- `macwal apply --targets terminal --image FIXTURE` writes `macwal.terminal` and installs it as the default Terminal profile when `setAsDefault` is true.
- The generated `.terminal` profile can be opened by Terminal.app without XML/plist parse errors.
- The profile contains all 16 ANSI colors.
- Direct preference mutation is not performed when `setAsDefault` is false.
- If direct mutation is enabled, original `com.apple.Terminal` preferences are backed up before writing.
- `macwal restore --targets terminal` restores the previous Terminal preferences or removes generated profile artifacts, depending on what was changed.

## Milestone 9: Obsidian Adapter

### Work

1. Discover vaults from user config.
2. If no vaults are configured, detect common vault locations only for preview and doctor output; do not guess-write.
3. Write `macwal.css` to each configured vault:

```text
<vault>/.obsidian/snippets/macwal.css
<vault>/.obsidian/appearance.json
```

4. Generate CSS variables and common Obsidian variables:
   - `--background-primary`
   - `--background-secondary`
   - `--text-normal`
   - `--text-muted`
   - `--text-accent`
   - `--interactive-accent`
   - `--h1-color` through `--h6-color`
5. Enable the generated snippet by updating `enabledCssSnippets` in `appearance.json`.
6. Do not edit Obsidian plugin files or app bundle files.

### Acceptance Criteria

- `macwal doctor --json` reports configured vaults and whether each vault has `.obsidian`.
- `macwal apply --targets obsidian` writes only to configured vaults.
- If no vaults are configured, `macwal apply --targets obsidian` exits with status `2` and explains how to configure vault paths.
- `macwal.css` is valid CSS.
- `appearance.json` contains `macwal` in `enabledCssSnippets` after apply.
- Existing `macwal.css` is backed up before overwrite.
- Existing `appearance.json` is backed up before overwrite.
- Restore returns each vault's `macwal.css` and `appearance.json` to their previous states.

## Milestone 10: Chrome Adapter

### Work

1. Generate a Manifest V3 Chrome theme directory:

```text
~/Library/Application Support/macwal/generated/chrome/macwal-theme/
  manifest.json
  images/
```

2. Manifest must include:
   - `manifest_version: 3`
   - `name: "macwal"`
   - `version`
   - `theme.colors.frame`
   - `theme.colors.toolbar`
   - `theme.colors.tab_text`
   - `theme.colors.bookmark_text`
   - `theme.colors.ntp_background`
   - `theme.colors.ntp_text`
   - `theme.colors.button_background`
3. Generate a README inside the theme folder explaining how to load it through `chrome://extensions`.
4. Do not edit Chrome profile preferences in the first implementation.

### Acceptance Criteria

- `manifest.json` is valid JSON.
- `manifest.json` uses RGB arrays for Chrome theme colors.
- `macwal preview --targets chrome --json` reports the extension folder and marks install as `manual`.
- `macwal apply --targets chrome` writes or updates the theme folder only.
- The generated folder can be loaded as an unpacked Chrome extension.
- Restore removes generated Chrome files if they were created by `macwal`.
- No Chrome profile preferences are modified.

## Milestone 11: Safari Adapter

### Work

1. Implement Safari as an informational adapter.
2. Report that Safari follows system appearance and does not have a Chrome-style theme target.
3. Optionally generate a content CSS snippet only if a future explicit feature is added; do not include it in the MVP.

### Acceptance Criteria

- `macwal list-targets --json` marks Safari as `supported system inheritance only`.
- `macwal apply --targets safari` performs no writes.
- `macwal apply --targets safari --json` returns success with a message explaining that Safari inherits system appearance only.
- Safari adapter never requires `--allow-private`.
- Safari adapter never modifies Safari preferences, extension files, or website data in the MVP.

## Milestone 12: Spotify Adapter Through Spicetify

### Work

1. Detect `spicetify` with configured path or `PATH` lookup.
2. Generate Spicetify theme:

```text
~/.config/spicetify/Themes/macwal/
  color.ini
  user.css
```

3. Set current Spicetify theme to `macwal`.
4. Run `spicetify apply` unless `--dry-run`.
5. Capture command output for logs.
6. Do not install Spicetify automatically.

### Acceptance Criteria

- If `spicetify` is missing, `macwal apply --targets spotify` exits with status `2`.
- Missing `spicetify` error includes an install instruction summary and does not open a browser.
- `color.ini` includes at least `text`, `subtext`, `main`, `sidebar`, `player`, `card`, `shadow`, `selected-row`, `button`, `button-active`, `button-disabled`, and `tab-active`.
- `user.css` is valid CSS.
- `macwal apply --targets spotify --dry-run --json` lists every command that would be run.
- Actual apply runs `spicetify config current_theme macwal` and `spicetify apply`.
- Restore restores previous Spicetify theme settings if they were backed up.

## Milestone 13: System Appearance Adapter

### Work

This adapter is private and must be disabled unless `--allow-private` is present.

1. Read current system appearance state.
2. Implement optional light/dark mode setting.
3. Implement optional accent/theme color setting by mapping extracted accent to nearest available macOS color:
   - blue
   - purple
   - pink
   - red
   - orange
   - yellow
   - green
   - graphite
4. Implement optional text highlight color using custom RGB string where supported.
5. Post relevant notifications after preference writes.
6. On macOS 26+, prefer documented system-color change observation in internal code where possible.
7. Never kill user apps by default.

### Acceptance Criteria

- `macwal apply --targets system` without `--allow-private` exits with status `3` and performs no writes.
- `macwal apply --targets system --allow-private --dry-run --json` lists exact preference domains and keys it would write.
- Before any actual system write, original values are backed up.
- Accent mapping is deterministic and unit-tested for the supported macOS accent palette.
- If setting a color fails, the adapter reports failure and does not continue to later system writes.
- `macwal restore --targets system --allow-private` restores original preference values.
- No app processes are killed unless a future explicit `--restart-apps` flag is implemented.

## Milestone 14: Finder and Tahoe Folder Adapter

### Work

This adapter is private and must be disabled unless `--allow-private` is present.

1. Detect macOS major version.
2. On macOS versions earlier than 26, report that Tahoe folder features are unavailable.
3. Support configured folder paths only; do not recursively modify folders by default.
4. For configured folders, optionally write Tahoe folder customization extended attributes.
5. Support clearing the attributes during restore.
6. Keep default Finder/system folder color as a future experiment until a stable preference key is proven.

### Acceptance Criteria

- `macwal apply --targets finder` without `--allow-private` exits with status `3`.
- On macOS earlier than 26, `macwal apply --targets finder --allow-private` exits with status `2` and performs no writes.
- The adapter writes only to explicitly configured folder paths.
- The adapter refuses to modify `/System`, `/Applications`, `/Library`, and `/Users` root folders.
- Extended attributes are backed up before modification.
- Restore returns the exact previous extended attribute state.
- The adapter never modifies arbitrary files inside configured folders.

## Milestone 15: Watcher

### Work

1. Implement `macwal watch install`.
2. Create a LaunchAgent plist at `~/Library/LaunchAgents/io.macwal.watch.plist`.
3. Watcher mode must run periodically and compare current wallpaper source and file metadata to last applied state.
4. If wallpaper changed, run `macwal apply` with configured targets.
5. Implement `macwal watch uninstall`.
6. Write logs to:

```text
~/Library/Application Support/macwal/logs/watch.log
```

### Acceptance Criteria

- `macwal watch install --targets shell,terminal` writes a valid plist.
- The plist references the absolute path to the installed `macwal` binary.
- `launchctl plist` validation or equivalent plist parse test passes.
- `macwal watch uninstall` unloads and deletes the plist if it exists.
- Watcher does not apply private adapters unless the installed command included `--allow-private`.
- Watcher logs every apply attempt with timestamp, target list, and result.
- Repeated watcher runs without wallpaper changes perform no adapter writes.

## Milestone 16: Doctor and Diagnostics

### Work

1. Implement full environment checks:
   - macOS version
   - app support path writable
   - cache path writable
   - configured vault paths
   - Terminal preference accessibility
   - Chrome app/profile presence
   - Spicetify availability
   - LaunchAgent installed state
   - private adapters disabled/enabled
2. Provide remediation messages.
3. Add `--json` diagnostics.

### Acceptance Criteria

- `macwal doctor` exits with status `0` if core shell target can run.
- `macwal doctor --json` includes one diagnostic record per target.
- Missing optional app targets do not cause `doctor` to fail.
- Missing app support write permission causes `doctor` to exit with status `3`.
- Every failed diagnostic includes a remediation string.
- `doctor` does not write anything except creating default app support/config paths if missing.

## Milestone 17: Integration Tests

### Work

1. Add integration test fixtures for all generated artifacts.
2. Use temporary home directories in tests where possible.
3. Mock OS APIs where direct macOS state would be unsafe.
4. Add snapshot tests for:
   - palette JSON
   - shell files
   - terminal profile plist
   - Obsidian CSS
   - Chrome manifest
   - Spicetify color.ini
5. Add dry-run tests for private adapters.

### Acceptance Criteria

- `swift test` does not modify the real user's home directory.
- All generated file snapshots are deterministic.
- Private adapter tests prove no writes occur without `--allow-private`.
- Restore tests cover file existed, file absent, preference existed, and preference absent cases.
- Tests can be run repeatedly without cleanup failures.

## Milestone 18: Documentation

### Work

1. Write `README.md` with:
   - installation
   - quick start
   - safety model
   - target matrix
   - examples
   - restore instructions
2. Write one adapter doc per target under `docs/adapters/`.
3. Document private adapter risks.
4. Document manual Chrome loading.
5. Document automatic Obsidian snippet enabling.
6. Document Spicetify requirement.

### Acceptance Criteria

- README has a "Safety" section.
- README has a "Restore" section with exact command `macwal restore`.
- Each target has a dedicated doc file.
- Private adapters are clearly labeled as undocumented and opt-in.
- Documentation never claims Safari chrome can be directly themed.
- Documentation never claims Dock/menu bar system icons can be directly recolored.

## Milestone 19: Packaging

### Work

1. Add release build instructions.
2. Add Homebrew formula draft.
3. Add signed/notarized packaging plan if distributing binaries.
4. Add uninstall instructions.
5. Add shell completion generation if supported by the CLI parser.

### Acceptance Criteria

- `swift build -c release` succeeds.
- Release binary runs `macwal --help`.
- Homebrew formula installs the release binary in a test tap or local formula path.
- Uninstall instructions remove:
  - binary
  - LaunchAgent
  - app support data, only if user chooses
  - generated app files, only through `macwal restore`
- Packaging docs state that private adapters remain opt-in after installation.

## Final MVP Definition of Done

The MVP is complete only when all of these are true:

1. `swift build -c release` succeeds.
2. `swift test` succeeds.
3. `macwal palette --image FIXTURE --json` emits valid Palette JSON.
4. `macwal preview --image FIXTURE --targets all --json` emits valid JSON.
5. `macwal apply --image FIXTURE --targets shell,terminal,obsidian,chrome --dry-run --json` performs no writes.
6. `macwal apply --image FIXTURE --targets shell,terminal,chrome` writes generated artifacts.
7. `macwal restore --targets shell,terminal,chrome` restores or removes generated artifacts correctly.
8. `macwal apply --targets system` refuses to run without `--allow-private`.
9. `macwal apply --targets finder` refuses to run without `--allow-private`.
10. `macwal doctor --json` reports all target statuses.
11. Documentation explains every unsupported or partial target honestly.
12. No implementation path requires SIP disabling.

## Explicit Non-Goals

- No SIP disabling.
- No patching macOS system files.
- No patching app bundles in `/Applications`.
- No automatic installation of Spicetify.
- No automatic loading of Chrome unpacked extensions through UI scripting or enterprise policy in the default adapter.
- No direct Safari browser chrome theming.
- No direct Dock background/icon recoloring beyond system-inherited appearance.
- No direct menu bar status glyph recoloring.
- No recursive folder customization by default.

## Future Work After MVP

1. iTerm2 adapter.
2. Alacritty adapter.
3. Ghostty adapter.
4. WezTerm adapter.
5. VS Code adapter.
6. Neovim theme export.
7. Raycast extension.
8. Better Tahoe icon/widget/folder color research.
9. Optional Chrome enterprise policy adapter.
10. Menubar app wrapper for preview and quick restore.
11. Live wallpaper change detection using more specific macOS notifications if reliable.
12. Theme gallery export.

## Source References

- Apple Support, Appearance settings: https://support.apple.com/guide/mac-help/change-appearance-settings-mchlp1225/mac
- Apple Support, wallpaper settings: https://support.apple.com/guide/mac-help/choose-your-desktop-picture-mchlp3013/mac
- Apple Support, Terminal profiles: https://support.apple.com/guide/terminal/profiles-change-terminal-windows-trml107/mac
- Apple Developer, `NSWorkspace.desktopImageURL(for:)`: https://developer.apple.com/documentation/appkit/nsworkspace/desktopimageurl%28for%3A%29
- Apple Developer, `NSWorkspace.setDesktopImageURL(_:for:options:)`: https://developer.apple.com/documentation/appkit/nsworkspace/setdesktopimageurl%28_%3Afor%3Aoptions%3A%29
- Apple Developer, `NSColor.controlAccentColor`: https://developer.apple.com/documentation/appkit/nscolor/controlaccentcolor
- Apple Developer, `NSColor.systemColorsDidChangeNotification`: https://developer.apple.com/documentation/appkit/nscolor/systemcolorsdidchangenotification
- Apple Developer Forums, no API for all-Spaces wallpaper setting: https://developer.apple.com/forums/thread/834630
- Alex Chan, changing macOS accent color without System Preferences: https://alexwlchan.net/2022/changing-the-macos-accent-colour/
- Chrome theme extensions: https://developer.chrome.com/docs/extensions/develop/ui/themes
- Obsidian CSS snippets: https://obsidian.md/help/snippets
- Spicetify CLI: https://github.com/spicetify/cli
- Spicetify theme docs: https://spicetify.app/docs/development/themes
