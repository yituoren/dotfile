# Quickshell

The desktop runs the custom shell in `quickshell/mine/`. The idle monitors and session lock run independently of the bar.

## Architecture

Each output has a fullscreen layer-shell `PanelWindow` in `modules/drawers/ContentWindow.qml`. It contains the bar, popups and outside-click scrim. A shared scene graph lets the `Caelestia.Blobs` C++ plugin blend the bar and popup with a cubic smooth minimum to produce the curved join. [Caelestia shell](https://github.com/caelestia-dots/shell)

The `PopupManager` singleton owns popup state. Bar and popup geometry derive from `currentPopup`, `anchorX`, `openAmount`, `triggerRelativeX`, `animatedAnchorX` and `displayWidth`.

The popup shape provides the blur region for this same surface on each animation frame. Closing the dashboard clears the region. The Arch chat panel has its own state and WebEngine surface. [Media controls, spectrum and lyrics](media.md)

## Session Lock

`Mod+Ctrl+L` and the power menu start `mine-lock.service`. The independent shell in `quickshell/mine-lock/` takes a Wayland session lock on every output and authenticates through the system PAM `login` profile. Press a key or click to reveal the empty password field. Type the password and press Enter to submit. Escape clears the field and returns to the clock.

On a fresh checkout, link the configurations and user units.

```bash
mkdir -p ~/.config/quickshell ~/.config/systemd/user
ln -s ~/.dotfiles/quickshell/mine ~/.config/quickshell/mine
ln -s ~/.dotfiles/quickshell/mine-lock ~/.config/quickshell/mine-lock
ln -s ~/.dotfiles/quickshell/mine-idle ~/.config/quickshell/mine-idle
ln -s ~/.dotfiles/quickshell/mine-idle/mine-idle.service ~/.config/systemd/user/
ln -s ~/.dotfiles/quickshell/mine-lock/systemd/*.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user start mine-sleep-lock.service
```

Quickshell IdleMonitor requests lock at five minutes, monitor power-off at ten, and suspend at fifteen. The session guard forwards logind lock requests and pauses the timers for logind idle inhibitors. The compositor handles Wayland inhibitors. The sleep guard uses system Python with PyGObject to hold a logind delay inhibitor. It releases the inhibitor when the compositor confirms the lock. The next lock loads the current wallpaper, matugen colors and QML.

## Caelestia.Blobs Plugin

`~/.dotfiles/caelestia-blobs/` contains the port of Caelestia's Blobs submodule, with five C++ sources, five headers and two GLSL shaders. It depends on Qt 6 Quick and builds independently of the rest of Caelestia.

### Build & Install

```bash
sudo pacman -S --needed quickshell cmake gcc make qt6-base qt6-shadertools qt6-declarative

cd ~/.dotfiles/caelestia-blobs
mkdir -p build && cd build
cmake ..
make -j
make install   # User installation in ~/.local/share/qt6/qml/Caelestia/Blobs/
```

Verify the installed files:

```bash
ls ~/.local/share/qt6/qml/Caelestia/Blobs/
# libcaelestia-blobs.so  libcaelestia-blobsplugin.so  qmldir  caelestia-blobs.qmltypes
```

### Iterating

Rebuild, reinstall and restart qs after changing C++ or GLSL. Quickshell loads the native library at process startup.

```bash
cd ~/.dotfiles/caelestia-blobs/build && make && make install
qs -c mine kill
QML_IMPORT_PATH="$HOME/.local/share/qt6/qml" qs -p ~/.config/quickshell/mine -d
```

When launched by niri, qs inherits `QML_IMPORT_PATH`. Set it explicitly for a manual launch.

## QML Module Path

Qt searches `/usr/lib/qt6/qml` by default. Expose the user installation under `~/.local/share/qt6/qml/` in `niri/environment.kdl`.

```kdl
QML_IMPORT_PATH "/home/yituoren/.local/share/qt6/qml"
QML2_IMPORT_PATH "/home/yituoren/.local/share/qt6/qml"
```

These values are literal. **Use the absolute home directory for the target account.** niri does not expand `$HOME` here.

## Autostart

The startup command lives in `niri/startup.kdl`.

```kdl
spawn-at-startup "qs" "-p" "/home/yituoren/.config/quickshell/mine" "-d"
```

niri starts qs with its environment, including `QML_IMPORT_PATH`. Updated startup commands run at the next niri session. Existing processes keep running.

`~/.config/quickshell/mine` links to `~/.dotfiles/quickshell/mine/`.

## Verify

```bash
# Check for a running shell.
pgrep -fa "qs.*mine"

# Check for a mine-shell surface on each output.
niri msg layers | grep mine-shell

# Read the log for the bar instance.
qs -c mine log -t 20
```

## Quickshell ABI Compatibility

After a system Qt update, an older Quickshell build may report an ABI mismatch at startup:

```
WARN: Quickshell was built against Qt 6.X but the system has updated to Qt 6.Y
```

Install a Quickshell build for the running Qt version. For a `quickshell-git` installation, rebuild with `yay -S quickshell-git`. The local `caelestia-blobs` plugin also uses the system Qt ABI.

## Hot-Reload Gotchas

- Saving QML in an editor such as Neovim or Zed triggers inotify reload.
- After an atomic file replacement, run `touch <file>` to trigger reload. The original watch may still refer to the old inode.
- For native plugin changes, follow the build and restart steps under **Iterating**.

## Chat panel

The Arch logo toggles the chat window independently of the dashboard and right-hand menus. The default width is one quarter of the output and the height is about 80%. Drag the toolbar to move it, or drag an edge or corner to resize. Each output remembers the window geometry for the shell session. The main shell preloads Cloud, controls animations and switches between Cloud and Local. A separate Quickshell host with the Qt argv patch renders the Cloud page within the panel geometry. Local starts `codex app-server` on demand with the existing Codex login, home working directory, the selected permissions profile and `on-request` approval. Enter sends and Shift+Enter inserts a newline. Responses continue when switching panels. The shell saves its thread ID and restores it with `thread/resume` after restart. `setwall` renders `chat/chat.css` from the matugen template for `https://chatgpt.com`. Sign in on first use. Cloud keeps its login cookies in the named `mine-chat` WebEngine profile. The Chrome button uses the existing browser session.

Local history lists home-directory conversations by most recent update. Search by title, load more, browse archived conversations or restore one. Type `/` for commands, use the arrow keys to select, Tab to complete, and Enter to run. Start with `//` to send a literal slash.

```text
/new                     Start a conversation
/resume [thread ID]      Browse history or open a home-directory conversation by ID
/rename title            Rename the current conversation
/fork                    Branch from the current conversation
/archive                 Archive the current conversation
/compact                 Compact the current context
/model [model ID]        Select a model for subsequent Local messages
/permissions [profile]   View or select the conversation permission profile
/effort [level]          View or set reasoning effort for the current model
/skills                  List skills available in the home directory
/mcp                     List configured MCP servers
/status                  Show account, workspace, model, effort and permissions
/stop                    Stop the current response
/help                    Show supported commands
```

Build the private launcher from the Quickshell v0.3.2 source directory with the Quickshell build dependencies installed.

```sh
patch -p1 < ~/.dotfiles/quickshell/mine/chat/quickshell-0.3.2-argv.patch
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build --target quickshell
DESTDIR="$PWD/stage" cmake --install build --prefix /usr
install -Dm755 stage/usr/bin/quickshell ~/.local/lib/mine-chat/quickshell
```
