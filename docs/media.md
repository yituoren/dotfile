# Media Configuration Guide

## Playback and audio

| Control | Backend |
| --- | --- |
| Hardware play, next and previous keys | niri runs `playerctl` against MPRIS. |
| Media tab and dashboard media strip | Quickshell reads the selected MPRIS session directly for metadata, transport and position. |
| Volume and mute | WirePlumber's `wpctl` controls the default PipeWire sink. |
| Output menu | `pactl` lists and selects sinks through `pipewire-pulse`. |
| Bar spectrum and album halo | A shared CAVA process reads the Pulse monitor source and sends ASCII samples to Quickshell. |

## Spectrum settings

Edit [cava.conf](../quickshell/mine/cava.conf) to change the number of bands, frame rate or capture source. The default is 32 bands at 60 frames per second. Keep the output in raw ASCII with a maximum of 100. CAVA loads this file when the shell starts its visualizer.

## Inspect the current session

```sh
playerctl --list-all
playerctl metadata --format '{{artist}} — {{title}}'
wpctl status
pactl get-default-sink
pactl list short sinks
```

Run these commands as the logged-in desktop user. If playback works but the spectrum stays flat, compare the default sink with the one carrying the audio. If a player is missing, check whether it publishes an MPRIS name with `playerctl --list-all`.

## Browser media

The Media menu shows one entry per media tab using the installed Plasma Browser Integration's TabsRunner. Chrome's native MPRIS player and Plasma are matched to tabs in the same browser process by a unique URL or, for Chrome's title-only reports, a unique page title. Native desktop players keep their own entries. If the tab interface is unavailable, the browser falls back to a single MPRIS player.

A newly playing tab becomes active in automatic selection. Clicking a row selects it for inspection. When its playback stops, another playing tab takes over. Plasma provides track details for the tab it currently reports. A background tab can retain its last reported title, artist and album while its page stays the same. Its audible status comes from TabsRunner. If MPRIS moves to another tab, the progress bar can advance from the last position and playback rate observed for the same tab and track. A live reading corrects it when the browser reports that tab again. Seeking and playback controls require a matching live MPRIS session. For Apple Music, the displayed track length comes from the existing matched lyrics catalogue result. The total stays blank when unavailable. Seeking requires the browser and catalogue lengths to agree within four seconds.

## Lyrics

Media reads `xesam:asText` from the current MPRIS player first. When lyrics are missing, it queries LRCLIB and NetEase Cloud Music in parallel and matches title, artist, album and available track duration. Results are cached in `~/.cache/quickshell/mine/lyrics/`. Apple Music may report the length of the continuous browser stream, so its total is excluded from matching. Timed lyrics follow the current MPRIS position even when totals differ. Lyrics without timing or playback position can be scrolled. Instrumental tracks leave the lyrics area empty.
