# My Arch Linux Dotfiles

My Wayland desktop runs niri with a custom Quickshell bar, dashboard, chat panel and lock screen. SDDM handles login. Changing the wallpaper with `setwall` updates the desktop palette, terminals and login theme together.

![Wallpaper from the collection](assets/wallpaper.jpg)

## Desktop software

| Software | Where it is used | Configuration |
| --- | --- | --- |
| niri | Scrolling layout, workspaces, overview, shortcuts, screenshots and color picker | [Session setup](docs/niri.md) |
| Quickshell (`qs`), Qt Quick, Caelestia.Blobs | Per-output bar, popups, tray, notifications and dashboard. The locally built C++ plugin draws the joined bar and popup and supplies their blur geometry. | [Shell setup and plugin build](docs/quickshell.md) |
| Quickshell IdleMonitor, systemd-logind, PAM, Python with PyGObject | Lock after 5 idle minutes, power off displays after 10 and suspend after 15. The session lock also runs before sleep. | [Lock and idle units](docs/quickshell.md#session-lock) |
| SDDM, ImageMagick | Qt 6 greeter with a blurred copy of the current wallpaper and a password field shared with the session lock | [Login theme installation](sddm/README.md) |
| awww, matugen, jq | `awww-daemon` displays the wallpaper. `matugen` extracts Material You colors and renders GTK, KDE, fuzzel and chat themes. `jq` reads the palette for terminals. | [Wallpaper and colors](docs/colors.md) |
| xdg-desktop-portal-gtk, GNOME Keyring | GTK handles portal requests such as file selection. GNOME Keyring provides the Secret portal. | [niri portal preferences](xdg-desktop-portal/niri-portals.conf) |
| Fcitx5, Rime | Chinese input with Rime-Ice. Fcitx starts with the session. The input profile and Autumn theme live in the user account. | [Startup](niri/startup.kdl) · [Environment](niri/environment.kdl) |
| Maple Mono NF CN, Material Symbols Rounded, Bibata Modern Classic | Terminal and launcher text, shell icons and the niri pointer | [WezTerm](wezterm/wezterm.lua) · [fuzzel](fuzzel/fuzzel.ini) · [Cursor](niri/startup.kdl) |

The account also uses Darkly for KDE widgets, Breeze Plus icons and Google Sans Flex for GTK text. The generated KDE palette is defined in [MineDesktop.colors](matugen/templates/kde/MineDesktop.colors).

## Dashboard and devices

| Software or service | What it does | Configuration |
| --- | --- | --- |
| MPRIS, playerctl | The Media tab reads track information and controls the selected player through MPRIS. niri's play/pause, next and previous keys call `playerctl`. | [Media guide](docs/media.md) |
| CAVA | Samples the output mix for the bar spectrum and the ring around the album cover | [Spectrum settings](quickshell/mine/cava.conf) |
| PipeWire, WirePlumber, pipewire-pulse | `wpctl` adjusts volume and mute. `pactl` lists and selects output devices through the PulseAudio-compatible server. | [Audio and playback checks](docs/media.md) |
| Plasma Browser Integration | Optional Chrome tab discovery. The Media tab matches tab information with the browser's MPRIS reports. | [Browser media](docs/media.md#browser-media) |
| LRCLIB, NetEase Cloud Music | Supply lyrics when the player omits them. Instrumental tracks leave the lyrics area empty. | [Lyrics](docs/media.md#lyrics) |
| EasyEffects | Optional PipeWire effects processor. The startup hook runs it when the executable is installed. | [Startup](niri/startup.kdl) |
| NetworkManager, plasma-nm, BlueZ, BlueDevil | `nmcli` and `bluetoothctl` drive the quick controls. Network settings open the KDE module, and pairing opens `bluedevil-wizard`. | [Device controls](quickshell/mine/services/SystemStatus.qml) |
| brightnessctl, ddcutil | Adjust the internal backlight and DDC/CI-capable external displays. Battery status comes from Linux sysfs. | [Brightness and battery](quickshell/mine/services/SystemStatus.qml) |
| Taskwarrior (`task`), GTK (`gtk-launch`) | The dashboard calendar reads and edits tasks. App search launches desktop entries and opens terminal apps in WezTerm. | [Tasks](quickshell/mine/services/Tasks.qml) · [App search](quickshell/mine/modules/drawers/AppSearch.qml) |
| GeoClue, curl, Python | Weather uses GeoClue or IP geolocation, Open-Meteo forecasts and an NMC station fallback. The shell starts the first fetch at login. | [Weather service](quickshell/mine/services/Weather.qml) |
| Linux procfs and sysfs, df, nvidia-smi | The Control tab samples system metrics. NVIDIA metrics appear when the driver utility is available. | [System monitor](quickshell/mine/services/SysMonitor.qml) |
| Qt WebEngine, Codex CLI | The Arch logo opens Cloud chat in a persistent WebEngine profile or Local chat through `codex app-server` in the home directory. Cloud uses a private Quickshell launcher. | [Chat setup and commands](docs/quickshell.md#chat-panel) |

## Applications and shortcuts

`Mod` is the Super key. The dashboard opens from the center of the bar. [All bindings](niri/binds.kdl)

| Shortcut | Software and action |
| --- | --- |
| `Mod+Space` / `Mod+V` | [fuzzel](docs/fuzzel.md) launches apps or selects clipboard history from cliphist. wl-clipboard provides `wl-paste` and `wl-copy`. |
| `Mod+Return` / `Mod+T` | Open [WezTerm](docs/wezterm.md) or [Kitty](docs/kitty.md). [Zsh](docs/zsh.md) uses Zimfw, Powerlevel10k and eza. |
| `Mod+E` | Open [Yazi](docs/yazi.md) in WezTerm. Dolphin is also available as a graphical file manager. |
| `Mod+W` / `Mod+C` | Open Google Chrome or Zed. |
| `Mod+Shift+S` / `Mod+Shift+C` | Use niri's region screenshot or copy a picked hex color. |
| `Mod+Shift+X` | Select a region with slurp, capture it with grim and copy Tesseract OCR text. |
| `Mod+Ctrl+L` / `Ctrl+Alt+Delete` | Lock the session or toggle the shell power menu. |
| `Mod+Tab` / `Mod+Slash` | Open the niri overview or the searchable Quickshell shortcut sheet. |

Clash Verge uses a local mixed proxy port. The Zsh functions `start_proxy` and `stop_proxy` set or clear the HTTP proxy variables for the current shell. [Proxy configuration](clash-verge/config.yaml) · [Shell functions](zsh-config/.zshrc)

## Configuration layout

The checkout lives at `~/.dotfiles`. niri and Kitty link their directories. WezTerm, fuzzel, matugen and Zsh link individual configuration files or template directories. Generated colors, lyrics caches and chat profiles live with their consumers. For another account, adjust absolute home paths in niri and the SDDM mount before linking.

1. Link the compositor configuration and portal selection. [niri guide](docs/niri.md)
2. Link the desktop shell, build its QML plugin and link the idle and lock services. [Quickshell guide](docs/quickshell.md)
3. Link matugen and `setwall`, then select a wallpaper. [Color guide](docs/colors.md)
4. Install the login theme once a wallpaper has been selected. [SDDM guide](sddm/README.md)

## Gallery and acknowledgements

[Archived desktop screenshot](assets/appearance.jpg) · [Wallpaper collection](assets/)

Thanks to [9vvert](https://github.com/9vvert) for helping set up this Arch system. The shell's blob renderer is adapted from [Caelestia](https://github.com/caelestia-dots/shell). Feel free to use and adapt these personal configurations.
