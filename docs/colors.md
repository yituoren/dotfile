# Wallpaper and Color Configuration Guide

## Link the configuration

This setup uses `awww`, `matugen` (provided here by `matugen-bin`) and `jq`. On a fresh checkout, link the template registry and template directory separately.

```sh
mkdir -p ~/.config/matugen ~/.config/fuzzel ~/.local/bin
ln -s ~/.dotfiles/matugen/config.toml ~/.config/matugen/config.toml
ln -s ~/.dotfiles/matugen/templates ~/.config/matugen/templates
ln -s ~/.dotfiles/scripts/setwall.sh ~/.local/bin/setwall
```

## Set the wallpaper

```sh
setwall ~/Pictures/Wallpaper/image.jpg
setwall ~/Pictures/Wallpaper/image.jpg wipe
setwall random
WALL_DIR=~/Pictures/Other setwall random
```

niri starts `awww-daemon` at login. The restore script first asks awww for its cached image, then reads the saved wallpaper path if the output still has no image. [Startup](../niri/startup.kdl) · [Restore script](../scripts/restore-wallpaper.sh)

## Palette consumers

`setwall` displays the image, then runs `matugen image` with source color index zero. The template registry defines the destinations. [Wallpaper script](../scripts/setwall.sh) · [matugen templates](../matugen/config.toml)

| Consumer | Output and refresh |
| --- | --- |
| Quickshell | Reads `~/.local/state/quickshell/user/generated/colors.json` at startup and on `qs -c mine ipc call theme reload`. |
| Lock screen | Loads the palette and `wallpaper/path.txt` from the same state directory at each lock. |
| SDDM | ImageMagick prepares a blurred copy and a greeter palette in `/var/lib/mine-greeter/` once the theme is installed. |
| GTK 3 and 4 | The generated `gtk.css` lives in each version's configuration directory. Reopen the application to pick up changes. |
| KDE applications | matugen writes `~/.local/share/color-schemes/MineDesktop.colors`. When available, `plasma-apply-colorscheme` applies the scheme or updates its accent. |
| fuzzel | Reads the generated sibling `fuzzel_theme.ini` on launch. |
| Cloud chat | The private WebEngine host loads the generated `quickshell/mine/chat/chat.css`. Edit its [template](../matugen/templates/quickshell/chat.css). |
| WezTerm, Kitty and Zsh | WezTerm reads and watches the JSON palette. Zsh loads it on startup. Running terminals receive OSC color sequences directly from `setwall`. |

## Change a color mapping

Edit a template and rerun `setwall` with the current image. For terminal ANSI colors, keep the Bash broadcast, Zsh startup and WezTerm configuration in sync. Colors 0–7 map to `surface_container_lowest`, `error`, `tertiary`, `secondary`, `primary`, `tertiary_container`, `primary_container` and `on_surface`. [Bash](../scripts/setwall.sh) · [Zsh](../zsh-config/.zshrc) · [WezTerm](../wezterm/wezterm.lua)

```sh
awww query
palette=~/.local/state/quickshell/user/generated
jq '{primary, background, on_surface}' "$palette/colors.json"
cat "$palette/wallpaper/path.txt"
qs -c mine ipc call theme reload
```
