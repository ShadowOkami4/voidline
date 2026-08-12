#!/bin/sh
set -eu

[ "$(id -u)" -eq 0 ] || {
    printf '%s\n' 'Run this SDDM uninstall step as root.' >&2
    exit 77
}

theme=/usr/share/sddm/themes/voidline
configuration=/etc/sddm.conf.d/voidline-theme.conf
[ -d "$theme" ] && rm -R -- "$theme"
rm -f -- "$configuration"
printf '%s\n' 'Removed the Voidline SDDM theme and its selector file.'
