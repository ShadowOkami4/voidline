# Voidline SDDM theme

This is a standalone, lightweight SDDM theme. It does not import or start
Quickshell. It provides user and session selection, password authentication,
Caps Lock feedback, suspend/hibernate controls, guarded restart and power-off
actions, cached per-user wallpaper/avatar support, and keyboard navigation.
The clock, profile card, controls, surfaces, and motion mirror the Voidline
lock screen.

## Requirements

- SDDM 0.21 or newer
- `qt5-graphicaleffects` for Arch's current Qt 5 SDDM greeter and the
  lightweight rounded avatar mask
- Roboto Flex and Material Symbols Rounded (listed by Voidline's dependency
  manifest)

## Wallpaper hand-off

Whenever Voidline applies a wallpaper, `sddm-wallpaper-cache.sh` atomically
copies it to:

`/var/tmp/voidline-sddm-<username>.wallpaper.png`

SDDM can read that cached image before a user session exists. A small matching
metadata file caches only non-sensitive clock/font/accent presentation values;
it never includes the source wallpaper path. The profile
service uses the matching
`/var/tmp/voidline-sddm-<username>.avatar.png` path. The theme keeps a
lightweight built-in gradient and the account's normal SDDM avatar as
fallbacks until the per-user caches load. There is no daemon or background
polling.

## Test and install

From an active graphical session, test without installing:

```sh
sddm-greeter --test-mode --theme ./voidline
```

On Wayland, SDDM's test greeter may need the active display environment:

```sh
QT_QPA_PLATFORM=wayland sddm-greeter --test-mode --theme ./voidline
```

Install the complete theme:

```sh
sudo sh ./install.sh
```

The installer copies the theme to `/usr/share/sddm/themes/voidline` and writes
only `/etc/sddm.conf.d/voidline-theme.conf`. Log out or restart SDDM to see it.
It does not restart SDDM automatically, so the current graphical session is
never terminated by the installer.
