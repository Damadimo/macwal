# System Adapter

Classification: `private`

The system adapter uses undocumented global macOS preferences and requires:

```bash
--allow-private
```

It only writes settings enabled in `config.json`:

```json
{
  "adapters": {
    "system": {
      "setAppearanceMode": true,
      "setAccentColor": true,
      "setHighlightColor": true
    }
  }
}
```

Possible writes:

- `-globalDomain:AppleInterfaceStyle`
- `-globalDomain:AppleInterfaceStyleSwitchesAutomatically`
- `-globalDomain:AppleAccentColor`
- `-globalDomain:AppleHighlightColor`

After writes, `macwal` posts appearance-change notifications. It does not kill or restart user apps.

Restore:

```bash
macwal restore --targets system
```

Private behavior can change between macOS releases.
