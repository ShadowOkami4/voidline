# Voidline shell rewrite

This directory is the clean replacement for `recon`. It is deliberately
independent so the current desktop stays usable while the rewrite is built and
tested.

## Motion contract

- A panel keeps the edge nearest its trigger fixed while it opens.
- Attached panels grow away from their owning bar group. Top, bottom, left and
  right layouts use the same outward-filled concave joins, mirrored at the
  appropriate edge instead of falling back to floating rectangles.
- The Control Center uses a deliberate 700 ms in-out-cubic morph in both
  directions. The compact App Center and Music panel use a faster 320 ms
  variant; clipped content follows after each surface visibly expands.
- The container does not fade during exit; it stays opaque until the reverse
  geometry morph has fully contracted into the bar.
- The Control Center also terminates into the adjacent screen edge: top and
  bottom bars connect it to the screen side, while side bars connect it to the
  bottom frame. These joins extend outside the panel body so they never carve
  a notch out of its content surface.
- Pressed controls use a short scale response. Large panels do not bounce.
- Moving the bar between edges never slides a layer surface across the
  desktop. Its chrome fades and contracts, relocates while transparent, then
  settles and fades back in at the requested edge.
- No decorative or polling animation runs while the shell is idle.

## Architecture

- `core/` owns tokens, motion and the small panel state machine.
- `services/` owns native Quickshell integrations and system mutations.
- `components/` contains reusable visual primitives.
- `bar/` and `panels/` compose those primitives without shell-command parsing.

The color system uses Material 3 surface and text roles for dark and light
mode. Magic Colors feeds the selected wallpaper through Quickshell's
low-resolution quantizer and derives the complete tonal scheme: background,
panels, raised surfaces, text, outlines, accents and state containers. Chroma
is deliberately capped so wallpaper-derived colors remain calm and readable.

The first milestone keeps Recon's full-width, three-group bar silhouette. The
bar is painted inside a taller transparent layer window so its reverse concave
corner canvases can extend below the main surface. Its Control Center uses an
Android/Material motion foundation with a desktop-first One UI-inspired layout,
and spatially expands into focused Wi-Fi, Bluetooth, Sound, and Power &
Resources pages. Action Center, App Center, and Power drawer share a stable
12/18/24/30 px shape hierarchy. Selection changes color and elevation rather
than assigning unrelated radii to each state. Bar corners, the screen frame,
and every attached-panel join share one 20 px concave radius.

Bluetooth, PipeWire audio, UPower, PolicyKit and notifications use native Quickshell
services. Wi-Fi radio state is event-driven through `rfkill` and `networkctl`
because the laptop runs systemd-networkd. Network discovery and saved-network
connections prefer `NetworkManager`/`nmcli` and fall back to `iwd`/`iwctl`; without either backend, the page stays
usable as a radio control and explains which backend is missing. Power profiles
use `powerprofilesctl` against tuned-ppd, so the supported desktop policy path
is used instead of assigning a protected D-Bus property directly. Resource sampling
runs every 1.5 seconds only while its dashboard is visible and stops immediately
when that page closes.

The Wi-Fi page can rescan, connect to open and saved networks, accept a new PSK
through stdin, disconnect, and forget saved networks. The Bluetooth page can
scan, pair, confirm a displayed passkey or accept a PIN, connect, disconnect,
and forget devices. Its `bluetoothctl` pairing agent exists only while the page
or an unfinished pairing request needs it. The connectivity pages keep a fixed
surface size while their internal state changes to avoid nested panel morphs.
Sound exposes Android/One UI-inspired system-volume pills with embedded mute
buttons, hard-capped at 100%, native PipeWire output and input routing, and a
live Windows-style mixer for every application playback stream. The Home page
also has a master-volume control. `brightnessctl` detects real laptop backlight
hardware; only those systems receive a brightness slider beneath master volume.
Internal brightness is written through logind's session API and external
monitors use DDC/CI when `ddcutil` reports support. Settings and Action Center
share the same optimistic state, error handling, and coalesced writes.
Advanced enterprise Wi-Fi and Bluetooth permissions stay in the future Settings
app.

Home also exposes action-center controls for hotspot setup, Hyprland display
projection, and screen recording. Projection offers internal, external, mirror,
and extended modes when a second monitor is present. Recording uses
`wf-recorder` and saves into `~/Videos/Screencasts`. Hotspot setup stays inside
the attached Control Center: the native Material page configures the network
name, password, radio band and detected Ethernet-to-Wi-Fi route, then controls
the installed `create_ap` backend through PolicyKit. The password is sent over
standard input and is never exposed in the process command line. It is saved
outside the repository at `~/.local/state/voidline/hotspot.profile`; its parent
directory is owner-only (`0700`) and the encoded profile is mode `0600`, so the
details survive shell reloads without ever entering Git. Optional tiles
stay visibly unavailable when their backend is missing and are discovered again
whenever Home opens. On Arch, install the hotspot backend and its NAT/DHCP
helpers with:

