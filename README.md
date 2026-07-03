# macwal

`macwal` is a macOS command-line theming tool inspired by `pywal`.
It reads the current wallpaper or an explicit image, extracts a pywal-style contrast-safe palette, and applies generated theme assets to supported macOS and app-level surfaces.

## Safety

Every target is classified before it can write anything:

- `supported`: Uses a public API or documented app configuration surface.
- `supported app config`: Writes documented or conventional per-app config files.
- `supported/private mixed`: Writes generated files plus restorable user preferences.
- `supported system inheritance only`: Performs no direct app write because the app follows macOS appearance.
- `private`: Uses undocumented macOS preferences, notifications, extended attributes, or UI scripting.
- `external`: Requires a third-party tool or app-specific extension system.
- `manual`: Generates assets/configuration that the user must install or enable manually.

`macwal` does not disable SIP, patch sealed system files, modify Apple app bundles, or replace protected OS assets.

## Install From Source

```bash
swift build -c release
install -m 0755 .build/release/macwal /usr/local/bin/macwal
```

For development:

```bash
swift build
.build/debug/macwal --help
```

## Target Matrix

| Target | Classification | Status |
| --- | --- | --- |
| `shell` | supported | Generates shell, JSON, CSS, and Xresources files. |
| `terminal` | supported/private mixed | Generates and installs a `.terminal` profile as the default Terminal profile. |
| `obsidian` | supported app config | Writes and enables CSS snippets in configured vaults. |
| `chrome` | manual | Generates a Manifest V3 theme folder for manual loading. |
| `firefox`, `librewolf`, `zen`, `floorp` | supported app config | Writes profile `userChrome.css`, `userContent.css`, and `user.js`; browser restart required. |
| `spotify` | external | Generates and applies a Spicetify theme. |
| `alacritty`, `kitty`, `wezterm`, `ghostty`, `iterm2` | supported / supported app config | Writes terminal color configuration; Kitty attempts live reload when available. |
| `vscode`, `zed`, `vim`, `neovim` | supported / supported app config | Writes editor themes and enables them where a stable config file exists. |
| `tmux`, `starship`, `bat`, `btop`, `yazi`, `fzf`, `lazygit` | supported / supported app config | Writes common TUI/CLI theme files and imports them when safe. |
| `aerospace`, `yabai`, `sketchybar`, `janky-borders`, `hammerspoon` | supported / external | Writes macOS tool color configs; runs available CLI reload/config commands for supported tools. |
| `raycast`, `alfred`, `discord`, `telegram`, `slack` | manual | Generates palette/theme assets where stable automatic activation is unavailable. |
| `thunderbird` | supported app config | Writes Thunderbird profile chrome CSS and `user.js`; restart required. |
| `safari` | supported system inheritance only | Informational no-op; Safari follows system appearance. |
| `system` | private | Optionally writes global macOS appearance preferences. Requires `--allow-private`. |
| `finder` | private | Optionally applies a reversible colored Finder tag xattr to configured folders. Requires `--allow-private`. |

## Quick Start

```bash
swift build
.build/debug/macwal --help
.build/debug/macwal palette --image /path/to/wallpaper.jpg --json
.build/debug/macwal preview --image /path/to/wallpaper.jpg --targets shell,terminal,chrome
.build/debug/macwal apply --image /path/to/wallpaper.jpg --targets shell --dry-run
.build/debug/macwal apply --image /path/to/wallpaper.jpg --targets shell
```

The safest first run is `shell`, because it only writes generated files under:

```text
~/Library/Application Support/macwal/generated/shell/
```

After that, try `terminal` and `chrome`:

```bash
macwal apply --image /path/to/wallpaper.jpg --targets terminal,chrome
```

Terminal installs its generated profile as the default Terminal profile by default. Chrome still writes a Manifest V3 theme folder for manual loading from `chrome://extensions`; Chrome does not expose a normal user-level API for silent theme activation.

For Firefox-family browsers and dotfile-driven terminals/editors, explicit targets write and import the generated theme automatically:

```bash
macwal apply --image /path/to/wallpaper.jpg --targets firefox,kitty,wezterm,vscode,tmux,btop
```

Firefox-family browsers and Thunderbird require an app restart because their chrome CSS is only loaded at startup. Most terminal/editor targets apply on the next app reload or new session; Kitty, tmux, yabai, sketchybar, janky-borders, and Hammerspoon also attempt their runtime reload command when the tool is available.

Do not start with `system` or `finder` on a primary account. Those paths use undocumented preferences or extended attributes and require explicit `--allow-private`.

## Safe Release Smoke Test

From a clone, run:

```bash
swift test
swift build -c release
scripts/smoke.sh
```

## Commands

```bash
macwal palette [--image PATH] [--screen INDEX] [--json]
macwal preview [--image PATH] [--targets TARGETS] [--allow-private] [--json]
macwal apply [--image PATH] [--targets TARGETS] [--allow-private] [--dry-run] [--json]
macwal restore [--targets TARGETS] [--dry-run] [--json]
macwal watch install [--targets TARGETS] [--allow-private]
macwal watch uninstall
macwal watch run [--targets TARGETS] [--allow-private]
macwal doctor [--json]
macwal list-targets [--json]
```

