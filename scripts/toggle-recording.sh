#!/usr/bin/env bash
# Toggle a recording of the focused niri output and the current playback device.
set -euo pipefail

unit=mine-screen-recording.service
umask 077
exec 9>"${XDG_RUNTIME_DIR:?}/mine-screen-recording.lock"
flock -n 9 || exit 0

notify() {
    notify-send --app-name="Screen recording" "$@" || true
}

if systemctl --user is-active --quiet "$unit"; then
    file=$(systemctl --user show "$unit" --property=Description --value)
    systemctl --user stop "$unit"
    if [[ -s "$file" ]]; then
        notify "Recording saved" "$file"
    else
        notify "Recording stopped" "No video was written."
    fi
    exit 0
fi

output=$(niri msg --json focused-output | jq -er '.name') || {
    notify "Could not start recording" "No focused display."
    exit 1
}
videos=$(xdg-user-dir VIDEOS) || videos="$HOME/Videos"
directory="$videos/Recordings"
mkdir -p -- "$directory"
args=(-o "$output" -x yuv420p)
if ffmpeg -nostdin -loglevel error -f lavfi -i color=s=640x480 -frames:v 1 -c:v h264_nvenc -f null - 2>/dev/null; then
    args+=(--no-dmabuf -c h264_nvenc -p cq=22)
else
    args+=(-c libx264 -p preset=veryfast)
fi
if sink=$(pactl get-default-sink) && [[ -n "$sink" ]]; then
    args+=(--audio-backend=pulse "--audio=$sink.monitor")
fi

file=$(mktemp --suffix=.mkv "$directory/Recording-$(date +%F-%H%M%S)-XXXX")
if systemd-run --user --quiet --collect --unit="$unit" --description="$file" \
        --property=Type=exec --property=KillSignal=SIGINT --property=PartOf=graphical-session.target \
        --setenv="WAYLAND_DISPLAY=${WAYLAND_DISPLAY:?}" \
        wf-recorder "${args[@]}" -y -f "$file"; then
    notify "Recording started" "$output"
else
    [[ -s "$file" ]] || rm -f -- "$file"
    notify "Could not start recording" "Check the user journal for $unit."
    exit 1
fi