```sh
yay -S --needed linux-wifi-hotspot dnsmasq
```

The Hotspot tile opens Voidline's own page rather than the backend's separate
GTK window. Its tile becomes accented while `create_ap` reports a running access
point, and the page reports the live number of connected clients. A native
Share QR action uses `qrencode` to generate a temporary standard Wi-Fi QR code
under `$XDG_RUNTIME_DIR/voidline`, allowing phones to join without typing the
saved password.

Each monitor owns its own bar and attached Control Center. Clicking a bar always
opens the panel on that bar's monitor; global shortcuts and regular IPC calls
fall back to Hyprland's currently focused monitor. Project mode uses Hyprland
0.55's Lua `hl.monitor(...)` runtime API for internal-only, external-only,
duplicate, and extended layouts. Extend places external outputs to the right
while preserving each active output's mode and scale.

The center Apps button and `SUPER + Space` open the App and Command Center on
the invoking monitor. Its compact root palette contains shell-level modules and
immediate actions rather than duplicating Control Center detail pages. Apps
opens a native `DesktopEntries` grid; Overview opens a monitor-local Task View
with live Hyprland window previews, window focus/close controls, workspace
selection, and New desktop. Existing Hyprland special workspaces appear as
scratchpads beside the regular desktops; opening one of their windows reveals
the hidden special workspace before focusing it. It is an internal
command-center page rather than a
second layer: the same bar-attached surface morphs from the compact palette to
one monitor-sized Overview geometry and back. Workspace changes never resize the
expanded panel. A stable responsive grid centers incomplete rows, caps card and
preview dimensions, and scrolls when more rows are needed. Visible cards capture
a fresh frame while only the selected card remains live; off-screen cards stop
capturing. Selecting a desktop only changes which cards are shown; opening a
card closes the panel and focuses that window. Calculator, a typed home-folder
file search, a Steam-library game carousel, and a combined Clipboard & Symbols
page are native launcher modules. Find Files can narrow results to documents,
images, media, or code. The combined page presents recent `cliphist` entries as
a list and the built-in emoji/symbol catalog as a name-free grid. Calculator supports
parentheses, powers, common functions, `pi`, and `e`; its result and selected
characters are copied with `wl-copy`. Clipboard collection runs only while the
required tools are available. Shell is a dedicated command page with in-session
history, captured output, exit status, and stop/clear controls. Interactive
terminal programs such as `nano`, `vim`, `nvim`, and `cava` open inside the
preferred terminal emulator; entering `>` from the root palette remains a
shortcut into Shell. The bar's Apps trigger is anchored to the exact horizontal
center of the attached App Center. **Ask Lyra** is the native entry for
Voidline's optional local assistant. Lyra is a name, not an acronym. Its
Quickshell UI, structured
action router, and inference provider separate. The shipped provider adapter
uses a rootless, session-owned Ollama service and the user's existing model
store; changing provider later does not require rewriting the App Center.

The responsive default is the Q4_K `qwen3.5:4b` model with a 4096-token context,
four-message history, 384-token response cap, streaming output, thinking
disabled, and a 15-minute warm-model window. On the Radeon 780M, the
`ollama-vulkan` runner is enabled explicitly, including integrated-GPU support.
Lyra remains local-only unless `online` is deliberately enabled for a future
provider. The preset manifest exposes Compact, Balanced, Advanced, and
Workstation choices for the future installer; automatic recommendations are
conservative so 32 GB or more is required before selecting the slower 9B tier.
The user can always override that choice:

```sh
scripts/local-ai.sh presets
scripts/local-ai.sh recommend
scripts/local-ai.sh pull-preset advanced
```

The complete AI performance, hardware-planning, hybrid CPU/GPU, multi-model,
service-lifecycle, telemetry, compatibility-warning, and user-control contract
is maintained in [`AI_ARCHITECTURE.md`](AI_ARCHITECTURE.md). The existing Ollama
adapter is provisional under that contract: it remains only if repeatable Arch
Linux benchmarks confirm the required latency, cancellation, offload, resource
reporting, and recovery behavior. Ask Lyra will expose only compact live metrics;
the standalone application owns detailed resource views and tuning controls.