`TARGETS` is a comma-separated list:

```text
system,terminal,shell,obsidian,chrome,firefox,librewolf,zen,floorp,safari,spotify,
alacritty,kitty,wezterm,ghostty,iterm2,vscode,zed,vim,neovim,tmux,starship,bat,
btop,yazi,fzf,lazygit,aerospace,yabai,sketchybar,janky-borders,hammerspoon,
raycast,alfred,discord,thunderbird,telegram,slack,finder
```

`all` expands to every available non-private target unless `--allow-private` is present.

## Configuration

The config file is created at:

```text
~/Library/Application Support/macwal/config.json
```

Important settings and opt-ins:

- Terminal mutates `com.apple.Terminal` preferences when `adapters.terminal.setAsDefault` is true. This is true by default so `apply` visibly updates Terminal without a manual import step.
- Obsidian writes only to `adapters.obsidian.vaults` and enables the generated `macwal` snippet in each vault's `.obsidian/appearance.json`.
- Spotify requires `spicetify` on `PATH` or `adapters.spotify.spicetifyPath`.
- Firefox-family browsers and Thunderbird write only inside discovered profile directories.
- Generated app targets are documented in `docs/adapters/generated-apps.md`.
- System writes only happen when individual `adapters.system` booleans are enabled and `--allow-private` is supplied.
- Finder writes only happen when `adapters.finder.setFolderTint` is true, folders are listed, macOS is Tahoe or newer, and `--allow-private` is supplied.

## Restore

Use this command to restore files and settings previously modified by `macwal`:

```bash
macwal restore
```

Private adapters remain opt-in even after installation.

## Troubleshooting

### No Wallpaper Source

If macOS does not report a wallpaper image, pass one explicitly:

```bash
macwal palette --image /path/to/wallpaper.jpg --json
```

### Obsidian Vault Not Configured

Add vault paths to:

```text
~/Library/Application Support/macwal/config.json
```

Then run:

```bash
macwal apply --targets obsidian --image /path/to/wallpaper.jpg
```

`macwal` enables the generated `macwal` snippet automatically by updating `.obsidian/appearance.json`.

### Missing Spicetify

Spotify theming requires Spicetify. `macwal` does not install it automatically.

```bash
macwal preview --targets spotify --json
```

### Chrome Theme Loading

After applying the Chrome adapter, open `chrome://extensions`, enable Developer mode, choose "Load unpacked", and select:

```text
~/Library/Application Support/macwal/generated/chrome/macwal-theme/
```

Chrome does not expose a supported per-user CLI/API that silently activates an unpacked theme in an existing profile. Enterprise policy and UI scripting paths are intentionally not used by the default adapter.

### Firefox-Family Browser Restart

Firefox, LibreWolf, Zen, Floorp, and Thunderbird load `userChrome.css` and `userContent.css` at startup. After applying one of these targets, quit and reopen the app.

`macwal` updates this profile preference automatically:

```text
toolkit.legacyUserProfileCustomizations.stylesheets = true
```

### Generated App Targets

For file-driven apps, run a focused target list:

```bash
macwal apply --image /path/to/wallpaper.jpg --targets alacritty,kitty,wezterm,vscode,zed,vim,neovim,tmux,btop
```

Use `macwal preview --targets TARGETS --json` to see exact planned write paths before applying.

### Terminal Profile Activation

The Terminal adapter installs the generated profile into `com.apple.Terminal` and sets it as the default when `adapters.terminal.setAsDefault` is true.

Disable direct Terminal activation by setting `adapters.terminal.setAsDefault` to `false`.

## Uninstall

Restore generated files and preferences first:

```bash
macwal restore
macwal watch uninstall
```

Then remove the binary:

```bash
rm -f /usr/local/bin/macwal
```

Optional user data removal:

```bash
rm -rf "$HOME/Library/Application Support/macwal"
rm -rf "$HOME/Library/Caches/macwal"
```

## Watcher

```bash
macwal watch install --targets shell,terminal,chrome
macwal watch uninstall
```

The watcher installs `~/Library/LaunchAgents/io.macwal.watch.plist`. It runs `macwal watch run` periodically and skips writes when the wallpaper source and target list have not changed.

## Limitations

- Safari browser chrome cannot be directly themed.
- Chrome generated themes cannot be silently activated through supported per-user Chrome APIs.
- Firefox-family browser theming requires restart.
- Dock and menu bar system icons cannot be directly recolored.
- Raycast, Alfred, Telegram, and Slack do not expose stable user-owned theme dotfiles for silent activation, so macwal generates palette assets only.
- Finder folder tinting uses Tahoe's colored-tag behavior, not the full Customize Folder payload.
- Private adapters use undocumented macOS behavior and may change between macOS releases.
