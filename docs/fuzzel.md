# Fuzzel Configuration Guide

## Linking the dotfile

```bash
mkdir -p ~/.config/fuzzel
ln -s ~/.dotfiles/fuzzel/fuzzel.ini ~/.config/fuzzel/fuzzel.ini
```

matugen renders `fuzzel_theme.ini` directly into `~/.config/fuzzel/`. The generated file stays outside the repository.

## Configuration

```ini
include="~/.config/fuzzel/fuzzel_theme.ini"   # Generated matugen palette
font=Maple Mono NF CN:weight=medium
terminal=wezterm start --                     # Desktop entries with Terminal=true
prompt=">>  "
layer=overlay

[border]
radius=17
width=1

[dmenu]
exit-immediately-if-empty=yes
```

### Terminal Prefix

Fuzzel appends the desktop entry's `Exec` command to this prefix. Include any terminal-specific execution flag in the prefix.

| Prefix | Command for `yazi` |
|---|---|
| `xterm -e` (default) | `xterm -e yazi` |
| `kitty -1` | `kitty -1 yazi` |
| `wezterm start --` | `wezterm start -- yazi` |
| `wezterm -e` | `wezterm -e yazi` |

### Font

Use `family:weight=...:size=...`. List available families with:

```bash
fc-list | grep -i maple
```

### Layer

The stacking order is `background < bottom < top < overlay`. The default overlay keeps fuzzel visible.

## niri Integration

Configure the background blur in `~/.dotfiles/niri/rules.kdl`.

```kdl
layer-rule {
    match namespace="^launcher$"
    geometry-corner-radius 17
    background-effect {
        blur true
    }
}
```

Fuzzel uses the fixed layer-shell namespace `launcher`. Verify the published namespace with:

```bash
# With fuzzel open, run this in another terminal.
niri msg layers
```

## Launch Modes

| Binding | Mode |
|---|---|
| niri `Mod+Space` → `spawn "fuzzel"` | Application launcher reading desktop entries |
| niri `Mod+V` → `cliphist list \| fuzzel --dmenu \| ...` | dmenu reading entries from stdin |
