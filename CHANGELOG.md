# Changelog

## v0.1.0 - Unreleased

Initial developer-tool release candidate.

### Added

- Terminal.app and Ghostty now recolor their open windows in place — macwal writes OSC color escape sequences to each open window's TTY instead of force-quitting and relaunching the app, so no windows or sessions are lost. New windows still pick up the full profile/config; only window opacity waits for a new window (it is not a color). Honors `MACWAL_SKIP_RESTART=1`.
- One opacity knob for every translucent surface: `adapters.opacity` (default `0.85`; `1.0` restores fully opaque) controls the see-through level of every generated terminal theme (Alacritty, Kitty, WezTerm, Ghostty, iTerm2, and Terminal.app) and Discord's background panels. It replaces the terminal-only `adapters.terminalOpacity`; config files that still use the old key are read as an alias, and files with neither key default to `0.85`.
- Translucent Discord: the generated Vencord/Vesktop theme now renders Discord's background layers with `adapters.opacity` while keeping text and accent colors fully opaque. Full see-through to the desktop additionally requires Vencord's window-transparency/vibrancy option, which is a one-time manual step.
- Discord theming now targets the correct macOS locations. macwal writes the Vencord theme under `~/Library/Application Support/Vencord/` (previously the Linux `~/.config/Vencord/` path, which Discord on macOS never reads) and also themes Vesktop (`~/Library/Application Support/vesktop/`) when it is installed.
- Cleaner Firefox-family new tab / home / blank page: the background matches the palette (themed through `userContent.css`) and the default clutter is hidden — logo/wordmark, sponsored shortcuts, Pocket "recommended" stories, highlights, weather, and snippets — while the search box and the user's own top-site shortcuts are kept and recolored. The toolbar chrome remains fully functional, just recolored.
- `set` command: themes every supported target the user has installed (installed-detection via apps, CLIs on `PATH`, and config directories) and sets the desktop wallpaper on all displays in one step.
- `--image` now accepts a folder; a random image inside it is chosen (wallpaper rotation). This applies to `set`, `apply`, `preview`, and `palette`.
- Automatic activation with no manual step: browsers and Thunderbird are quit and relaunched; Terminal.app, Ghostty, and Kitty recolor their open windows live (no restart); VS Code/Zed/Vim/Neovim/Starship/Yazi/bat/btop themes are activated in their config; iTerm2's generated profile is set as default; the Discord (Vencord) theme is enabled in settings; Raycast is imported when running. `MACWAL_SKIP_RESTART=1` disables all restarts/reloads/live flips.
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
- Firefox-family browsers and Thunderbird are auto-restarted to apply the theme, which can discard open tabs or unsaved state. (Terminal.app and Ghostty recolor open windows in place instead; only their window opacity waits for a newly opened window.)
- Alfred, Telegram, and Slack support generated palette assets only until stable user-owned theme config surfaces are identified.
- Discord support writes and enables a Vencord theme (plus a Vesktop theme when Vesktop is installed and a BetterDiscord theme when that folder exists) but requires Discord to reload to show it. Discord's background translucency is applied via CSS; full desktop see-through additionally needs Vencord's window-transparency/vibrancy option (a manual one-time toggle). Vanilla Discord without a client mod cannot load custom CSS.
- Spotify requires a user-managed Spicetify installation.
- System and Finder adapters use undocumented macOS behavior and may break across releases.
