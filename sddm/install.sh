#!/usr/bin/env bash
# Run as the desktop user. sudo is used only for system-owned paths and the mount.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
[[ $(id -u) != 0 ]] || { echo "Run as the desktop user." >&2; exit 1; }
theme=/usr/share/sddm/themes/mine
assets=/var/lib/mine-greeter
wallpaper=$(cat "$HOME/.local/state/quickshell/user/generated/wallpaper/path.txt")
[[ -r "$wallpaper" ]]
if [[ -e "$theme" || -L "$theme" ]] && [[ $(readlink -- "$theme" || :) != /run/minesddm ]]; then
    echo "$theme is already in use by another theme." >&2
    exit 1
fi
sudo -v
sudo install -d -o "$(id -u)" -g "$(id -g)" -m 0755 "$assets"
"$here/update-background" "$wallpaper" "$assets"
# A read-only alias exposes just the theme through the 0700 home directory.
# The greeter sees repository edits without gaining access to the rest of HOME.
sudo install -m 0644 "$here/run-minesddm.mount" /etc/systemd/system/run-minesddm.mount
sudo systemctl daemon-reload
sudo systemctl enable --now run-minesddm.mount
if [[ ! -L "$theme" ]]; then sudo ln -sT /run/minesddm "$theme"; fi
sudo -u sddm test -r "$theme/Main.qml"
sudo -u sddm test -r "$assets/theme.conf.user"
sudo -u sddm test -r "$assets/$(sed -n 's/^wallpaper=//p' "$assets/theme.conf.user")"
# Only select the theme after the greeter can read all required files.
sudo install -m 0644 "$here/90-mine.conf" /etc/sddm.conf.d/zz-mine.conf
echo "Mine is ready for the next login."
