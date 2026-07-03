# macwal Release Checklist

This file tracks what remains before publishing `macwal` as a usable developer tool.

## Current Status

- MVP implementation: complete
- Test suite: passing
- Release build: passing
- Public release readiness: not complete

## Required Before Release

### 1. Repository and Versioning

- [ ] Create or confirm the public Git repository location.
- [ ] Decide the first release version, for example `v0.1.0`.
- [x] Add a changelog entry for the first release.
- [ ] Tag the release commit.
- [ ] Confirm `README.md` examples work from a clean clone.

Acceptance criteria:

- A clean clone can run `swift build`, `swift test`, and `swift build -c release`.
- The release tag points to the exact commit intended for distribution.

### 2. Packaging

- [ ] Replace the placeholder homepage and source URL in `Formula/macwal.rb`.
- [ ] Generate the release tarball SHA-256.
- [ ] Replace `REPLACE_WITH_RELEASE_TARBALL_SHA256`.
- [ ] Run `brew install --build-from-source ./Formula/macwal.rb`.
- [ ] Run `brew test macwal`.
- [ ] Decide whether to distribute only source builds or also signed binaries.
- [ ] If distributing binaries, add signing and notarization instructions.

Acceptance criteria:

- Homebrew installs `macwal` from the release formula.
- `macwal --help` works after Homebrew install.
- Packaging docs do not imply private adapters are enabled by default.

### 3. Real macOS Validation

- [ ] Test on a clean macOS user account.
- [ ] Test on macOS 15 Sequoia.
- [ ] Test on macOS 26 Tahoe, especially Finder behavior.
- [ ] Verify `macwal doctor --json` on a clean machine.
- [ ] Verify `macwal restore` after every adapter tested below.

Acceptance criteria:

- No command writes outside documented user-owned locations.
- Restore succeeds after each real adapter test.
- No test requires disabling SIP or modifying app bundles.

### 4. Adapter Validation

#### Shell

- [ ] Run `macwal apply --targets shell --image PATH`.
- [ ] Source generated `colors.sh` in `zsh`.
- [ ] Confirm `colors.json`, `colors.css`, and `colors.Xresources` are usable.
- [ ] Run `macwal restore --targets shell`.

Acceptance criteria:

- All generated shell files exist after apply.
- Generated files are removed or restored after restore.

#### Terminal

- [ ] Run `macwal apply --targets terminal --image PATH`.
- [ ] Confirm the generated profile is installed as the default Terminal profile.
- [ ] Open a new Terminal window and confirm colors render correctly.
- [ ] Verify generated profile and defaults keys are backed up.
- [ ] Set `adapters.terminal.setAsDefault` to `false` and verify apply only writes the `.terminal` file.
- [ ] Run `macwal restore --targets terminal`.

Acceptance criteria:

- Generated profile parses without plist errors.
- Default config performs visible Terminal activation without `--allow-private`.
- `setAsDefault: false` performs no Terminal defaults writes.
- Restore returns Terminal preferences to their previous state.

#### Obsidian

- [ ] Configure a real test vault in `config.json`.
- [ ] Run `macwal apply --targets obsidian --image PATH`.
- [ ] Confirm `.obsidian/appearance.json` includes `macwal` in `enabledCssSnippets`.
- [ ] Open Obsidian and confirm the theme applies without enabling the snippet manually.
- [ ] Run `macwal restore --targets obsidian`.

Acceptance criteria:

- Only configured vaults are written.
- Existing snippet content is restored if it existed before apply.
- Existing `appearance.json` content is preserved and restored.

#### Chrome

- [ ] Run `macwal apply --targets chrome --image PATH`.
- [ ] Load the generated theme folder from `chrome://extensions`.
- [ ] Confirm browser chrome colors match the palette.
- [ ] Run `macwal restore --targets chrome`.

Acceptance criteria:

- Manifest loads as an unpacked extension.
- No Chrome profile preferences are modified.

#### Firefox-Family Browsers and Thunderbird

- [ ] Test `firefox` on a profile with existing `userChrome.css`, `userContent.css`, and `user.js`.
- [ ] Test `firefox` on a profile without a `chrome/` directory.
- [ ] Test `librewolf`, `zen`, `floorp`, and `thunderbird` when available.
- [ ] Run `macwal apply --targets firefox --image PATH`.
- [ ] Confirm `chrome/macwal.css` is written in the detected profile.
- [ ] Confirm `userChrome.css` and `userContent.css` import `macwal.css`.
- [ ] Confirm `user.js` enables `toolkit.legacyUserProfileCustomizations.stylesheets`.
- [ ] Quit and reopen the app and confirm chrome colors apply.
- [ ] Run `macwal restore --targets firefox`.

