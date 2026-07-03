# Changelog

## v0.1.0 - Unreleased

Initial developer-tool release candidate.

### Added

- Wallpaper and explicit-image pywal-style palette generation with contrast validation.
- CLI commands for `palette`, `preview`, `apply`, `restore`, `watch`, `doctor`, and `list-targets`.
- Shell, Terminal, Obsidian, Chrome, Safari, Spotify, system, and Finder adapters.
- Firefox-family and Thunderbird profile theming through generated `userChrome.css`, `userContent.css`, and `user.js`.
- Generated app adapters for Alacritty, Kitty, WezTerm, Ghostty, iTerm2, VS Code, Zed, Vim, Neovim, tmux, Starship, bat, btop, Yazi, fzf, Lazygit, AeroSpace, yabai, SketchyBar, janky-borders, Hammerspoon, Raycast, Alfred, Discord, Telegram, and Slack.
- Backup and restore for generated files, defaults keys, and Finder extended attributes.
- Automatic Terminal profile installation and Obsidian CSS snippet enabling.
- Filesystem write-root guard for adapter writes.
- Private adapter gating with `--allow-private`.
- LaunchAgent watcher with change detection.
- Adapter documentation and release checklist.
- Snapshot and integration-style tests using temporary home directories.

### Known Limitations

- Safari browser chrome cannot be directly themed.
- Dock and menu bar glyphs cannot be safely recolored through public APIs.
- Chrome theme loading is manual because Chrome has no supported per-user silent activation API for unpacked themes.
- Firefox-family and Thunderbird chrome CSS requires app restart.
- Raycast, Alfred, Telegram, and Slack support generated palette assets only until stable user-owned theme config surfaces are identified.
- Discord support writes Vencord/BetterDiscord theme files but requires those clients/mods to load the theme.
- Spotify requires a user-managed Spicetify installation.
- System and Finder adapters use undocumented macOS behavior and may break across releases.
