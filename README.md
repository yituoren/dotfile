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
    <a href="#setup">🛠️ Setup</a> •
    <a href="#thanks">❤️ Acknowledgements</a>
  </p>
</div>

<br />

> My bar, dashboard and lock screen share the colors of the current wallpaper. The dashboard brings together music, weather and the calendar. The Arch logo opens my chat panel.
>
> **⭐ If you find this helpful, please consider giving this repo a star!**

---

<a name="gallery"></a>

## 🖼️ **Gallery**

<div align="center">
  <img src="assets/appearance.jpg" alt="My earlier Hyprland desktop" width="100%" style="border-radius: 8px; box-shadow: 0 4px 8px rgba(0,0,0,0.1);">
  <br>
  <i>From my Hyprland setup, before the move to niri. <a href="assets/wallpaper.jpg">View wallpaper</a>.</i>
</div>

---

<a name="components"></a>

## 🧩 **Components**

### 🖥️ **Window Manager**

| Component | Software | Role |
| :--- | :--- | :--- |
| **[Compositor](docs/niri.md)** | [niri](https://github.com/YaLTeR/niri) | Scrolling window layout, workspaces and overview |
| **[Desktop Shell](docs/quickshell.md)** | [Quickshell](https://quickshell.org/) · [Qt Quick](https://doc.qt.io/qt-6/qtquick-index.html) | Per-display bar, dashboard and popup menus |
| **[Popup Renderer](caelestia-blobs/)** | [Caelestia.Blobs](https://github.com/caelestia-dots/shell) | Local adaptation that joins the bar and popup into one shape |
| **[Wallpaper & Colors](docs/colors.md)** | [awww](https://codeberg.org/LGFae/awww) · [matugen](https://github.com/InioX/matugen) · [jq](https://jqlang.org/) | Display the wallpaper · extract its palette · update terminal colors |
| **[Login Screen](sddm/README.md)** | [SDDM](https://github.com/sddm/sddm) · [ImageMagick](https://imagemagick.org/) | Qt greeter with a blurred copy of the wallpaper |
| **[Lock & Idle](docs/quickshell.md#session-lock)** | [Quickshell](https://quickshell.org/) · [systemd-logind](https://www.freedesktop.org/software/systemd/man/latest/systemd-logind.service.html)<br>[PyGObject](https://pygobject.gnome.org/) · [Linux-PAM](https://github.com/linux-pam/linux-pam) | Lock at 5 min · screen off at 10 min · suspend at 15 min<br>Lock before sleep and authenticate on return |

### 🎛️ **Shell Feature**

| Component | Software | Role |
| :--- | :--- | :--- |
| **[Media Playback](docs/media.md)** | [MPRIS](https://specifications.freedesktop.org/mpris/latest/interfaces.html) · [playerctl](https://github.com/altdesktop/playerctl)<br>[Plasma Browser Integration](https://invent.kde.org/plasma/plasma-browser-integration) | Desktop player metadata and playback controls<br>Optional per-tab selection in Chrome |
| **[Lyrics](docs/media.md#lyrics)** | [LRCLIB](https://lrclib.net/) · [NetEase Cloud Music](https://music.163.com/) | Look up lyrics when the player omits them |
| **[Audio Spectrum](quickshell/mine/cava.conf)** | [CAVA](https://github.com/karlstav/cava) | Live spectrum under the bar and around the album cover |
| **[Weather](quickshell/mine/services/Weather.qml)** | [GeoClue](https://gitlab.freedesktop.org/geoclue/geoclue) · [curl](https://curl.se/) · [Python](https://www.python.org/)<br>[Open-Meteo](https://open-meteo.com/) · [NMC](https://www.nmc.cn/) | Location and forecast retrieval<br>NMC station fallback |
| **[Calendar](quickshell/mine/services/Tasks.qml)** | [Taskwarrior](https://taskwarrior.org/) | View and edit tasks by due date |
| **[App Search](quickshell/mine/modules/drawers/AppSearch.qml)** | [gtk-launch](https://github.com/GNOME/gtk/blob/gtk-3-24/gtk/gtk-launch.c) · [WezTerm](https://wezterm.org/) | Launch desktop entries and terminal apps |
| **[System Monitor](quickshell/mine/services/SysMonitor.qml)** | [Linux procfs & sysfs](https://docs.kernel.org/filesystems/) · [GNU df](https://www.gnu.org/software/coreutils/manual/html_node/df-invocation.html)<br>[NVIDIA SMI](https://docs.nvidia.com/deploy/nvidia-smi/) | CPU, memory, network and disk usage<br>GPU readings where available |
| **[Chat Panel](docs/quickshell.md#chat-panel)** | [ChatGPT](https://chatgpt.com/) · [Qt WebEngine](https://doc.qt.io/qt-6/qtwebengine-index.html)<br>[Codex CLI](https://github.com/openai/codex) | Cloud chat with a persistent login<br>Local conversations in the home directory |

### 🔌 **Desktop Integrations**

| Component | Software | Role |
| :--- | :--- | :--- |
| **[Audio](docs/media.md)** | [PipeWire](https://pipewire.org/) · [WirePlumber](https://pipewire.pages.freedesktop.org/wireplumber/) · [pipewire-pulse](https://docs.pipewire.org/page_man_pipewire-pulse_1.html)<br>[EasyEffects](https://github.com/wwmm/easyeffects) | Volume, mute and output selection<br>Optional audio effects |
| **[Wi-Fi & Bluetooth](quickshell/mine/services/SystemStatus.qml)** | [NetworkManager](https://networkmanager.dev/) · [plasma-nm](https://invent.kde.org/plasma/plasma-nm)<br>[BlueZ](https://www.bluez.org/) · [BlueDevil](https://invent.kde.org/plasma/bluedevil) | Wi-Fi connections and network settings<br>Bluetooth devices and pairing |
| **[Brightness](quickshell/mine/services/SystemStatus.qml)** | [brightnessctl](https://github.com/Hummer12007/brightnessctl) · [ddcutil](https://www.ddcutil.com/) | Internal backlight and external DDC/CI monitors |
| **[Launcher & Clipboard](docs/fuzzel.md)** | [fuzzel](https://codeberg.org/dnkl/fuzzel) · [cliphist](https://github.com/sentriz/cliphist) · [wl-clipboard](https://github.com/bugaevc/wl-clipboard) | Application launcher and clipboard history |
| **[Terminals](docs/wezterm.md)** | [WezTerm](https://wezterm.org/) · [Kitty](https://sw.kovidgoyal.net/kitty/) | Primary and secondary terminal emulators |
| **[Shell & Prompt](docs/zsh.md)** | [Zsh](https://www.zsh.org/) · [Zimfw](https://zimfw.sh/) · [Powerlevel10k](https://github.com/romkatv/powerlevel10k) · [eza](https://eza.rocks/) | Interactive shell, modules, prompt and file listings |
| **[File Managers](docs/yazi.md)** | [Yazi](https://yazi-rs.github.io/) · [Dolphin](https://apps.kde.org/dolphin/) | Terminal and graphical file browsing |
| **Editor & Browser** | [Zed](https://zed.dev/) · [Google Chrome](https://www.google.com/chrome/) | Code editing and web browsing |
| **[Input Method](niri/environment.kdl)** | [Fcitx5](https://fcitx-im.org/wiki/Fcitx_5) · [Rime](https://rime.im/) · [Rime-Ice](https://github.com/iDvel/rime-ice)<br>[Autumn](https://github.com/thep0y/fcitx5-themes-candlelight/tree/main/autumn) | Chinese Pinyin input and candidate window theme |
| **[Fonts & Symbols](docs/colors.md)** | [Maple Mono NF CN](https://github.com/subframe7536/maple-font) · [Google Sans Flex](https://design.google/library/google-sans-flex-font)<br>[Material Symbols Rounded](https://fonts.google.com/icons) | Terminal, launcher and GTK text<br>Shell icons |
| **[Desktop Theme](matugen/templates/kde/MineDesktop.colors)** | [Darkly](https://github.com/Bali10050/darkly) · [Breeze Plus](https://github.com/mjkim0727/breeze-plus) · [Bibata Modern Classic](https://github.com/ful1e5/Bibata_Cursor) | KDE widgets, application icons and pointer |
| **[Portals](xdg-desktop-portal/niri-portals.conf)** | [xdg-desktop-portal-gtk](https://github.com/flatpak/xdg-desktop-portal-gtk) · [GNOME Keyring](https://gitlab.gnome.org/GNOME/gnome-keyring) | File dialogs and secret storage |
| **Screen Tools** | [niri](https://github.com/YaLTeR/niri) · [slurp](https://github.com/emersion/slurp) · [grim](https://gitlab.freedesktop.org/emersion/grim) · [Tesseract](https://github.com/tesseract-ocr/tesseract) | Screenshots, color picking and region OCR |
| **[Proxy](clash-verge/config.yaml)** | [Clash Verge Rev](https://github.com/clash-verge-rev/clash-verge-rev) · [Mihomo](https://github.com/MetaCubeX/mihomo) | Local VLESS profile with IPv6 and IPv4 nodes<br>Fill in provider details before importing the template |

---

<a name="setup"></a>

## 🛠️ **Setup**

The checkout lives at `~/.dotfiles`. For another account, adjust the absolute home paths in niri and the SDDM mount before linking the files.

1. Link the compositor configuration and portal preferences. [niri guide](docs/niri.md)
2. Build the QML plugin and link the shell, idle and lock services. [Quickshell guide](docs/quickshell.md)
3. Link matugen and select a wallpaper with `setwall`. [Color guide](docs/colors.md)
4. Install the login theme after selecting a wallpaper. [SDDM guide](sddm/README.md)

---

<a name="thanks"></a>

## ❤️ **Special Thanks**

A huge shoutout to **9vvert** for his patience, guidance, and invaluable help during the installation and configuration of my Arch Linux system. This setup wouldn't be possible without his support.

- 👨‍💻 **GitHub**: [9vvert](https://github.com/9vvert)
- 🌐 **Website**: [9vvert.github.io](https://9vvert.github.io/)

The bar’s blob renderer is adapted from the [Caelestia shell](https://github.com/caelestia-dots/shell).

---

## 📄 **License**

Feel free to use and modify these configurations. A star back to the original repo would be appreciated!
