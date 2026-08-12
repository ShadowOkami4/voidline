#!/usr/bin/env bash
set -Eeuo pipefail

repository=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
mode=system
remove_sddm=0
purge_generated=0

usage() {
    cat <<'EOF'
Usage: ./uninstall.sh [--system|--user] [--remove-sddm] [--purge-generated]

By default this removes only files installed by Voidline. Personal settings,
wallpapers, screenshots, conversations, and backups remain untouched.
--purge-generated additionally removes Voidline's generated caches and state,
but still preserves user-selected wallpapers and backup files.
EOF
}
while (($#)); do
    case "$1" in
        --system) mode=system ;;
        --user) mode=user ;;
        --remove-sddm) remove_sddm=1 ;;
        --purge-generated) purge_generated=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 64 ;;
    esac
    shift
done

systemctl --user disable --now voidline-shell.service 2>/dev/null || true
systemctl --user stop voidline-backend.service voidline-ai.service 2>/dev/null || true

config_home=${XDG_CONFIG_HOME:-$HOME/.config}
state_home=${XDG_STATE_HOME:-$HOME/.local/state}
backup_root="$state_home/voidline/backups/uninstall-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p -- "$backup_root"
chmod 700 "$backup_root"

for config in "$config_home/hypr/hyprland.conf" "$config_home/hypr/hyprland.lua"; do
    [[ -f $config ]] || continue
    if grep -q 'Added by Voidline' "$config"; then
        cp -a -- "$config" "$backup_root/$(basename "$config")"
        temporary=$(mktemp "$(dirname "$config")/.voidline-uninstall.XXXXXX")
        if [[ $config == *.lua ]]; then
            sed '/^-- Added by Voidline 0\.3\.0dev$/,+1d' "$config" >"$temporary"
        else
            sed '/^# Added by Voidline 0\.3\.0dev$/,+1d' "$config" >"$temporary"
        fi
        chmod --reference="$config" "$temporary" 2>/dev/null || chmod 600 "$temporary"
        mv -f -- "$temporary" "$config"
    fi
done
rm -f -- "$config_home/hypr/voidline.conf" "$config_home/hypr/voidline.lua"

if [[ $mode == system ]]; then
    sudo "$repository/backend/uninstall-system.sh"
else
    "$repository/backend/uninstall-user.sh"
fi
if [[ $remove_sddm -eq 1 ]]; then
    sudo "$repository/sddm/uninstall.sh"
fi
if [[ $purge_generated -eq 1 ]]; then
    cache_home=${XDG_CACHE_HOME:-$HOME/.cache}
    runtime_home=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
    [[ -d $cache_home/voidline ]] && rm -R -- "$cache_home/voidline"
    [[ -d $runtime_home/voidline ]] && rm -R -- "$runtime_home/voidline"
    rm -f -- "$state_home/voidline"/*.json "$state_home/voidline"/*.state 2>/dev/null || true
fi
systemctl --user daemon-reload
printf '%s\n' 'Voidline-installed files were removed.'
printf '%s\n' 'Personal configuration, data, wallpapers, and backups were preserved.'
printf 'Any edited Hyprland config was backed up under %s.\n' "$backup_root"
