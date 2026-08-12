-- Voidline 0.3.0dev Hyprland integration.
-- Installed separately so an update never replaces the user's main config.

hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user start voidline-shell.service")
end)

hl.bind("SUPER + SPACE", hl.dsp.global("quickshell:toggleLauncher"))
hl.bind("SUPER + I", hl.dsp.global("quickshell:toggleSettings"))
hl.bind("SUPER + TAB", hl.dsp.global("quickshell:toggleOverview"))
hl.bind("CTRL + ALT + DELETE", hl.dsp.global("quickshell:togglePowerMenu"))
hl.bind("SUPER + PERIOD", hl.dsp.global("quickshell:openClipboardSymbols"))
hl.bind("SUPER + V", hl.dsp.global("quickshell:openClipboardHistory"))
hl.bind("SUPER + A", hl.dsp.global("quickshell:openActionCenter"))
hl.bind("SUPER + Q", hl.dsp.global("quickshell:openFileSearch"))
hl.bind("SUPER + L", hl.dsp.global("quickshell:lockScreen"))
hl.bind("PRINT", hl.dsp.exec_cmd("voidlinectl screenshot screen"))
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("voidlinectl screenshot region"))
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("voidlinectl color-picker"))
