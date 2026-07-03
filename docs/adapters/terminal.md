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

By default, `macwal` also installs the profile directly and sets it as the default Terminal profile:

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

Set `adapters.terminal.setAsDefault` to `false` to generate only the `.terminal` profile file.

Restore:

```bash
macwal restore --targets terminal
```
