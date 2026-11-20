# Login screen

```sh
~/.dotfiles/sddm/install.sh
sddm-greeter-qt6 --test-mode --theme ~/.dotfiles/sddm/mine
```

The installer enables Mine for the next SDDM login. The greeter opens with the last account selected and the password field focused. Type your password and press Enter to sign in.

Select the username at the bottom center to switch accounts. A username field opens above the password field. Pick a listed account or type a username, then press Enter to move to the password. Press Escape or select **Back** to return to the default account. When no account is listed or remembered, the username field opens automatically.

The session menu in the lower left defaults to Niri. A keyboard layout selector appears beside it when multiple layouts are available. Power controls sit in the lower right.

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
