--  ▄▄▄▄▄▄
-- █▀██▀▀▀█▄
--   ██▄▄▄█▀▄             ▄▄ ▄          ▄        ▄
--   ██▀▀▀  ████▄▄███▄ ▄████ ████▄▄▀▀█▄ ███▄███▄ ███▄███▄ ▄██▀█
-- ▄ ██     ██   ██ ██ ██ ██ ██   ▄█▀██ ██ ██ ██ ██ ██ ██ ▀███▄
--▀██▀    ▄█▀  ▄▀███▀▄▀████▄█▀  ▄▀█▄██▄██ ██ ▀█▄██ ██ ▀██▄▄██▀
--                       ██
--                      ▀▀▀
Terminal = "voidline-terminal" -- Terminal emulator default
FileManager = "nautilus"  -- File manager default
-- Opens the system default web browser (xdg-settings default-web-browser).
Browser = "sh -c 'gtk4-launch \"$(xdg-settings get default-web-browser)\"'"  -- Web browser default


--  ▄▄▄                                               ▄▄▄▄▄▄▄         ▄▄
-- ▀██▀                                         █▄   █▀██▀▀▀           ██
--  ██                  ▄▄             ▄        ██     ██              ██
--  ██      ▄███▄ ▄███▄ ██ ▄█▀   ▄▀▀█▄ ████▄ ▄████     ███▀▄█▀█▄ ▄█▀█▄ ██
--  ██      ██ ██ ██ ██ ████     ▄█▀██ ██ ██ ██ ██   ▄ ██  ██▄█▀ ██▄█▀ ██
-- ████████▄▀███▀▄▀███▀▄██ ▀█▄  ▄▀█▄██▄██ ▀█▄█▀███   ▀██▀  ▀█▄▄▄▄▀█▄▄▄▄██
WindowGaps = 8 -- Gaps between windows
ScreenGaps = 20-- Gaps between windows and screen edge
BorderSize = 10 -- Border size in pixels
Activecolor = { colors = { "rgba(E2B7F4ee)", "rgba(D3C0D8ee)" }, angle = 45 } -- Active window border color (gradient)
Inactivecolor = { colors = { "rgba(161217aa)" }, angle = 45 } -- Inactive window border color
BorderResize = true -- Enable border resizing
Rounding = 15 -- Window corner rounding in pixels
Rounding_power = 3  -- Higher values make corners more circular, lower values make them more elliptical
Active_opacity = 1.0 -- Active window opacity
Inactive_opacity = 0.9 -- Inactive window opacity
Dim_inactive = true -- Dim inactive windows
Shadow_enabled = true -- Enable window shadows
Shadow_range = 32 -- Shadow footprint in pixels
Shadow_render_power = 2 -- Shadow falloff strength
Shadow_scale = 1.0 -- Shadow footprint multiplier
Shadow_color = "rgba(00000050)" -- Shadow color
Blur_enabled = true -- Enable window blur
Blur_size = 16 -- Blur size in pixels
Blur_passes = 2 -- Number of blur passes (higher values increase blur quality but reduce performance)
Blur_popups = true -- Blur menus and transient surfaces
PointerSensitivity = 0 -- Pointer speed from -1.0 to 1.0
NaturalScroll = false -- Reverse touchpad scrolling
TapToClick = true -- Touchpad tap-to-click
ScrollMethod = "2fg" -- Touchpad scroll method
KeyboardLayout = "de" -- XKB keyboard layout
RepeatRate = 25 -- Keyboard repeats per second
RepeatDelay = 600 -- Delay before repeating in milliseconds
WorkspaceSwipe = true -- Three-finger workspace gesture
Animation = "fast"  -- Animation preset to use (options: "default", "smooth", "fast", "end4", "dynamic", "high", "standard", "disabled", "classic", "moving")
require("animations." .. Animation)  -- Load the selected animation preset
