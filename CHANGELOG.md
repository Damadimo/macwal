# Changelog

## v0.1.0 - Unreleased

Initial developer-tool release candidate.

### Added

- `set` command: themes every supported target the user has installed (installed-detection via apps, CLIs on `PATH`, and config directories) and sets the desktop wallpaper on all displays in one step.
- `--image` now accepts a folder; a random image inside it is chosen (wallpaper rotation). This applies to `set`, `apply`, `preview`, and `palette`.
- Automatic activation with no manual step: browsers, Thunderbird, Terminal.app, and Ghostty are quit and relaunched; Kitty is live-reloaded; VS Code/Zed/Vim/Neovim/Starship/Yazi/bat/btop themes are activated in their config; iTerm2's generated profile is set as default; the Discord (Vencord) theme is enabled in settings; Raycast is imported when running. `MACWAL_SKIP_RESTART=1` disables all restarts/reloads/live flips.
- Wallpaper and explicit-image pywal-style palette generation with contrast validation.
- CLI commands for `set`, `palette`, `preview`, `apply`, `restore`, `watch`, `doctor`, and `list-targets`.
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
- Firefox-family browsers, Thunderbird, Terminal.app, and Ghostty are auto-restarted to apply the theme, which can discard open tabs or unsaved state.
- Alfred, Telegram, and Slack support generated palette assets only until stable user-owned theme config surfaces are identified.
- Discord support writes and enables a Vencord theme (and a BetterDiscord theme when that folder exists) but requires Discord to reload to show it.
- Spotify requires a user-managed Spicetify installation.
- System and Finder adapters use undocumented macOS behavior and may break across releases.
