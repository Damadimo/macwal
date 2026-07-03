# Packaging

## Release Build

```bash
swift build -c release
.build/release/macwal --help
```

## Local Install

```bash
install -m 0755 .build/release/macwal /usr/local/bin/macwal
```

## Homebrew Formula Draft

The draft formula lives at:

```text
Formula/macwal.rb
```

Before publishing:

1. Replace the placeholder GitHub URL.
2. Create a signed release tag.
3. Generate the source archive SHA-256.
4. Replace `REPLACE_WITH_RELEASE_TARBALL_SHA256`.
5. Run:

```bash
brew install --build-from-source ./Formula/macwal.rb
brew test macwal
```

## Uninstall

First restore generated files and preferences:

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

Private adapters remain opt-in after installation.
