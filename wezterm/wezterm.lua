-- Import the WezTerm module.
local wezterm = require 'wezterm'
-- Create a configuration builder for recent WezTerm versions.
local config = wezterm.config_builder()

config.automatically_reload_config = true
config.enable_wayland = true

-- =========================================================
-- Appearance
-- =========================================================

-- 1. Color scheme
-- Read matugen colors.json to follow the wallpaper. Fall back to Tokyo Night if unavailable.
-- Use the same palette when launched from a shell, fuzzel or a desktop entry.
local matugen_colors_path = os.getenv('HOME') .. '/.local/state/quickshell/user/generated/colors.json'

local function load_matugen_colors(path)
    local f = io.open(path, 'r')
    if not f then return nil end
    local content = f:read('*a'); f:close()
    local ok, parsed = pcall(wezterm.json_parse, content)
    if not ok or not parsed then return nil end
    -- Keep the mapping in sync with ~/.dotfiles/scripts/setwall.sh and .zshrc.
    return {
        background = parsed.background,
        foreground = parsed.on_background,
        cursor_bg  = parsed.primary,
        cursor_fg  = parsed.on_primary,
        cursor_border = parsed.primary,
        selection_bg = parsed.secondary_container,
        selection_fg = parsed.on_secondary_container,
        ansi = {
            parsed.surface_container_lowest or parsed.background, -- black
            parsed.error,                                          -- red
            parsed.tertiary,                                       -- green
            parsed.secondary,                                      -- yellow
            parsed.primary,                                        -- blue
            parsed.tertiary_container,                             -- magenta
            parsed.primary_container,                              -- cyan
            parsed.on_surface,                                     -- white
        },
        brights = {
            parsed.surface_container_low or parsed.surface,        -- bright black
            parsed.error_container,                                -- bright red
            parsed.on_tertiary_container or parsed.tertiary,       -- bright green
            parsed.on_secondary_container or parsed.secondary,     -- bright yellow
            parsed.on_primary_container or parsed.primary,         -- bright blue
            parsed.tertiary_fixed or parsed.tertiary,              -- bright magenta
            parsed.primary_fixed or parsed.primary,                -- bright cyan
            parsed.inverse_surface or parsed.on_background,        -- bright white
        },
    }
end

local matugen = load_matugen_colors(matugen_colors_path)
if matugen then
    config.colors = matugen
else
    config.color_scheme = 'Tokyo Night (Gogh)'
end

-- Watch colors.json and reload after setwall changes the wallpaper.
wezterm.add_to_config_reload_watch_list(matugen_colors_path)

-- 2. Fonts
-- Install a Nerd Font first (for example, sudo pacman -S ttf-jetbrains-mono-nerd).
config.font = wezterm.font('Maple Mono NF CN', { weight = 'Bold' })
config.font_size = 12.5
config.cell_width = 1.1

-- 3. Window opacity
config.window_background_opacity = 0.85 -- Range 0.0 to 1.0. Lower values are more transparent.

-- 4. Window decorations
-- RESIZE allows resizing from the edges without a title bar.
-- config.window_decorations = "RESIZE"

-- 5. Tab bar
-- config.use_fancy_tab_bar = false -- Disable the fancy tab bar for the compact classic layout.
-- config.hide_tab_bar_if_only_one_tab = true -- Hide the tab bar when only one tab is open.
config.enable_tab_bar = false

config.default_cursor_style = 'SteadyBar'

-- =========================================================
-- Performance and graphics
-- =========================================================
-- Use a GPU-accelerated frontend such as WebGpu or OpenGL.
-- Use OpenGL to avoid black screens and lost input with WebGpu under niri/wlroots.
config.front_end = "OpenGL"

-- =========================================================
-- Tmux-style key bindings
-- =========================================================
-- Use Ctrl+a as the leader, like a tmux prefix.
-- config.leader = { key = 'd', mods = 'ALT', timeout_milliseconds = 2000}

config.keys = {
    -- 1. Split vertically.
    {
        key = ',',
        mods = 'ALT',
        action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
    },
    -- 2. Split horizontally.
    {
        key = '.',
        mods = 'ALT',
        action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
    },
    -- 3. Close the current pane.
    {
        key = 'd',
        mods = 'ALT',
        action = wezterm.action.CloseCurrentPane { confirm = true },
    },
    -- 4. Move between panes.
    { key = 'LeftArrow',  mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Left' },
    { key = 'RightArrow', mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Right' },
    { key = 'UpArrow',    mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Up' },
    { key = 'DownArrow',  mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Down' },

    { key = 'c',          mods = 'ALT', action = wezterm.action.CopyTo 'Clipboard' },
    { key = 'v',          mods = 'ALT', action = wezterm.action.PasteFrom 'Clipboard' },
}

-- =========================================================
-- Other settings
-- =========================================================
-- Let the Arch package manager handle updates.
config.check_for_updates = false
-- Disable the audible bell.
config.audible_bell = "Disabled"

return config
