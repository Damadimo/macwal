# Spotify Adapter

Classification: `external`

The Spotify adapter requires Spicetify. `macwal` does not install Spicetify.

Generated files:

```text
~/.config/spicetify/Themes/macwal/color.ini
~/.config/spicetify/Themes/macwal/user.css
```

Apply:

```bash
macwal apply --targets spotify
```

The adapter runs:

```bash
spicetify config current_theme macwal
spicetify apply
```

Restore:

```bash
macwal restore --targets spotify
```