Acceptance criteria:

- Existing profile CSS and `user.js` content is preserved outside managed blocks.
- Profiles are discovered from `profiles.ini` and no unrelated profile roots are written.
- Restore removes generated files or restores previous profile files.
- Documentation clearly states restart is required.

#### Safari

- [ ] Run `macwal apply --targets safari --json`.
- [ ] Confirm it performs no writes.

Acceptance criteria:

- Safari remains an informational no-op.
- Documentation clearly says Safari chrome cannot be directly themed.

#### Spotify

- [ ] Install Spicetify manually on a test machine.
- [ ] Run `macwal apply --targets spotify --image PATH`.
- [ ] Confirm `spicetify config current_theme macwal` is applied.
- [ ] Confirm Spotify reflects the theme.
- [ ] Run `macwal restore --targets spotify`.

Acceptance criteria:

- Missing Spicetify exits with status `2`.
- Apply runs the expected Spicetify commands.
- Restore returns generated files/settings to their prior state as implemented.

#### Terminal Apps

- [ ] Run `macwal apply --targets alacritty,kitty,wezterm,ghostty,iterm2 --image PATH`.
- [ ] Confirm Alacritty imports `~/.config/alacritty/macwal.toml`.
- [ ] Confirm Kitty includes `macwal.conf` and live reload succeeds when Kitty remote control is available.
- [ ] Confirm WezTerm writes `macwal.lua` without overwriting an existing `wezterm.lua`.
- [ ] Confirm Ghostty selects `theme = macwal`.
- [ ] Confirm iTerm2 loads the Dynamic Profile.
- [ ] Run `macwal restore --targets alacritty,kitty,wezterm,ghostty,iterm2`.

Acceptance criteria:

- Generated terminal palettes include background, foreground, cursor, selection, and all ANSI colors.
- Existing config files are restored exactly.
- Runtime reload commands are best-effort and do not fail the whole apply when the tool is absent.

#### Editors

- [ ] Run `macwal apply --targets vscode,zed,vim,neovim --image PATH`.
- [ ] Confirm VS Code theme extension is generated and `workbench.colorTheme` is set when `settings.json` is valid JSON or absent.
- [ ] Confirm Zed theme JSON is written.
- [ ] Confirm Vim and Neovim colorschemes are written and enabled by managed config blocks.
- [ ] Run `macwal restore --targets vscode,zed,vim,neovim`.

Acceptance criteria:

- Existing editor configs are preserved outside managed blocks.
- Invalid VS Code settings JSON is not overwritten.
- Restore removes generated themes or restores pre-existing files.

#### CLI and TUI Apps

- [ ] Run `macwal apply --targets tmux,starship,bat,btop,yazi,fzf,lazygit --image PATH`.
- [ ] Confirm tmux config sources `macwal.tmux` and reloads when tmux is available.
- [ ] Confirm Starship palette fragment is generated.
- [ ] Confirm bat theme is selected and cache build runs when `bat` is available.
- [ ] Confirm btop selects `color_theme = "macwal"`.
- [ ] Confirm Yazi theme file is written.
- [ ] Confirm fzf shell export is sourced from `~/.zshrc` and from `~/.bashrc` only if it exists.
- [ ] Confirm Lazygit does not overwrite an existing config and instead writes a merge file.
- [ ] Run `macwal restore --targets tmux,starship,bat,btop,yazi,fzf,lazygit`.

Acceptance criteria:

- Every target writes only documented user-owned config paths.
- Existing config files are restored exactly.
- Missing optional executables do not make generated file writes fail.

#### macOS Desktop Tools

- [ ] Run `macwal apply --targets aerospace,yabai,sketchybar,janky-borders,hammerspoon --image PATH`.
- [ ] Confirm AeroSpace palette fragment is generated.
- [ ] Confirm yabai border colors are applied when `yabai` is available.
- [ ] Confirm SketchyBar bar/icon/label colors are applied when `sketchybar` is available.
- [ ] Confirm janky-borders colors are applied when `borders` is available.
- [ ] Confirm Hammerspoon loads `macwal.lua` and reloads when `hs` is available.
- [ ] Run `macwal restore --targets aerospace,yabai,sketchybar,janky-borders,hammerspoon`.

Acceptance criteria:

- Missing optional desktop-tool CLIs are reported without failing generated file writes.
- Runtime commands use palette colors in the expected app-specific formats.
- Restore removes generated fragments and restores pre-existing config files.

#### Generated Asset Targets

