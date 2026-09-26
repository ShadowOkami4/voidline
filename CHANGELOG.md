# Changelog

## Unreleased

- Installer: re-running `install.sh` no longer appends duplicate Hyprland
  integration lines (which made every shortcut fire twice); existing
  duplicates are cleaned up. Refuses to run as root, accepts rustup, resolves
  packages through provides, uses paru/yay for AUR packages, pins the cargo
  target directory, swaps the packaged shell in atomically, and no longer
  aborts when no systemd user session is reachable.
- Material 3 Expressive redesign: seeded tonal colour scheme (fixes purple
  containers when Magic Colors is off), M3E shape scale and spring motion,
  shape-morphing switches, icon buttons, tiles and chips, segmented Settings
  groups, connected button groups, and restyled bar, notifications, power
  drawer, lock screen, and SDDM theme.

## 0.3.0dev — 2026-08-12

- First public development snapshot of the rewritten Voidline shell.
- Added connected, orientation-aware panels and shared geometry/motion tokens.
- Added App Center, Action Center, Settings, notifications, tray, power, music,
  clipboard, overview, wallpaper, lock-screen, and SDDM experiences.
- Added shared NetworkManager Wi-Fi activation for new and saved networks.
- Added a validated Rust backend, `voidlinectl`, and Rust terminal.
- Added wallpaper-derived palettes, original wallpapers, device integrations,
  and `en-US`, `de-DE`, and `pl-PL` localization.
- Added optional Lyra — Extreme Beta packaging and standalone interface.
- Added staged system/user installers, clean uninstall support, and Arch package
  metadata.
