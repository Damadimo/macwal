# Chrome Adapter

Classification: `manual`

The Chrome adapter generates a Manifest V3 theme folder:

```text
~/Library/Application Support/macwal/generated/chrome/macwal-theme/
```

Load it manually:

1. Open `chrome://extensions`.
2. Enable Developer mode.
3. Choose "Load unpacked".
4. Select the generated `macwal-theme` folder.

`macwal` does not modify Chrome profile preferences.

Restore:

```bash
macwal restore --targets chrome
```
