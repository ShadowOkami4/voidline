# Voidline design preview

Work on the Voidline design on **Windows, macOS, or Linux** without Quickshell,
Hyprland, or a Voidline session. The preview loads the real shell QML from
`.config/quickshell/void` and the SDDM theme from `sddm/voidline`, with sample
data instead of live system services.

## Setup

1. Install [Python 3.10 or newer](https://www.python.org/downloads/).
   On Windows, tick **Add python.exe to PATH** in the installer.
2. Install PySide6 (the official Qt for Python package):

   ```sh
   pip install PySide6
   ```

3. Download the two fonts the design uses (Roboto Flex and Material Symbols
   Rounded) into `tools/preview/fonts/`. They are loaded only by the preview,
   so nothing is installed on your system:

   ```sh
   python tools/preview/preview.py --fetch-fonts
   ```

## Use

Run the commands from the repository root:

```sh
python tools/preview/preview.py                              # desktop with the bar
python tools/preview/preview.py action-center                # Quick Settings open
python tools/preview/preview.py settings --page appearance   # a Settings page
python tools/preview/preview.py power --style floating       # power menu, floating bar
python tools/preview/preview.py bar --style taskbar          # taskbar (always shown)
python tools/preview/preview.py lock --light                 # lock screen, light theme
python tools/preview/preview.py sddm                         # login screen
```

A window opens with the chosen part of the shell. **Leave it open and edit the
QML in any editor.** Each time you save a `.qml`, `.js`, or `.json` file, the
window reloads by itself. Loading errors and QML warnings are printed in the
terminal.

In the preview window:

| Key | Action |
| --- | --- |
| F5 | Reload now |
| F6 | Switch between light and dark |
| F12 | Save a screenshot to `tools/preview/shots/` |

Resize the window to see how the layout reacts to smaller or larger screens.

### Targets

| Target | Shows |
| --- | --- |
| `desktop`, `bar` | Wallpaper, screen frame, and bar |
| `action-center` | Action Center / Quick Settings |
| `launcher` | App Center |
| `clock` | Clock and calendar panel |
| `music` | Music panel |
| `power` | Power menu |
| `notification` | A notification popup |
| `settings` | Settings app; choose the page with `--page` |
| `lock` | Lock screen |
| `sddm` | SDDM login theme |

Settings pages: `connections`, `devices`, `display`, `audio`, `input`,
`appearance`, `desktop`, `windows`, `lock`, `notifications`, `security`,
`accessibility`, `language`, `updates`, `system`.

### Options

| Option | Meaning |
| --- | --- |
| `--style frame\|islands\|floating\|minimal\|taskbar` | Bar style |
| `--position top\|bottom\|left\|right` | Bar edge (the taskbar is always at the bottom) |
| `--autohide` | Let the taskbar hide (otherwise it stays visible for design work) |
| `--light` | Light theme |
| `--accent "#2FA38A"` | Fixed accent colour instead of wallpaper colours |
| `--wallpaper PATH` | Another wallpaper |
| `--size 1920x1080` | Starting window size (default 1536x864) |
| `--scale 1.2` | Voidline UI scale |
| `--shot out.png` | Save one screenshot and exit, without opening a window |
| `--verbose` | Show every QML warning |

## How it works

- The shell is copied into `tools/preview/.cache/` on every reload.
  **Always edit the files in `.config/quickshell/void`, never the cache.**
- `stubs/` contains minimal stand-ins for the Quickshell modules
  (`PanelWindow`, `Hyprland`, `Process`, …) so the shell's QML can load.
  Layer-shell windows become ordinary items inside one preview window.
- Every `*Service` singleton is replaced by a generated fake. Values come from
  `demo.json`; anything not listed there gets an empty default. Add entries to
  `demo.json` to try other states, for example a low battery or Do Not
  Disturb:

  ```json
  "PowerService": { "percentage": 12, "charging": false }
  ```

- Nothing runs commands, changes system settings, or writes your real
  Voidline configuration. Buttons that would do so do nothing.

## Limitations

- Behaviour that needs a real session (Wi-Fi scans, audio devices, window
  lists, notifications arriving, locking) is not simulated; the preview is for
  layout, colour, typography, and motion.
- Some warnings about missing sample data (for example weather) are expected.
- `--shot` on a machine without a GPU (such as a server or container) falls
  back to software rendering, where rounded images using `MultiEffect` masks
  appear empty. The live window on a normal desktop draws them correctly.
- The real result can differ slightly from Hyprland (blur, window shadows,
  and compositor animations are not part of the QML).
