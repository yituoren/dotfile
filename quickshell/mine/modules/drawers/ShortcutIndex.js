// Read the section headings, key chords and overlay titles from niri/binds.kdl.
const keyNames = {
    Mod: "Super", Return: "Enter", Slash: "/", Minus: "−", Equal: "=", Comma: ",", Period: ".",
    Left: "←", Right: "→", Up: "↑", Down: "↓", BracketLeft: "[", BracketRight: "]",
    Page_Up: "PgUp", Page_Down: "PgDn", WheelScrollUp: "Wheel ↑", WheelScrollDown: "Wheel ↓",
    XF86AudioRaiseVolume: "Vol +", XF86AudioLowerVolume: "Vol −", XF86AudioMute: "Mute",
    XF86AudioMicMute: "Mic mute", XF86MonBrightnessUp: "Brightness +", XF86MonBrightnessDown: "Brightness −",
    XF86AudioPlay: "Play / pause", XF86AudioNext: "Next track", XF86AudioPrev: "Previous track"
}

function read(source) {
    const rows = []
    let section = "Desktop"
    // A binding starts with its chord. Read through the opening brace to the
    // first action, leaving shell command strings (which may contain braces) alone.
    const pattern = /^\s*\/\/ ---- (.+?) ----\s*$|^[ \t]*([\w+.-]+)[ \t]+([^{}\n]*)\{\s*([\w-]+)\s*([^;\n}]*)/gm
    let m
    while ((m = pattern.exec(source)) !== null) {
        if (m[1]) { section = m[1]; continue }
        if (m[2] === "binds") continue
        const title = /hotkey-overlay-title="((?:\\.|[^"\\])*)"/.exec(m[3])
        if (/hotkey-overlay-title=null/.test(m[3])) continue
        const params = m[5].trim().replace(/"/g, "").replace(/\s+focus=false$/, "")
        const description = title ? JSON.parse('"' + title[1] + '"')
            : (m[4].replace(/-/g, " ") + (params ? " " + params : ""))
        const keys = m[2].split("+").map(k => keyNames[k] ?? k)
        rows.push({ section, keys, label: description[0].toUpperCase() + description.slice(1),
                    search: [section, m[2], keys.join("+"), description].join(" ").toLowerCase() })
    }
    return rows
}
