# WezTerm Configuration Guide

## Link the configuration

```sh
mkdir -p ~/.config/wezterm
ln -s ~/.dotfiles/wezterm/wezterm.lua ~/.config/wezterm/wezterm.lua
```

## Desktop integration

| Entry point | Command |
| --- | --- |
| niri terminal shortcut (`Mod+Return`) | `wezterm` |
| niri file manager shortcut (`Mod+E`) | `wezterm start --class yazi -- yazi` |
| fuzzel terminal desktop entries | `wezterm start --` followed by the desktop command |

WezTerm runs on Wayland with the OpenGL renderer and Maple Mono NF CN. It reads the matugen palette on launch, including when Yazi starts directly, and watches it for changes. Edit the Lua file for fonts, opacity, pane shortcuts and the renderer. [Configuration](../wezterm/wezterm.lua) · [Color guide](colors.md)
