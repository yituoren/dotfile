# niri Configuration Guide

## Link the session files

On a fresh account, place the checkout in `~/.dotfiles`. Set the absolute home paths in `environment.kdl` and `startup.kdl` for that account. The environment block takes literal paths.

```sh
mkdir -p ~/.config/xdg-desktop-portal
ln -s ~/.dotfiles/niri ~/.config/niri
ln -s ~/.dotfiles/xdg-desktop-portal/niri-portals.conf ~/.config/xdg-desktop-portal/
niri validate
```

## Settings

| File | Edit here to change |
| --- | --- |
| [binds.kdl](../niri/binds.kdl) | Keyboard and mouse bindings, media keys and application commands |
| [layout.kdl](../niri/layout.kdl) | Width presets, gaps, window decorations and the top strut reserved for the shell |
| [outputs.kdl](../niri/outputs.kdl) · [input.kdl](../niri/input.kdl) | Output names, positions, modes, scaling and input devices |
| [rules.kdl](../niri/rules.kdl) | Floating dialogs, layer effects and fuzzel corner radius |
| [environment.kdl](../niri/environment.kdl) | User executable path, QML imports, input method and Qt environment |
| [startup.kdl](../niri/startup.kdl) | Fcitx5, wallpaper restore, keyring, session guard, clipboard watchers, GeoClue and the shell |

niri reloads saved configuration files. Startup commands run at the next login. Match monitor names and modes to the output of `niri msg outputs`. The current top strut is 61 px for the 53 px bar and its 8 px margin.

## Keyboard help and session prompts

Press `Super+/` to open the shortcut sheet. Press Down to browse categories, Right to enter a category and Left to return. Use Up and Down to scroll the bindings. Type in the search field to filter all categories, then press Down to browse matches. Escape closes the sheet. It reads the chords in `binds.kdl` each time it opens. Keep the section headings (`// ---- Applications ----`) and use niri's `hotkey-overlay-title` on bindings that launch external commands.

`Super+Shift+E` and the power menu share the logout prompt. The icon-only restart and shut down buttons execute their actions directly. Tab moves between the buttons, Enter activates the focused button and Escape dismisses the prompt.

## Check a running session

```sh
niri msg outputs
niri msg layers
qs -c mine ipc show
systemctl --user status mine-sleep-lock.service mine-idle.service
```

The GTK backend handles file dialogs in niri. The Secret portal uses GNOME Keyring. The SDDM session menu also offers Plasma on this machine. [Portal selection](../xdg-desktop-portal/niri-portals.conf) · [Login theme](../sddm/README.md)
