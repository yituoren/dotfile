# Login screen

```sh
~/.dotfiles/sddm/install.sh
sddm-greeter-qt6 --test-mode --theme ~/.dotfiles/sddm/mine
```

The installer enables Mine for the next SDDM login. Niri is selected by default. Use the session menu to sign in to another desktop.

## Files

| Path | Purpose |
| --- | --- |
| `sddm/mine/` | Editable Qt 6 login theme |
| `/usr/share/sddm/themes/mine` | Symlink to the read-only view of the repository theme at `/run/minesddm` |
| `/var/lib/mine-greeter/` | Two blurred image slots and the generated matugen palette, readable before login |
| `/etc/sddm.conf.d/zz-mine.conf` | System-owned theme selection |
| `/etc/systemd/system/run-minesddm.mount` | System-owned mount definition |

QML edits appear the next time the greeter opens. `setwall` updates the login wallpaper and colors. To rebuild just the login background:

```sh
~/.dotfiles/sddm/update-background "$(cat ~/.local/state/quickshell/user/generated/wallpaper/path.txt)"
```

To restore the previously configured theme at the next login:

```sh
sudo rm /etc/sddm.conf.d/zz-mine.conf
sudo systemctl disable run-minesddm.mount
```
