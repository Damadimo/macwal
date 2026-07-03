# Obsidian Adapter

Classification: `supported app config`

The Obsidian adapter writes:

```text
<vault>/.obsidian/snippets/macwal.css
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

After the first write, enable the `macwal` snippet once in Obsidian Settings > Appearance > CSS snippets.

Restore:

```bash
macwal restore --targets obsidian
```
