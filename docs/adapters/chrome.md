# Chrome Adapter

Classification: `manual`

The Chrome adapter generates a Manifest V3 theme folder:

```text
~/Library/Application Support/macwal/generated/chrome/macwal-theme/
```

Chrome does not expose a supported per-user CLI/API that silently activates an unpacked theme in an existing profile, so loading remains manual:

1. Open `chrome://extensions`.
2. Enable Developer mode.
3. Choose "Load unpacked".
4. Select the generated `macwal-theme` folder.

`macwal` does not modify Chrome profile preferences, install enterprise policies, or use UI scripting in the default adapter.

Restore:

```bash
macwal restore --targets chrome
```
