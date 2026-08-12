#!/bin/sh
set -eu

theme_name=voidline
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
theme_source="$script_dir/voidline"
destination=${DESTDIR:-}
case "$destination" in ''|/*) ;; *)
    printf '%s\n' 'DESTDIR must be an absolute path.' >&2
    exit 64
esac
theme_target="$destination/usr/share/sddm/themes/$theme_name"
config_target="$destination/etc/sddm.conf.d/voidline-theme.conf"

for required in Main.qml RoundedAvatar.qml VoidButton.qml \
    metadata.desktop theme.conf; do
    if [ ! -r "$theme_source/$required" ]; then
        printf 'Missing required theme file: %s\n' "$theme_source/$required" >&2
        exit 2
    fi
done

if [ -z "$destination" ] && [ "$(id -u)" -ne 0 ]; then
    printf 'Run with sudo: sudo %s\n' "$0" >&2
    exit 1
fi

if [ -z "$destination" ] && { [ -e "$theme_target" ] || [ -e "$config_target" ]; }; then
    backup_root="/var/lib/voidline/backups/sddm-$(date -u +%Y%m%dT%H%M%SZ)"
    install -d -m 0700 "$backup_root"
    [ ! -d "$theme_target" ] || cp -a -- "$theme_target" "$backup_root/theme"
    [ ! -f "$config_target" ] || cp -a -- "$config_target" "$backup_root/voidline-theme.conf"
    printf 'Backed up the previous SDDM theme files to %s.\n' "$backup_root"
fi

install -d -m 0755 "$theme_target"
cp -R -- "$theme_source/." "$theme_target/"
find "$theme_target" -type d -exec chmod 0755 {} \;
find "$theme_target" -type f -exec chmod 0644 {} \;

install -d -m 0755 "$destination/etc/sddm.conf.d"
temporary=$(mktemp "$destination/etc/sddm.conf.d/.voidline-theme.XXXXXX")
trap 'rm -f "$temporary"' EXIT HUP INT TERM
printf '[Theme]\nCurrent=%s\n' "$theme_name" >"$temporary"
chmod 0644 "$temporary"
mv -f -- "$temporary" "$config_target"
trap - EXIT HUP INT TERM

printf 'Installed the %s SDDM theme at %s.\n' \
    "$theme_name" "$theme_target"
printf 'SDDM will use it on the next logout or reboot.\n'
