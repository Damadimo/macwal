# Finder Adapter

Classification: `private`

The Finder adapter requires macOS 26 Tahoe or newer and:

```bash
--allow-private
```

It does not attempt to write Apple's full Customize Folder payload. Instead, it applies a reversible Finder tag named `macwal` with a color nearest to the generated accent color. On Tahoe, colored Finder tags can tint folders.

Configuration:

```json
{
  "adapters": {
    "finder": {
      "setFolderTint": true,
      "folders": ["/Users/example/Desktop/Project"]
    }
  }
}
```

The adapter refuses to modify these root folders:

- `/System`
- `/Applications`
- `/Library`
- `/Users`

Restore:

```bash
macwal restore --targets finder
```

Restore returns the original Finder tag extended attribute exactly.
