# Obsidian Adapter

Classification: `supported app config`

The Obsidian adapter writes:

```text
<vault>/.obsidian/snippets/macwal.css
<vault>/.obsidian/appearance.json
```

Vaults must be listed in:

```text
~/Library/Application Support/macwal/config.json
```

Example:

```json
{
  "adapters": {
    "obsidian": {
      "vaults": ["/Users/example/Documents/My Vault"]
    }
  }
}
```

`macwal` enables the generated `macwal` snippet automatically by adding it to `enabledCssSnippets` in `appearance.json`. Existing snippets and other appearance keys are preserved and backed up before writing.

Restore:

```bash
macwal restore --targets obsidian
```
