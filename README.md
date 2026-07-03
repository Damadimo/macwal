# macwal

`macwal` is a macOS command-line theming tool inspired by `pywal`.
It reads the current wallpaper or an explicit image, extracts a contrast-safe palette, and applies generated theme assets to supported macOS and app-level surfaces.

## Safety

Every target is classified before it can write anything:

- `supported`: Uses a public API or documented app configuration surface.
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
| `terminal` | supported/private mixed | Generates a `.terminal` profile. Does not mutate Terminal preferences by default. |
| `obsidian` | supported app config | Writes CSS snippets to configured vaults. |
| `chrome` | manual/supported extension format | Generates a Manifest V3 theme folder for manual loading. |
| `spotify` | external | Generates and applies a Spicetify theme. |
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

Terminal writes a `.terminal` profile for manual import. Chrome writes a Manifest V3 theme folder for manual loading from `chrome://extensions`.

Do not start with `system`, `finder`, or Terminal `setAsDefault` on a primary account. Those paths use undocumented preferences or extended attributes and require explicit `--allow-private`.

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
system,terminal,shell,obsidian,chrome,safari,spotify,finder
```

`all` expands to every available non-private target unless `--allow-private` is present.

## Configuration

The config file is created at:

```text
~/Library/Application Support/macwal/config.json
```

Important opt-in settings:

- Terminal only mutates `com.apple.Terminal` preferences when `adapters.terminal.setAsDefault` is true and `--allow-private` is supplied.
- Obsidian writes only to `adapters.obsidian.vaults`.
- Spotify requires `spicetify` on `PATH` or `adapters.spotify.spicetifyPath`.
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

Obsidian users may need to enable the `macwal.css` snippet once in Settings > Appearance > CSS snippets.

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

### Terminal Profile Import

After applying the Terminal adapter, open:

```text
~/Library/Application Support/macwal/generated/terminal/macwal.terminal
```

Terminal preference mutation only happens when `adapters.terminal.setAsDefault` is true and `--allow-private` is supplied.

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
- Dock and menu bar system icons cannot be directly recolored.
- Finder folder tinting uses Tahoe's colored-tag behavior, not the full Customize Folder payload.
- Private adapters use undocumented macOS behavior and may change between macOS releases.
