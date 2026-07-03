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
- [ ] Open the generated `.terminal` profile in Terminal.app.
- [ ] Confirm colors render correctly.
- [ ] Enable `adapters.terminal.setAsDefault` in config.
- [ ] Verify apply without `--allow-private` is blocked.
- [ ] Verify apply with `--allow-private` backs up and writes Terminal preferences.
- [ ] Run `macwal restore --targets terminal`.

Acceptance criteria:

- Generated profile imports without plist errors.
- Direct preference mutation never happens without `--allow-private`.
- Restore returns Terminal preferences to their previous state.

#### Obsidian

- [ ] Configure a real test vault in `config.json`.
- [ ] Run `macwal apply --targets obsidian --image PATH`.
- [ ] Enable the `macwal.css` snippet in Obsidian.
- [ ] Confirm the theme applies.
- [ ] Run `macwal restore --targets obsidian`.

Acceptance criteria:

- Only configured vaults are written.
- Existing snippet content is restored if it existed before apply.

#### Chrome

- [ ] Run `macwal apply --targets chrome --image PATH`.
- [ ] Load the generated theme folder from `chrome://extensions`.
- [ ] Confirm browser chrome colors match the palette.
- [ ] Run `macwal restore --targets chrome`.

Acceptance criteria:

- Manifest loads as an unpacked extension.
- No Chrome profile preferences are modified.

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
- [ ] Add restore tests for existing defaults keys.
- [ ] Add restore tests for absent defaults keys.
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
  - [x] Terminal profile import
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
- There are no undocumented persistent writes.

## Known Limitations to Keep in Release Notes

- Safari browser chrome cannot be directly themed.
- Dock and menu bar glyphs cannot be safely recolored through public APIs.
- Finder support uses reversible colored tag extended attributes, not full Apple folder customization internals.
- System and Finder adapters use undocumented behavior and may break across macOS releases.
- Chrome theme loading is manual in the MVP.
- Spicetify is required for Spotify and is not installed by `macwal`.