Natural-language desktop actions never become shell text. Lyra first routes
requests through a small allow-list for applications, Steam games, safe
home-directory files, App Center searches, attached panels, Settings pages,
volume, brightness, radios, DND, and power profiles. File results are resolved
and canonicalized by a constrained helper before `xdg-open` receives them.
Restart, shutdown, logout, suspend, lock, and recording require an explicit
in-shell confirmation. The model is used for answers, not command execution.

The bar also owns a native StatusNotifierItem tray. It follows item icon,
tooltip, status and attention updates; forwards activate, secondary-activate,
context-menu, and scroll events; supplies a themed fallback icon; and pages
overflow items. The same component becomes a compact vertical stack when the
bar moves to either side.

Settings opens as a normal toplevel which Hyprland tiles and manages like any
other application; it is not a layer-shell panel. Wallpaper is native: it scans `~/.background`
and the XDG Wallpapers directory, persists the selected image, owns a Quickshell
background layer on every monitor, and feeds that path into Magic Colors.
The five workspace indicators in the bar use Hyprland 0.55's Lua dispatcher
syntax.

The tiled Settings application uses compact, width-bounded One UI-inspired
groups while retaining Voidline's own tonal palette, typography and shape
scale. Connections, PipeWire audio, connected hardware, notification behavior,
display arrangement, Appearance, lock screen, security, accessibility,
updates, and system information each have focused pages. Display arrangement
is drag-based and emits validated Hyprland monitor rules; unsupported features
such as HDR, night light, calibrated profiles, scanners, or VPN backends stay
visibly unavailable on hardware where they cannot work. Appearance covers the
wallpaper-derived palette, manual accent, theme, density, fonts, icon/cursor
themes, bar layout, clock design, and graphical Hyprland controls for
borders, opacity, gaps, rounding, shadows, blur, and animation presets.
Pointer, touchpad, and keyboard settings use the same allow-listed runtime
bridge. The Android-style developer page is unlocked by repeatedly selecting
the Voidline version.

Wallpaper changes are also exported atomically to a single readable cache file
under `/var/tmp`. The separate project in `sddm/` consumes that image without
starting Quickshell, provides a built-in fallback, and visually matches the
native lock screen. There is no wallpaper daemon or login-time polling.

Notifications are received by a Quickshell-owned daemon. New notifications
slide down at the top-right and remain available in the Action Center and
Settings notification history. Popup and Do Not Disturb preferences persist
without adding another polling process.

Voidline also owns the graphical PolicyKit agent through Quickshell's native
Polkit service. Authentication requests show the requesting application,
action, explanation, permitted identities, password visibility, retry and
error state in the wallpaper palette. Passwords are passed only to the active
authentication flow and are cleared immediately afterward. A separately
running `hyprpolkitagent` must be disabled so two agents do not race to register.

Settings uses real, allow-listed service bridges rather than decorative
controls: Bluetooth discovery and device management, PipeWire card
profiles/ports, logind/DDC brightness, optimistic monitor changes with
rollback, firewall and session inspection, accessibility backends, package
update review, and embedded diagnostics. Unsupported capabilities stay disabled
with an explanation. Official package updates are listed before confirmation
and installed through PolicyKit; AUR updates are listed separately and never
silently executed.

All shell-owned status menus use `VoidContextMenu`, including nested entries,
checkable and disabled items, separators, hover states, and animated
wallpaper-toned surfaces. Menus rendered inside sandboxed or Electron
applications remain owned by those applications; Voidline themes their GTK
integration but does not intercept application-private menu behavior.

`core/I18n.qml` loads `en-US`, `de-DE`, and `pl-PL` JSON catalogs with English
fallback, variables, locale-aware plural selection, and date/time formatting.
The active locale is persisted in Appearance and shared by the bar, attached
panels, Settings, Lyra, notifications, power and lock surfaces.

The lock-screen editor and real lock screen render the same `LockClock`
component. Digital, stacked, horizontal, minimal, analog, and playful designs
share font, weight, size, spacing, date, color and safe drag-position settings.

`scripts/app-theme.sh` builds a standards-compliant `Voidline` icon theme from
the vendored official Material Symbols source SVGs. Places, file types, devices,
symbolic aliases, and the application fallback have distinct icons; dynamic
folder colors use the current restrained wallpaper palette and inherit Papirus
and hicolor for application compatibility.

Discord, OBS, browsers, and other PipeWire portal clients use Voidline's native
share picker through XDPH's `custom_picker_binary` hook. It offers complete
outputs, individual application windows, and an interactive region selector in
one wallpaper-toned overlay on the focused monitor. Screen and window cards use
still-frame previews so merely opening the picker does not create a continuous
capture load. The Remember switch opts into XDPH restore tokens only when the
portal permits them. `scripts/voidline-share-picker` keeps Quickshell diagnostics
out of the portal protocol and falls back to the installed
`hyprland-share-picker` only when the custom frontend itself cannot start.

