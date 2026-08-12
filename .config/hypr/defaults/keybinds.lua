require("config") -- Load user configuration variables
--█████   ████                     █████      ███                 █████
--▒▒███   ███▒                     ▒▒███      ▒▒▒                 ▒▒███
--▒███  ███     ██████  █████ ████ ▒███████  ████  ████████    ███████   █████
--▒███████     ███▒▒███▒▒███ ▒███  ▒███▒▒███▒▒███ ▒▒███▒▒███  ███▒▒███  ███▒▒
--▒███▒▒███   ▒███████  ▒███ ▒███  ▒███ ▒███ ▒███  ▒███ ▒███ ▒███ ▒███ ▒▒█████
--▒███ ▒▒███  ▒███▒▒▒   ▒███ ▒███  ▒███ ▒███ ▒███  ▒███ ▒███ ▒███ ▒███  ▒▒▒▒███
--█████ ▒▒████▒▒██████  ▒▒███████  ████████  █████ ████ █████▒▒████████ ██████
--▒▒▒▒▒   ▒▒▒▒  ▒▒▒▒▒▒    ▒▒▒▒▒███ ▒▒▒▒▒▒▒▒  ▒▒▒▒▒ ▒▒▒▒ ▒▒▒▒▒  ▒▒▒▒▒▒▒▒ ▒▒▒▒▒▒
--                        ███ ▒███
--                      ▒▒██████
--                        ▒▒▒▒▒▒


--░█▀█░█▀▄░█▀█░█▀▀░█▀█░█▄█░█▄█░█▀▀
--░█▀▀░█▀▄░█░█░█░█░█▀█░█░█░█░█░▀▀█
--░▀░░░▀░▀░▀▀▀░▀▀▀░▀░▀░▀░▀░▀░▀░▀▀▀
--#Program launch bindings and window close
hl.bind("SUPER + T", hl.dsp.exec_cmd(Terminal))
hl.bind("SUPER + B", hl.dsp.exec_cmd(Browser))
hl.bind("SUPER + E", hl.dsp.exec_cmd(FileManager))
local closeWindowBind = hl.bind("SUPER + SHIFT + Q", hl.dsp.window.close())
--░█▀▄░█▀▀░█▀▀░█░█░▀█▀░█▀█░█▀█
--░█░█░█▀▀░▀▀█░█▀▄░░█░░█░█░█▀▀
--░▀▀░░▀▀▀░▀▀▀░▀░▀░░▀░░▀▀▀░▀░░
hl.bind("SUPER + SPACE",hl.dsp.global("quickshell:toggleLauncher"))
hl.bind("SUPER + I",hl.dsp.global("quickshell:toggleSettings"))
hl.bind("SUPER + TAB",hl.dsp.global("quickshell:toggleOverview"))
hl.bind("CTRL + ALT + DELETE",hl.dsp.global("quickshell:togglePowerMenu"))
hl.bind("SUPER + PERIOD",hl.dsp.global("quickshell:openClipboardSymbols"))
hl.bind("SUPER + V",hl.dsp.global("quickshell:openClipboardHistory"))
hl.bind("SUPER + A",hl.dsp.global("quickshell:openActionCenter"))
hl.bind("SUPER + Q",hl.dsp.global("quickshell:openFileSearch"))
hl.bind("SUPER + MINUS",hl.dsp.global("quickshell:toggleCheatsheet"))
hl.bind("PRINT",
    hl.dsp.exec_cmd("voidlinectl screenshot screen"))
hl.bind("SUPER + SHIFT + S",
    hl.dsp.exec_cmd("voidlinectl screenshot region"))
hl.bind("SUPER + SHIFT + C",
    hl.dsp.exec_cmd("voidlinectl color-picker"))
--░█░█░█░█░█▀█░█▀▄░█░░░█▀█░█▀█░█▀▄
--░█▀█░░█░░█▀▀░█▀▄░█░░░█▀█░█░█░█░█
--░▀░▀░░▀░░▀░░░▀░▀░▀▀▀░▀░▀░▀░▀░▀▀░
--#hyprland specific
hl.bind("SUPER + P", hl.dsp.window.pseudo())
hl.bind("SUPER + J", hl.dsp.layout("togglesplit"))
hl.bind("SUPER + L",hl.dsp.global("quickshell:lockScreen"))
hl.bind("SUPER + M",
    hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl eval 'hl.dispatch(hl.dsp.exit())'"))
--░█░█░▀█▀░█▀█░█▀▄░█▀█░█░█
--░█▄█░░█░░█░█░█░█░█░█░█▄█
--░▀░▀░▀▀▀░▀░▀░▀▀░░▀▀▀░▀░▀
--#Window management
-- Move focus with mainMod + arrow keys
hl.bind("SUPER + left", hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + right", hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER + up", hl.dsp.focus({ direction = "up" }))
hl.bind("SUPER + down", hl.dsp.focus({ direction = "down" }))
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
--░█░█░█▀█░█▀▄░█░█░█▀▀░█▀█░█▀█░█▀▀░█▀▀░█▀▀
--░█▄█░█░█░█▀▄░█▀▄░▀▀█░█▀▀░█▀█░█░░░█▀▀░▀▀█
--░▀░▀░▀▀▀░▀░▀░▀░▀░▀▀▀░▀░░░▀░▀░▀▀▀░▀▀▀░▀▀▀
--#Workspace management
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
--░█▀▀░█▀█░█▀▀░█▀▀░▀█▀░█▀█░█░░░░░█░█░█▀█░█▀▄░█░█░█▀▀░█▀█░█▀█░█▀▀░█▀▀░█▀▀
--░▀▀█░█▀▀░█▀▀░█░░░░█░░█▀█░█░░░░░█▄█░█░█░█▀▄░█▀▄░▀▀█░█▀▀░█▀█░█░░░█▀▀░▀▀█
--░▀▀▀░▀░░░▀▀▀░▀▀▀░▀▀▀░▀░▀░▀▀▀░░░▀░▀░▀▀▀░▀░▀░▀░▀░▀▀▀░▀░░░▀░▀░▀▀▀░▀▀▀░▀▀▀
--#Scratchpad management
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind("SUPER + ALT + " .. key, hl.dsp.workspace.toggle_special(i))
    hl.bind("SUPER + ALT + SHIFT + " .. key, hl.dsp.window.move({ workspace = "special:" .. i }))
end


--░█▄█░█░█░█░░░▀█▀░▀█▀░█▄█░█▀▀░█▀▄░▀█▀░█▀█
--░█░█░█░█░█░░░░█░░░█░░█░█░█▀▀░█░█░░█░░█▀█
--░▀░▀░▀▀▀░▀▀▀░░▀░░▀▀▀░▀░▀░▀▀▀░▀▀░░▀▀▀░▀░▀
--#Media and system controls
-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
    { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
    { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
    { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(
    "brightnessctl --quiet set +5%"),
    { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(
    "brightnessctl --quiet set 5%-"),
    { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
