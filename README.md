<div align="center">
  <img src="assets/wallpaper.jpg" alt="Wallpaper from my Arch Linux desktop" width="100%" style="object-fit: cover; border-radius: 10px;">

  <h1 align="center">My Arch Linux Dotfiles</h1>

  <p align="center">
    <strong>A scrolling desktop built with niri and a custom Quickshell.</strong>
  </p>

  <p align="center">
    <img src="https://img.shields.io/badge/Arch%20Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white" alt="Arch Linux" />
    <img src="https://img.shields.io/badge/niri-00A4A6?style=for-the-badge" alt="niri" />
    <img src="https://img.shields.io/badge/Quickshell-584972?style=for-the-badge" alt="Quickshell" />
    <img src="https://img.shields.io/badge/WezTerm-3C2C46?style=for-the-badge&logo=wezterm&logoColor=white" alt="WezTerm" />
    <img src="https://img.shields.io/badge/Zsh-F15A24?style=for-the-badge&logo=zsh&logoColor=white" alt="Zsh" />
  </p>

  <p align="center">
    <a href="#gallery">🖼️ Gallery</a> •
    <a href="#components">🧩 Components</a> •
    <a href="#thanks">❤️ Acknowledgements</a>
  </p>
</div>

<br />

> My bar, dashboard and lock screen share the colors of the current wallpaper. Click the center of the bar for music, weather and the calendar, or the Arch logo for chat. Press **Super + /** to explore the shortcuts.
>
> **⭐ If you find this helpful, please consider giving this repo a star!**

---

<a name="gallery"></a>

## 🖼️ Gallery

<div align="center">
  <img src="assets/appearance.jpg" alt="My earlier Hyprland desktop" width="100%" style="border-radius: 8px; box-shadow: 0 4px 8px rgba(0,0,0,0.1);">
  <br>
  <i>From my Hyprland setup, before the move to niri. <a href="assets/wallpaper.jpg">View wallpaper</a>.</i>
</div>

---

<a name="components"></a>

## 🧩 Components

### 🖥️ Window Manager & Desktop

| Component | Software | Configuration |
| :--- | :--- | :--- |
| Compositor | **niri** scrolls and tiles windows, manages workspaces and provides the overview. | [niri guide](docs/niri.md) |
| Bar & dashboard | **Quickshell** hosts the panels. **Caelestia.Blobs** draws the curved join between the bar and its menus. | [Shell guide](docs/quickshell.md) |
| Wallpaper & colors | **awww** displays the image. **matugen** extracts its palette for the shell, terminals, GTK and KDE. | [Color guide](docs/colors.md) |
| Login & lock | **SDDM** shows the login screen. **Quickshell** handles locking and idle timers in the running session. | [Login theme](sddm/README.md) · [Session lock](docs/quickshell.md#session-lock) |
| Launcher & clipboard | **fuzzel** opens apps with `Super+Space`. **cliphist** and **wl-clipboard** provide history on `Super+V`. | [Launcher guide](docs/fuzzel.md) |

<details>
<summary><strong>Shell features</strong> · media, weather, tasks and chat</summary>

| Feature | What powers it |
| :--- | :--- |
| Playback | **MPRIS** supplies track details and transport controls. The hardware media keys use **playerctl**. **Plasma Browser Integration** adds per-tab selection in Chrome when available. [Media guide](docs/media.md) |
| Lyrics & spectrum | The shell checks the player's lyrics first, then queries **LRCLIB** and **NetEase Cloud Music**. **CAVA** drives the spectrum under the bar and around the album cover. [Lyrics](docs/media.md#lyrics) · [Spectrum settings](quickshell/mine/cava.conf) |
| Weather | **GeoClue** or IP geolocation supplies coordinates. **curl** fetches the **Open-Meteo** forecast, with **NMC** station data as a fallback. [Weather service](quickshell/mine/services/Weather.qml) |
| Calendar & app search | **Taskwarrior** supplies dated tasks. **gtk-launch** opens graphical desktop entries, while terminal apps open in WezTerm. [Tasks](quickshell/mine/services/Tasks.qml) · [App search](quickshell/mine/modules/drawers/AppSearch.qml) |
| System monitor | Linux **procfs**, **sysfs** and **df** supply system metrics. **nvidia-smi** adds GPU readings when available. [Monitor](quickshell/mine/services/SysMonitor.qml) |
| Chat | The Arch logo opens **ChatGPT** in a persistent **Qt WebEngine** profile or the local **Codex CLI** in the home directory. [Chat panel](docs/quickshell.md#chat-panel) |

</details>

<details>
<summary><strong>Desktop integrations</strong> · devices, appearance and session services</summary>

| Feature | What powers it |
| :--- | :--- |
| Audio | **PipeWire** carries audio, **WirePlumber** provides `wpctl` for volume and mute, and `pactl` selects outputs through **pipewire-pulse**. **EasyEffects** starts when installed. [Audio controls](docs/media.md) |
| Wi-Fi & Bluetooth | **NetworkManager** (`nmcli`) and **BlueZ** (`bluetoothctl`) drive the menus. **plasma-nm** opens network settings and **BlueDevil** handles pairing. [Device controls](quickshell/mine/services/SystemStatus.qml) |
| Displays | **brightnessctl** adjusts the internal backlight. **ddcutil** adjusts external monitors that support DDC/CI. [Brightness controls](quickshell/mine/services/SystemStatus.qml) |
| Look & feel | **Maple Mono NF CN** for terminals and fuzzel, **Material Symbols Rounded** for shell icons and **Bibata Modern Classic** for the pointer. GTK uses **Google Sans Flex**. KDE uses **Darkly** and **Breeze Plus** icons. [Color scheme](matugen/templates/kde/MineDesktop.colors) |
| Wallpaper sync | `setwall` uses **jq** to read terminal colors and **ImageMagick** to prepare a blurred wallpaper for the greeter. [Wallpaper script](scripts/setwall.sh) |
| Idle & authentication | **Quickshell IdleMonitor** locks at 5 minutes, powers off displays at 10 and suspends at 15. **systemd-logind** and a **PyGObject** service coordinate locking before sleep. **PAM** verifies the password. [Lock and idle setup](docs/quickshell.md#session-lock) |
| Portals | **xdg-desktop-portal-gtk** provides file dialogs. **GNOME Keyring** handles the Secret portal. [Portal preferences](xdg-desktop-portal/niri-portals.conf) |
| Screen tools | **niri** takes screenshots and picks colors. **slurp**, **grim** and **Tesseract** copy text from a selected region. [Bindings](niri/binds.kdl) |
| Proxy | **Clash Verge** provides the local proxy. The Zsh functions `start_proxy` and `stop_proxy` toggle it for the current shell. [Proxy configuration](clash-verge/config.yaml) |

</details>

### 🚀 Terminal & Shell

| Component | Software | Configuration |
| :--- | :--- | :--- |
| Terminal | **WezTerm** on `Super+Enter`, **Kitty** on `Super+T` | [WezTerm](docs/wezterm.md) · [Kitty](docs/kitty.md) |
| Shell & prompt | **Zsh** with **Zimfw**, **Powerlevel10k** and **eza** | [Zsh guide](docs/zsh.md) |
| File manager | **Yazi** in WezTerm on `Super+E`. **Dolphin** is also available. | [Yazi guide](docs/yazi.md) |
| Editor & browser | **Zed** on `Super+C`, **Google Chrome** on `Super+W` | [Bindings](niri/binds.kdl) |

### ⌨️ Input Method (IME)

| Component | Software |
| :--- | :--- |
| Framework & engine | [Fcitx5](https://github.com/fcitx/fcitx5) with [Rime](https://github.com/fcitx/fcitx5-rime) |
| Pinyin schema | [Rime-Ice](https://github.com/iDvel/rime-ice) (雾凇拼音) |
| Theme | Autumn, installed in the user account |

<details>
<summary><strong>Setting up this checkout</strong></summary>

The checkout lives at `~/.dotfiles`. For another account, adjust the absolute home paths in niri and the SDDM mount before linking the files.

1. Link the compositor configuration and portal preferences. [niri](docs/niri.md)
2. Build the QML plugin and link the shell, idle and lock services. [Quickshell](docs/quickshell.md)
3. Link matugen and select a wallpaper with `setwall`. [Wallpaper and colors](docs/colors.md)
4. Install the login theme once the wallpaper has been selected. [SDDM](sddm/README.md)

</details>

---

<a name="thanks"></a>

## ❤️ Special Thanks

A huge shoutout to **9vvert** for his patience, guidance, and invaluable help during the installation and configuration of my Arch Linux system. This setup wouldn't be possible without his support.

- 👨‍💻 **GitHub**: [9vvert](https://github.com/9vvert)
- 🌐 **Website**: [9vvert.github.io](https://9vvert.github.io/)

The bar’s blob renderer is adapted from the [Caelestia shell](https://github.com/caelestia-dots/shell).

---

## 📄 License

Feel free to use and modify these configurations. A star back to the original repo would be appreciated!