`Print` captures the currently focused display immediately. `SUPER + SHIFT + S`
opens the region selector. Both shortcuts save to `~/Pictures/Screenshots`, copy
the image to the clipboard when `wl-copy` is available, and use the same capture
backend as the Control Center action. `SUPER + SHIFT + C` starts the same native
color picker exposed in the Control Center. Screenshot, Color Picker, Screen
Recording, and DND stay in the Control Center instead of being duplicated in
the App Center.

`CTRL + ALT + DELETE` opens the power menu, `SUPER + .` opens emoji and
symbols, `SUPER + V` opens clipboard history, `SUPER + A` opens the Action
Center, `SUPER + Q` opens file search, and `SUPER + I` opens the tiled Settings
application.

The bar's music action opens a native MPRIS panel with artwork, metadata,
position, seek, and previous/play/next controls. Track position is refreshed
only while the panel is visible.

The Power drawer is independent of the App Center. Moving the pointer into the
middle of the right edge opens the drawer belonging to that output; leaving it
closes the drawer after a short grace period. Sleep runs immediately. Lock uses
Quickshell's Wayland session-lock protocol and native PAM authentication, with
the selected wallpaper and the same shell typography; `SUPER + L`, the power
drawer, and Hypridle all enter that one lock path. Log out,
Restart, and Power off require confirmation. Keep Awake holds a
`systemd-inhibit` idle/sleep blocker while its illuminated action row is active.

The Games page discovers installed titles from every library listed by Steam's
`libraryfolders.vdf`; compatibility runtimes are excluded. Portrait artwork is
cached under `~/.cache/voidline/steamgriddb`. Put a personal SteamGridDB v2 API
key in `~/.config/voidline/steamgriddb.key` (one line, preferably mode `600`) to
download the top-rated **alternate, static** 600x900/342x482 grid for each Steam
AppID. The image button on each game opens a native picker containing only grids
that match that same policy; a selection is cached for that game. Until a key is
present, the carousel uses Steam's local portrait cache so the launcher remains
usable offline. No key is stored in this repository.

Run it explicitly during development with:

```sh
quickshell -p ~/.config/quickshell/void
```

The attached surface can also be opened directly from a Hyprland binding,
gesture helper, or hardware side button through IPC:

```sh
quickshell ipc -p ~/.config/quickshell/void call controlCenter open wifi
quickshell ipc -p ~/.config/quickshell/void call controlCenter open bluetooth
quickshell ipc -p ~/.config/quickshell/void call controlCenter open sound
quickshell ipc -p ~/.config/quickshell/void call controlCenter open power
quickshell ipc -p ~/.config/quickshell/void call controlCenter open project
quickshell ipc -p ~/.config/quickshell/void call controlCenter open hotspot
quickshell ipc -p ~/.config/quickshell/void call controlCenter openOn project HDMI-A-1
quickshell ipc -p ~/.config/quickshell/void call controlCenter close
quickshell ipc -p ~/.config/quickshell/void call launcher open
quickshell ipc -p ~/.config/quickshell/void call launcher openOn HDMI-A-1
quickshell ipc -p ~/.config/quickshell/void call launcher close
quickshell ipc -p ~/.config/quickshell/void call overview open
quickshell ipc -p ~/.config/quickshell/void call overview openOn HDMI-A-1
quickshell ipc -p ~/.config/quickshell/void call overview close
quickshell ipc -p ~/.config/quickshell/void call powerMenu open
quickshell ipc -p ~/.config/quickshell/void call powerMenu openOn HDMI-A-1
quickshell ipc -p ~/.config/quickshell/void call powerMenu close
quickshell ipc -p ~/.config/quickshell/void call media open
quickshell ipc -p ~/.config/quickshell/void call media openOn HDMI-A-1
quickshell ipc -p ~/.config/quickshell/void call media close
quickshell ipc -p ~/.config/quickshell/void call lockScreen lock
quickshell ipc -p ~/.config/quickshell/void call screenRecording start eDP-1
quickshell ipc -p ~/.config/quickshell/void call screenRecording stop
quickshell ipc -p ~/.config/quickshell/void call screenRecording status
quickshell ipc -p ~/.config/quickshell/void call lyra open
quickshell ipc -p ~/.config/quickshell/void call lyra ask "What are my system specs?"
quickshell ipc -p ~/.config/quickshell/void call lyra status
quickshell ipc -p ~/.config/quickshell/void call lyra confirm
quickshell ipc -p ~/.config/quickshell/void call lyra cancel
```
