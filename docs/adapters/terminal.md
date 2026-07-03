# Terminal Adapter

Classification: `supported/private mixed`

The Terminal adapter generates:

```text
~/Library/Application Support/macwal/generated/terminal/macwal.terminal
```

The generated profile includes background, foreground, cursor, selection, and ANSI colors.

Apply:

```bash
macwal apply --targets terminal
```

By default, import the profile by opening the generated `.terminal` file.

To install the profile directly and set it as the default Terminal profile, enable:

```json
{
  "adapters": {
    "terminal": {
      "profileName": "macwal",
      "setAsDefault": true
    }
  }
}
```

When `setAsDefault` is true, `macwal` backs up and writes these Terminal preference keys:

- `com.apple.Terminal:Window Settings`
- `com.apple.Terminal:Default Window Settings`
- `com.apple.Terminal:Startup Window Settings`

Because these preference writes are undocumented, actual apply requires:

```bash
macwal apply --targets terminal --allow-private
```

Dry runs can still report the planned preference writes without `--allow-private`.

Restore:

```bash
macwal restore --targets terminal
```
