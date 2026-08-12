require("config") -- Load user configuration variables
--   █████████
--  ███▒▒▒▒▒███
-- ▒███    ▒███  ████████  ████████   ██████   ██████   ████████   ██████   ████████    ██████   ██████
-- ▒███████████ ▒▒███▒▒███▒▒███▒▒███ ███▒▒███ ▒▒▒▒▒███ ▒▒███▒▒███ ▒▒▒▒▒███ ▒▒███▒▒███  ███▒▒███ ███▒▒███
-- ▒███▒▒▒▒▒███  ▒███ ▒███ ▒███ ▒███▒███████   ███████  ▒███ ▒▒▒   ███████  ▒███ ▒███ ▒███ ▒▒▒ ▒███████
-- ▒███    ▒███  ▒███ ▒███ ▒███ ▒███▒███▒▒▒   ███▒▒███  ▒███      ███▒▒███  ▒███ ▒███ ▒███  ███▒███▒▒▒
-- █████   █████ ▒███████  ▒███████ ▒▒██████ ▒▒████████ █████    ▒▒████████ ████ █████▒▒██████ ▒▒██████
--▒▒▒▒▒   ▒▒▒▒▒  ▒███▒▒▒   ▒███▒▒▒   ▒▒▒▒▒▒   ▒▒▒▒▒▒▒▒ ▒▒▒▒▒      ▒▒▒▒▒▒▒▒ ▒▒▒▒ ▒▒▒▒▒  ▒▒▒▒▒▒   ▒▒▒▒▒▒
--               ▒███      ▒███
--               █████     █████
--              ▒▒▒▒▒     ▒▒▒▒▒


hl.config({
    general = {
        gaps_in  = WindowGaps,
        gaps_out = ScreenGaps,

        border_size = BorderSize,

        col = {
            active_border   = Activecolor,
            inactive_border = Inactivecolor,
        },
    },
    decoration = {
        rounding = Rounding,
        active_opacity = Active_opacity,
        inactive_opacity = Inactive_opacity,
        fullscreen_opacity = 1.0,
        rounding_power = Rounding_power,

        shadow = {
            enabled = Shadow_enabled,
            range = Shadow_range,
            render_power = Shadow_render_power,
            scale = Shadow_scale,
            color = Shadow_color,
        },

        blur = {
            enabled   = Blur_enabled,
            size      = Blur_size,
            passes    = Blur_passes,
            popups    = Blur_popups,
            new_optimizations = on,
            ignore_opacity = true,
            xray = true,
            vibrancy  = 0.1696,
        },
    },
})