- [ ] Run `macwal apply --targets raycast,alfred,discord,telegram,slack --image PATH`.
- [ ] Confirm Raycast, Alfred, Telegram, and Slack palette assets are generated under app support.
- [ ] Confirm Discord CSS is written for Vencord and BetterDiscord theme directories.
- [ ] Run `macwal restore --targets raycast,alfred,discord,telegram,slack`.

Acceptance criteria:

- Documentation does not claim silent activation for Raycast, Alfred, Telegram, or Slack.
- Discord docs state that Vencord/BetterDiscord must load the generated theme.
- Restore removes generated assets or restores pre-existing files.

#### System

- [ ] Enable one system setting at a time in `config.json`.
- [ ] Verify apply without `--allow-private` is blocked.
- [ ] Run dry-run and inspect exact planned defaults keys.
- [ ] Run actual apply with `--allow-private` on a test account.
- [ ] Confirm appearance, accent, or highlight changes behave as expected.
- [ ] Run `macwal restore --targets system`.

Acceptance criteria:

- No system writes happen without `--allow-private`.
- Original defaults values are backed up before mutation.
- Restore returns previous defaults state.

#### Finder

- [ ] Configure only disposable test folders.
- [ ] Verify apply without `--allow-private` is blocked.
- [ ] Verify protected root folders are refused.
- [ ] Run apply with `--allow-private` on macOS 26 Tahoe.
- [ ] Confirm Finder tag/tint behavior.
- [ ] Run `macwal restore --targets finder`.

Acceptance criteria:

- Only explicitly configured folders are modified.
- No recursive folder changes occur.
- Extended attributes are restored exactly.

### 5. Test Coverage Improvements

- [x] Add the five planned wallpaper fixtures:
  - [x] dark low-saturation wallpaper
  - [x] bright low-saturation wallpaper
  - [x] high-saturation wallpaper
  - [x] mostly red wallpaper
  - [x] mostly blue/green wallpaper
- [x] Add expected palette snapshots for each fixture.
- [x] Add snapshot coverage for Terminal plist output.
- [x] Add snapshot coverage for Obsidian CSS.
- [x] Add snapshot coverage for Spicetify `color.ini`.
- [x] Add restore tests for pre-existing files.
- [x] Add restore tests for absent files.
- [x] Add restore tests for existing defaults keys.
- [x] Add restore tests for absent defaults keys.
- [x] Add target-list coverage for the expanded adapter registry.
- [x] Add Firefox profile dotfile apply/restore coverage.
- [x] Add generated app config apply/restore coverage for terminal/editor/TUI/macOS-tool targets.
- [ ] Add doctor failure tests for unwritable app support paths.

Acceptance criteria:

- `swift test` is deterministic.
- Tests do not modify the real user home directory.
- Snapshot changes require intentional review.

### 6. Documentation

- [x] Add a short release quickstart.
- [x] Add a safe first-run guide using only `shell`, `terminal`, and `chrome`.
- [x] Add a private-adapter warning section near command examples.
- [x] Add troubleshooting for:
  - [x] missing wallpaper source
  - [x] missing Spicetify
  - [x] Obsidian vault not configured
  - [x] Chrome theme loading
  - [x] Terminal profile activation
- [x] Add generated app adapter documentation.
- [x] Add Firefox-family browser restart documentation.
- [x] Add uninstall instructions to `README.md`, not only `docs/packaging.md`.

Acceptance criteria:

- A new user can install, apply a safe target, preview changes, and restore from the README alone.
- Documentation does not overclaim Safari, Dock, menu bar, icon, or protected system theming support.

### 7. Final Release Gate

- [x] `swift test` passes.
- [x] `swift build -c release` passes.
- [x] `.build/release/macwal --help` works.
- [x] CLI smoke tests pass under a temporary `MACWAL_HOME`.
- [ ] Homebrew formula installs successfully.
- [ ] `macwal restore` has been manually tested after real adapter runs.
- [x] Known limitations are documented.
- [x] Release notes include private API risk.

Acceptance criteria:

- Every required checklist item above is complete.
- There are no known data-loss bugs.
- Any undocumented persistent write is documented, backed up, and restorable.

## Known Limitations to Keep in Release Notes

- Safari browser chrome cannot be directly themed.
- Dock and menu bar glyphs cannot be safely recolored through public APIs.
- Finder support uses reversible colored tag extended attributes, not full Apple folder customization internals.
- System and Finder adapters use undocumented behavior and may break across macOS releases.
- Chrome theme loading is manual because Chrome has no supported per-user silent activation API for unpacked themes.
- Spicetify is required for Spotify and is not installed by `macwal`.
