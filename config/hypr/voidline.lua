-- Voidline integration for Hyprland (Lua config, 0.55+).
-- Loaded from hyprland.lua with:  require("voidline")
-- Everything here is safe to edit; the installer never overwrites your own
-- hyprland.lua, it only adds the require line.

local function shell(...)
    return hl.dsp.exec_cmd("qs -c voidline ipc call shell " .. table.concat({ ... }, " "))
end

-- Start the shell with the session.
hl.on("hyprland.start", function()
    hl.exec_cmd("qs -c voidline")
end)

-- Shell keybinds
hl.bind("SUPER + SPACE", shell("toggle", "launcher"))
hl.bind("SUPER + A", shell("toggle", "quick"))
hl.bind("SUPER + N", shell("minimize"))            -- minimise focused window
hl.bind("SUPER + SHIFT + N", shell("restore"))     -- bring back the last one
hl.bind("SUPER + ALT + S", shell("style", "next")) -- Voidline -> Windows -> macOS

-- Minimised windows live on this hidden workspace. Peek at all of them:
hl.bind("SUPER + CTRL + N", hl.dsp.workspace.toggle_special("minimized"))

-- Adaptive sync on capable displays.
hl.config({
    misc = {
        vrr = 1,
    },
})
