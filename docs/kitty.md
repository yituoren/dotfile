# Kitty Configuration Guide

## Link the configuration

This desktop uses the Arch `kitty` package. Link the hand-written directory on a fresh checkout.

```sh
mkdir -p ~/.config
ln -s ~/.dotfiles/kitty ~/.config/kitty
```

## Desktop integration

`Mod+T` opens Kitty. Edit [kitty.conf](../kitty/kitty.conf) for fonts, opacity and terminal settings. New interactive Zsh sessions read the wallpaper palette at startup. Running terminals receive updated colors from `setwall`. [Color guide](colors.md)
