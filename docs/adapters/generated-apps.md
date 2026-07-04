# Generated App Adapters

These targets write user-owned app configuration files or generated palette assets. They do not modify app bundles, install privileged helpers, disable SIP, or write system-protected paths.

Apply examples:

```bash
macwal apply --image /path/to/wallpaper.jpg --targets firefox,kitty,vscode,tmux,btop
macwal restore --targets firefox,kitty,vscode,tmux,btop
```

Preview exact writes before applying:

```bash
macwal preview --image /path/to/wallpaper.jpg --targets firefox,kitty,vscode --json
```

## Browser Profile Targets

Targets:

- `firefox`
- `librewolf`
- `zen`
- `floorp`
- `thunderbird`

Behavior:

- Discovers profiles from `profiles.ini`.
- Falls back to scanning `Profiles/` when no parseable `profiles.ini` exists.
- Writes `chrome/macwal.css`.
- Inserts a managed `@import url("macwal.css");` block in `chrome/userChrome.css`.
- Inserts a managed `@import url("macwal.css");` block in `chrome/userContent.css`.
- Enables custom profile chrome CSS by writing `toolkit.legacyUserProfileCustomizations.stylesheets` in `user.js`.
- These profiles load chrome CSS only at startup, so `macwal` quits and relaunches the app automatically to make the theme visible (set `MACWAL_SKIP_RESTART=1` to skip the restart).

Profile roots:

```text
~/Library/Application Support/Firefox/
~/Library/Application Support/LibreWolf/
~/Library/Application Support/Zen/
~/Library/Application Support/zen/
~/Library/Application Support/Floorp/
~/Library/Thunderbird/
```

## Terminal Targets

Targets and writes:

| Target | Writes | Runtime behavior |
| --- | --- | --- |
| `alacritty` | `~/.config/alacritty/macwal.toml`, import in `alacritty.toml` | Apply on config reload or app restart. |
| `kitty` | `~/.config/kitty/macwal.conf`, include in `kitty.conf` | Attempts `kitty @ set-colors --all --configured`. |
| `wezterm` | `~/.config/wezterm/macwal.lua`; creates `wezterm.lua` only if absent | Existing configs are not overwritten. |
| `ghostty` | `~/.config/ghostty/themes/macwal`, managed `theme = macwal` in config | Auto-quits and relaunches Ghostty to load the theme (set `MACWAL_SKIP_RESTART=1` to skip). |
| `iterm2` | `~/Library/Application Support/iTerm2/DynamicProfiles/macwal.json` | iTerm2 loads dynamic profiles automatically; select `macwal` for new sessions. |

## Editor Targets

Targets and writes:

| Target | Writes | Runtime behavior |
| --- | --- | --- |
| `vscode` | `~/.vscode/extensions/macwal-theme/`, `~/Library/Application Support/Code/User/settings.json` when valid JSON or absent | Selects `workbench.colorTheme = macwal`. |
| `zed` | `~/.config/zed/themes/macwal.json` | Theme is available to Zed. |
| `vim` | `~/.vim/colors/macwal.vim`, managed block in `~/.vimrc` | Applies on new Vim session or colorscheme reload. |
| `neovim` | `~/.config/nvim/colors/macwal.vim`, managed block in `init.lua` or `init.vim` | Applies on new Neovim session or colorscheme reload. |

## CLI and TUI Targets

Targets and writes:

| Target | Writes | Runtime behavior |
| --- | --- | --- |
| `tmux` | `~/.config/tmux/macwal.tmux`, managed source block in tmux config | Attempts `tmux source-file`. |
| `starship` | `[palettes.macwal]` block in `~/.config/starship.toml` | Activated by setting `palette = "macwal"` in the same file. |
| `bat` | `~/.config/bat/themes/macwal.tmTheme`, managed `--theme=macwal` in bat config | Attempts `bat cache --build`. |
| `btop` | `~/.config/btop/themes/macwal.theme`, `color_theme = "macwal"` in btop config | Applies on btop reload/restart. |
| `yazi` | `~/.config/yazi/flavors/macwal.flavor/flavor.toml`, `[flavor]` selection in `~/.config/yazi/theme.toml` | Selects the macwal flavor; applies on yazi reload/restart. |
| `fzf` | `~/.config/macwal/fzf.sh`, managed source block in shell rc files | Applies in new shells. |
| `lazygit` | `~/Library/Application Support/lazygit/config.yml` if absent | Existing Lazygit config is not overwritten; generated merge file is written instead. |

## macOS Tool Targets

Targets and writes:

| Target | Writes | Runtime behavior |
| --- | --- | --- |
| `aerospace` | `~/.config/aerospace/macwal.toml` | Palette fragment only. |
| `yabai` | `~/Library/Application Support/macwal/generated/yabai/macwal.sh` | Runs border color commands when `yabai` is on `PATH`. |
| `sketchybar` | `~/Library/Application Support/macwal/generated/sketchybar/macwal.sh` | Runs bar/icon/label color commands when `sketchybar` is on `PATH`. |
| `janky-borders` | `~/Library/Application Support/macwal/generated/janky-borders/macwal.sh` | Runs border color command when `borders` is on `PATH`. |
| `hammerspoon` | `~/.hammerspoon/macwal.lua`, managed `dofile` block in `init.lua` | Attempts `hs -c hs.reload()`. |

## Raycast

Target: `raycast`

Writes reusable palette assets plus a Raycast theme file:

```text
~/Library/Application Support/macwal/generated/raycast/colors.json
~/Library/Application Support/macwal/generated/raycast/colors.css
~/Library/Application Support/macwal/generated/raycast/macwal.raycasttheme
```

When Raycast is running, `macwal` opens the `.raycasttheme` to trigger Raycast's import flow (gated on `MACWAL_SKIP_RESTART`); confirm the import, then select `macwal` under Raycast Settings → Appearance. When Raycast is not running, importing it once is a manual step.

## Generated Asset Targets

Targets:

- `alfred`
- `telegram`
- `slack`

These apps do not expose stable user-owned theme dotfiles for silent activation. `macwal` writes reusable palette assets under:

```text
~/Library/Application Support/macwal/generated/<target>/colors.json
~/Library/Application Support/macwal/generated/<target>/colors.css
```

## Discord

Target: `discord`

Writes:

```text
~/.config/Vencord/themes/macwal.css
~/.config/Vencord/settings/settings.json   (enables macwal.css)
~/Library/Application Support/BetterDiscord/themes/macwal.theme.css   (only when that folder exists)
```

The Vencord theme is always written and enabled in Vencord's `settings.json` (`enabledThemes` includes `macwal.css`). A BetterDiscord theme is written only when the BetterDiscord themes folder already exists. Discord must reload (Cmd+R or restart) for the theme to appear; `macwal` does not force-restart Discord.

## Restore

Every generated app target records file backups before writing. Restore removes files created by `macwal` and restores files that existed before the first apply:

```bash
macwal restore --targets firefox,kitty,vscode,tmux,btop
```
