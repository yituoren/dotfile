#!/usr/bin/env bash
set -eu

for ((attempt = 0; attempt < 50; attempt++)); do
    outputs=$(awww query 2>/dev/null) && [[ -n "$outputs" ]] && break
    sleep 0.2
done
[[ -n "$outputs" ]] || exit 1

awww restore && outputs=$(awww query)
[[ "$outputs" == *"currently displaying: image: "* ]] && exit 0

state_dir=${XDG_STATE_HOME:-"$HOME/.local/state"}
IFS= read -r image < "$state_dir/quickshell/user/generated/wallpaper/path.txt"
[[ -f "$image" ]] && exec awww img --transition-type none "$image"
