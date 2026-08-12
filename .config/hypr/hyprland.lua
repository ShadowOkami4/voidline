--____   ____    .__    .___.__  .__
--\   \ /   /___ |__| __| _/|  | |__| ____   ____
-- \   Y   /  _ \|  |/ __ | |  | |  |/    \_/ __ \
--  \     (  <_> )  / /_/ | |  |_|  |   |  \  ___/
--   \___/ \____/|__\____ | |____/__|___|  /\___  >
--                       \/              \/     \/

-- Welcome to Voidline - Hyprland Configuration
-- This is the main entry point. All settings are modularized in defaults/


local monitorRules = require("monitors")
for _, monitor in pairs(monitorRules) do
    if monitor.enabled == false then
        hl.monitor({
            output = monitor.output,
            mode = "disabled",
        })
    else
        hl.monitor({
            output = monitor.output,
            mode = monitor.mode,
            position = monitor.position,
            scale = monitor.scale,
            transform = monitor.transform,
            vrr = monitor.vrr,
            mirror = monitor.mirror ~= "none" and monitor.mirror or nil,
            cm = monitor.color_profile,
        })
    end
end

hl.on("hyprland.start", function() -- Execute commands on Hyprland start
    hl.exec_cmd("systemctl --user start voidline-shell.service")
end)
hl.env ("XCURSOR_SIZE", 24) -- Set cursor size for X applications
hl.env ("HYPRCURSOR_SIZE", 24) -- Set cursor size for Hyprland native applications


require("defaults.keybinds")    -- Load keybindings
require("defaults.lookandfeel") -- Load appearance settings
require("defaults.rules")   -- Load window rules
require("input") -- Load input configuration (e.g., touchpad, mouse)
