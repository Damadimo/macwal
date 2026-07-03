# Shell Adapter

Classification: `supported`

The shell adapter writes generated palette files under:

```text
~/Library/Application Support/macwal/generated/shell/
```

Files:

- `colors.sh`
- `colors.json`
- `colors.css`
- `colors.Xresources`

Apply:

```bash
macwal apply --targets shell
```

Restore:

```bash
macwal restore --targets shell
```

The adapter does not require external tools and does not modify shell startup files.
