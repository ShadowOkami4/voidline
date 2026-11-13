# Voidline

Voidline is a desktop shell: a layer around a Wayland window manager that turns
it into a full desktop. It is built with [Quickshell](https://quickshell.org/)
and designed in Material 3 Expressive.

**0.4 is a full rewrite and a development preview.** It is not yet a
replacement for 0.3.0 (see [Status](#status)).

- Works on **Hyprland** (Lua config, 0.55+) and **Niri**, from the same code.
- Three **styles**, switchable live: **Voidline** (connected bar, screen frame
  and attached panels), **Windows** (bottom taskbar, start menu) and **macOS**
  (menu bar and dock).
- **Minimise** on a tiling window manager: minimised windows are parked on a
  hidden workspace and stay in the taskbar/dock, one click to bring them back.
- Light: no daemon, no polling loops. State comes from Quickshell's built-in
  services and compositor events.

## Install (Arch Linux)

```bash
git clone --branch v4 https://github.com/ShadowOkami4/voidline.git
cd voidline
./install.sh --install-deps
```

Run it as your normal user. The installer copies the shell to
`~/.config/quickshell/voidline`, puts one Voidline file next to your compositor
config and adds a single include line to it (after making a backup). It does not
replace your Hyprland or Niri config. `./install.sh --uninstall` reverts it.

Then log out and back in, or start it right away with `qs -c voidline`.

## Keys

| Key | Action |
| --- | --- |
| Super + Space | Launcher |
| Super + A | Quick settings |
| Super + N | Minimise the focused window |
| Super + Shift + N | Restore the last minimised window |
| Super + Alt + S | Next style |

Change them in `~/.config/hypr/voidline.lua` or `~/.config/niri/voidline.kdl`.
In the taskbar and dock: click focuses a window, clicking the focused window
minimises it, clicking a minimised window restores it, middle click closes it.

## Settings

Settings live in `~/.config/voidline/config.json` and apply as soon as the file
is saved.

| Key | Values | Meaning |
| --- | --- | --- |
| `style` | `voidline`, `windows`, `macos` | Layout preset |
| `dark` | `true`, `false` | Dark or light theme |
| `accent` | `#RRGGBB` | Seed colour for the palette |
| `wallpaper` | file path or `""` | Wallpaper drawn by Voidline (empty: leave it to the compositor) |
| `wallpaperColors` | `true`, `false` | Derive the palette from the wallpaper |
| `clock24h` | `true`, `false` | 24-hour clock |
| `reduceMotion` | `true`, `false` | Turn animations off |
| `doNotDisturb` | `true`, `false` | Collect notifications without popups |
| `workspaceCount` | number | Minimum workspaces shown (Hyprland) |

`voidlinectl` (optional, built by the installer when Rust is installed) edits
these with validation and can check your setup:

```bash
voidlinectl set style macos
voidlinectl doctor
```

## How it is put together

```
shell/
  shell.qml        entry point: one bar (+ frame/dock) and panel host per screen
  core/            Config (settings), Theme (colours, shapes, type), Motion, Style, Shell (UI state)
  compositor/      Compositor (neutral model) + one backend per window manager
  services/        Audio, Battery, Brightness, Network, Notifs, Apps
  widgets/         Buttons, slider, tile, icons, the concave join
  bar/             Bar layouts per style, workspaces, clock, tray, status, task list, dock, frame
  panels/          Launcher, quick settings, notifications, wallpaper
config/            The files hooked into Hyprland and Niri
helper/            voidlinectl (Rust)
```

Two rules keep it portable:

1. Only `compositor/` talks to a window manager. The rest of the shell sees
   `Compositor.workspaces`, `Compositor.windows` and a few actions. Adding a
   window manager means adding one backend file.
2. A style only changes geometry (`core/Style.qml`) and the bar arrangement
   (`bar/Bar.qml`). Colours, widgets and panels are shared.

## Status

Working in 0.4: bar, screen frame, dock, task list, workspaces, tray, clock,
launcher, quick settings (network, Bluetooth, do not disturb, theme, volume,
brightness, power), notifications, wallpaper with palette extraction, minimise,
live style switching.

Not rewritten yet (present in 0.3.0): settings app, lock screen, SDDM theme,
full Wi-Fi/Bluetooth/hotspot pages, games page, media controls, overview,
polkit dialog, translations. The Lyra assistant and the Voidline terminal are
not planned for 0.4.

Known limits:

- Niri has no hidden workspaces, so minimised windows sit on a normal
  workspace named `minimized`. Voidline hides it from the bar, but you can
  still scroll to it.
- Multi-monitor is untested.

## License

MIT, see [LICENSE](LICENSE).
