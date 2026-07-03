# Changelog

## v0.1.0 - Unreleased

Initial developer-tool release candidate.

### Added

- Wallpaper and explicit-image palette generation with contrast validation.
- CLI commands for `palette`, `preview`, `apply`, `restore`, `watch`, `doctor`, and `list-targets`.
- Shell, Terminal, Obsidian, Chrome, Safari, Spotify, system, and Finder adapters.
- Backup and restore for generated files, defaults keys, and Finder extended attributes.
- Filesystem write-root guard for adapter writes.
- Private adapter gating with `--allow-private`.
- LaunchAgent watcher with change detection.
- Adapter documentation and release checklist.
- Snapshot and integration-style tests using temporary home directories.

### Known Limitations

- Safari browser chrome cannot be directly themed.
- Dock and menu bar glyphs cannot be safely recolored through public APIs.
- Chrome theme loading is manual.
- Spotify requires a user-managed Spicetify installation.
- System and Finder adapters use undocumented macOS behavior and may break across releases.
