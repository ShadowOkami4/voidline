#!/bin/sh
set -eu

[ "$#" -eq 3 ] || exit 64
legacy_root=$1
config_root=$2
state_root=$3

case "$config_root" in
    /*/voidline) ;;
    *) exit 65 ;;
esac
case "$state_root" in
    /*/voidline) ;;
    *) exit 65 ;;
esac

migrate_file() {
    source_path=$1
    target_path=$2
    if [ ! -e "$target_path" ] && [ -f "$source_path" ]; then
        /usr/bin/install -m 600 "$source_path" "$target_path"
    fi
}

migrate_file "$legacy_root/settings.json" "$config_root/settings.json"
migrate_file "$legacy_root/system-settings.json" "$config_root/system-settings.json"
migrate_file "$legacy_root/assistant-state.json" "$config_root/assistant-state.json"
migrate_file "$legacy_root/ai-provider.json" "$config_root/ai-provider.json"
migrate_file "$legacy_root/updates-history.json" "$state_root/updates-history.json"
