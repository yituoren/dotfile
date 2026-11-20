# Zsh Configuration Guide

## Link the configuration

```sh
for file in .zshrc .zshenv .zimrc .p10k.zsh; do
    ln -s "$HOME/.dotfiles/zsh-config/$file" "$HOME/$file"
done
```

## Settings

| File | Purpose |
| --- | --- |
| [.zshenv](../zsh-config/.zshenv) | Skip global completion initialization so Zim can manage completion |
| [.zimrc](../zsh-config/.zimrc) | Zim modules, including Powerlevel10k |
| [.p10k.zsh](../zsh-config/.p10k.zsh) | Prompt appearance |
| [.zshrc](../zsh-config/.zshrc) | Palette, Zim initialization, eza alias |

Keep the terminal palette block before the Powerlevel10k instant prompt. [Color guide](colors.md)
