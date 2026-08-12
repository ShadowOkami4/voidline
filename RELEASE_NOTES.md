# Voidline 0.3.0dev

`0.3.0dev` is a development release for testing on Arch Linux with Hyprland.
It is not a stable or production-ready desktop environment yet.

## Highlights

- Quickshell desktop shell with direction-aware bar and connected panels
- App Center, Action Center, notifications, system tray, and music controls
- Wallpaper-derived theming and eight original Voidline backgrounds
- Desktop Settings application covering network, Bluetooth/devices, audio,
  displays, appearance, accessibility, security, updates, and diagnostics
- Shared NetworkManager Wi-Fi flow for new and saved networks
- Lock screen plus lightweight matching SDDM theme
- Validated Rust user backend, global `voidlinectl`, and Rust terminal
- English, German, and Polish localization catalogues
- Optional **Lyra — Extreme Beta** local assistant

## Development status

Hardware-dependent integrations still need broader testing, especially DDC/CI,
HDR/EDID overrides, Bluetooth pairing variants, printers, scanners, and input
devices. The software-update interface is not yet a complete libalpm software
center. Lyra remains highly experimental and may be slow, choose incorrect
tools, or change substantially in later versions.

Back up existing desktop configuration before installing and report problems
with reproduction steps and sanitized logs.
