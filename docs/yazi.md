# Yazi Configuration Guide

## Installation

```bash
sudo pacman -S --needed yazi
# Optional preview, search and archive tools
sudo pacman -S --needed ffmpeg 7zip jq poppler fd ripgrep fzf zoxide resvg imagemagick
```

| Dependency | Purpose |
|---|---|
| `ffmpeg` | Audio and video thumbnails |
| `7zip` | Pack and unpack 7z, ZIP and RAR archives |
| `jq` | JSON preview |
| `poppler` | PDF preview |
| `fd` | Filename search (`s`) |
| `ripgrep` | Content search (`S`) |
| `fzf` | Fuzzy jump (`Z`) |
| `zoxide` | Directory jump (`z`) |
| `resvg` | SVG preview |
| `imagemagick` | Other image previews |

## Default File Manager

```bash
# Make yazi.desktop the handler for directories.
xdg-mime default yazi.desktop inode/directory
```

The niri `Mod+E` binding lives in `~/.dotfiles/niri/binds.kdl`.

```kdl
Mod+E { spawn "wezterm" "start" "--class" "yazi" "--" "yazi"; }
```

## Key Bindings

### Navigation

| Key | Action |
|---|---|
| `h` / `j` / `k` / `l` or arrows | Parent / down / up / enter |
| `gg` / `G` | First / last item |
| `Ctrl+u` / `Ctrl+d` | Half a page up / down |
| `Ctrl+b` / `Ctrl+f` | Full page up / down |
| `K` / `J` | Scroll the preview |
| `Tab` | Toggle peek size |

### Selection

| Key | Action |
|---|---|
| `Space` | Toggle selection of the current item |
| `v` / `V` | Visual selection / invert visible selection |
| `Ctrl+a` / `Ctrl+r` | Select all / invert all |
| `Esc` | Clear selection or leave the mode |

### File Operations

| Key | Action |
|---|---|
| `y` / `x` / `p` | Copy / cut / paste |
| `P` | Paste and overwrite |
| `d` / `D` | Move to trash / **delete permanently** |
| `a` | Create an entry. A trailing `/` creates a directory. |
| `r` | Rename |
| `;` / `:` | Nonblocking / blocking shell |

### Open and Jump

| Key | Action |
|---|---|
| `Enter` / `o` | Open with the default application |
| `O` | Choose an application |
| `z` / `Z` | Jump with zoxide / fzf |
| `:cd <path>` | Go to a path |

### Search

| Key | Action |
|---|---|
| `f` / `F` | Find a name in the current directory / previous match |
| `s` / `S` | Search filenames with fd / contents with ripgrep |
| `/` / `n` / `N` | Enter a search / next match / previous match |

### Tabs and Bookmarks

| Key | Action |
|---|---|
| `t` / `T` | Create / close a tab |
| `1`–`9` | Select a tab by number |
| `[` / `]` | Previous / next tab |
| `{` / `}` | Move the current tab left / right |
| `m` / `'` + letter | Set / jump to a bookmark |
| `b` / `B` | List / delete bookmarks |

### Sorting, Display and Other Actions

| Key | Action |
|---|---|
| `,` | Sort menu |
| `.` / `-` | Toggle hidden files |
| `w` | Task manager |
| `Ctrl+n` / `Ctrl+d` / `Ctrl+c` | Drag out / follow symlink / copy path |
| `q` / `Q` | Quit and save / discard the working directory |
| `?` | Show help for the current key bindings |

## Shell Integration

Add this function to `.zshrc` to stay in Yazi's last directory after quitting.

```zsh
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}
```

Launch with `y` to use the directory-changing wrapper.

## Configuration Files

| File | Purpose |
|---|---|
| `~/.config/yazi/yazi.toml` | Main configuration |
| `~/.config/yazi/keymap.toml` | Key bindings |
| `~/.config/yazi/theme.toml` | Colors |
| `~/.config/yazi/init.lua` | Startup script and plugins |
