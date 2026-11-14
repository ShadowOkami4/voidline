-- Voidline integration for Hyprland (Lua config, 0.55+).
-- Loaded from hyprland.lua with:  require("voidline")
-- Everything here is safe to edit; the installer never overwrites your own
-- hyprland.lua, it only adds the require line.

-- Start the shell with the session.
hl.on("hyprland.start", function()
    hl.exec_cmd("sh ~/.config/quickshell/voidline/start.sh")
end)

-- If the shell ever stops while the screen is locked, a restarted shell may
-- take the lock over again instead of leaving the session stuck.
hl.config({ misc = { allow_session_lock_restore = true } })

-- Gaps, borders, input and Voidline's keyboard shortcuts come from Voidline
-- Settings (Keyboard shortcuts page).
pcall(require, "voidline-settings")

hl.window_rule({
    name = "voidline-welcome",
    match = { title = "Welcome to Voidline" },
    float = 1,
    size = { 760, 720 },
    center = 1,
})

-- Voidline Settings opens as a centred floating window.
hl.window_rule({
    name = "voidline-settings",
    match = { title = "Voidline Settings" },
    float = 1,
    size = { 1080, 760 },
    center = 1,
})
