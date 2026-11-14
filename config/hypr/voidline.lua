-- Voidline integration for Hyprland (Lua config, 0.55+).
-- Loaded from hyprland.lua with:  require("voidline")
-- Everything here is safe to edit; the installer never overwrites your own
-- hyprland.lua, it only adds the require line.

-- Start the shell with the session.
hl.on("hyprland.start", function()
    hl.exec_cmd("sh ~/.config/quickshell/voidline/start.sh")
end)

-- Gaps, borders, input and Voidline's keyboard shortcuts come from Voidline
-- Settings (Keyboard shortcuts page).
pcall(require, "voidline-settings")

-- Voidline Settings opens as a centred floating window.
hl.window_rule({
    name = "voidline-settings",
    match = { title = "Voidline Settings" },
    float = 1,
    size = { 1080, 760 },
    center = 1,
})
