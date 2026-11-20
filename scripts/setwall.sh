#!/usr/bin/env bash
# Set the wallpaper and regenerate matugen colors under niri with awww.
# Usage:
#   setwall <image-path>          Set an image with the fade transition.
#   setwall <image-path> wipe     Choose a transition (fade, wipe, grow, center, wave, etc.).
#   setwall random                Pick a random image from ~/Pictures/Wallpaper.

set -euo pipefail

WALL_DIR="${WALL_DIR:-$HOME/Pictures/Wallpaper}"
TRANSITION="${2:-fade}"

if [[ "${1:-}" == "random" ]]; then
    img="$(find "$WALL_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | shuf -n 1)"
elif [[ -f "${1:-}" ]]; then
    img="$1"
else
    echo "usage: $(basename "$0") <image|random> [transition]" >&2
    exit 2
fi

# Serialize wallpaper changes so the greeter receives the palette for the displayed image.
exec 8<"${BASH_SOURCE[0]}"
flock -x 8

# 1. Change the wallpaper.
awww img "$img" \
    --transition-type "$TRANSITION" \
    --transition-duration 0.8 \
    --transition-fps 60

# 2. Regenerate all matugen templates, including GTK, fuzzel and Quickshell colors.json.
# --source-color-index 0 selects the dominant color and skips the matugen 4.x picker.
matugen image "$img" --source-color-index 0

# The greeter reads a pre-blurred copy at boot, before the desktop session starts.
if [[ -w /var/lib/mine-greeter ]]; then
    repo=$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")
    "$repo/sddm/update-background" "$img" || echo "Could not update the login wallpaper" >&2
fi

flock -u 8
exec 8<&-

# KDE caches the active scheme in kdeglobals. Reapply it after matugen renders it.
if command -v plasma-apply-colorscheme >/dev/null; then
    if [[ $(kreadconfig6 --group General --key ColorScheme) == MineDesktop ]]; then
        plasma-apply-colorscheme --accent-color "$(jq -r '.primary' "$HOME/.local/state/quickshell/user/generated/colors.json")"
    else
        plasma-apply-colorscheme MineDesktop
    fi
fi

# 3. Derive terminal palette OSC sequences from colors.json and broadcast them to live terminals.
#    New zsh sessions read colors.json in .zshrc. This broadcast updates existing sessions.
#    Keep the Material You to ANSI 16 mapping in sync with .zshrc.
COLORS_JSON="$HOME/.local/state/quickshell/user/generated/colors.json"
if [[ -f "$COLORS_JSON" ]] && command -v jq >/dev/null; then
    mapfile -t C < <(jq -r '
        .background, .on_background, .primary,
        (.surface_container_lowest // .background),
        .error, .tertiary, .secondary, .primary,
        .tertiary_container, .primary_container, .on_surface,
        (.surface_container_low // .surface),
        .error_container,
        (.on_tertiary_container // .tertiary),
        (.on_secondary_container // .secondary),
        (.on_primary_container // .primary),
        (.tertiary_fixed // .tertiary),
        (.primary_fixed // .primary),
        (.inverse_surface // .on_background)
    ' "$COLORS_JSON")
    # C[0]=bg C[1]=fg C[2]=cursor C[3..18]=ANSI 0..15
    ESC=$'\033'; ST=$'\033\\'
    OSC=""
    for i in {0..15}; do OSC+="${ESC}]4;${i};${C[$((i+3))]}${ST}"; done
    OSC+="${ESC}]10;${C[1]}${ST}${ESC}]11;${C[0]}${ST}${ESC}]12;${C[2]}${ST}"

    for pts in /dev/pts/[0-9]*; do
        [[ -w "$pts" ]] && printf '%s' "$OSC" > "$pts" 2>/dev/null || true
    done
fi

# 4. Tell the custom shell's Theme service to reread colors.json.
#    Skip silently when Quickshell is not running.
qs -c mine ipc call theme reload 2>/dev/null || true

echo "wallpaper set: $img"
