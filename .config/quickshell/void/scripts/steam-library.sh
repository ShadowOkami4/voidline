#!/bin/sh

set -u

action=${1:-scan}
steam_root=${VOIDLINE_STEAM_ROOT:-"$HOME/.local/share/Steam"}
cache_dir=${XDG_CACHE_HOME:-"$HOME/.cache"}/voidline/steamgriddb
key_file=${STEAMGRIDDB_API_KEY_FILE:-"$HOME/.config/voidline/steamgriddb.key"}

manifest_value() {
    awk -F '"' -v field="$2" '$2 == field { print $4; exit }' "$1"
}

library_paths() {
    printf '%s\n' "$steam_root"
    library_file="$steam_root/steamapps/libraryfolders.vdf"
    [ -f "$library_file" ] || library_file="$steam_root/config/libraryfolders.vdf"
    if [ -f "$library_file" ]; then
        awk -F '"' '$2 == "path" { print $4 }' "$library_file" | sed 's#\\\\#\\#g'
    fi
}

manifest_paths() {
    library_paths | awk 'NF && !seen[$0]++' | while IFS= read -r library; do
        [ -d "$library/steamapps" ] || continue
        find "$library/steamapps" -maxdepth 1 -type f -name 'appmanifest_*.acf' -print
    done | awk '!seen[$0]++'
}

is_runtime() {
    case "$1:$2" in
        228980:*|1070560:*|1493710:*|4183110:*|*:Proton\ *|*:Steam\ Linux\ Runtime*|*:Steamworks\ Common\ Redistributables*)
            return 0
            ;;
    esac
    return 1
}

grid_cache_path() {
    appid=$1
    for extension in jpg jpeg png webp; do
        candidate=$(find "$cache_dir" -maxdepth 1 -type f \
            -name "${appid}-alternate-*.$extension" -print -quit 2>/dev/null || true)
        if [ -n "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

steam_grid_path() {
    appid=$1
    custom=$(find "$steam_root/userdata" -type f \
        \( -name "${appid}p.jpg" -o -name "${appid}p.png" -o -name "${appid}p.webp" \) \
        -print -quit 2>/dev/null || true)
    if [ -n "$custom" ]; then
        printf '%s\n' "$custom"
        return 0
    fi
    local_grid=$(find "$steam_root/appcache/librarycache/$appid" -type f \
        -name 'library_600x900*' -print -quit 2>/dev/null || true)
    if [ -n "$local_grid" ]; then
        printf '%s\n' "$local_grid"
        return 0
    fi
    return 1
}

scan_library() {
    if [ -s "$key_file" ] || [ -n "${STEAMGRIDDB_API_KEY:-}" ]; then
        printf 'status\tapi\t1\n'
    else
        printf 'status\tapi\t0\n'
    fi

    manifest_paths | while IFS= read -r manifest; do
        appid=$(manifest_value "$manifest" appid)
        name=$(manifest_value "$manifest" name)
        [ -n "$appid" ] && [ -n "$name" ] || continue
        is_runtime "$appid" "$name" && continue
        name=$(printf '%s' "$name" | tr '\t\r\n' '   ')

        source=steam
        if image=$(grid_cache_path "$appid"); then
            source=steamgriddb
        elif image=$(steam_grid_path "$appid"); then
            source=steam
        else
            image="https://cdn.cloudflare.steamstatic.com/steam/apps/$appid/library_600x900_2x.jpg"
        fi
        printf 'game\t%s\t%s\t%s\t%s\n' "$appid" "$name" "$image" "$source"
    done
}

refresh_artwork() {
    key=${STEAMGRIDDB_API_KEY:-}
    if [ -z "$key" ] && [ -s "$key_file" ]; then
        IFS= read -r key < "$key_file"
    fi
    [ -n "$key" ] || exit 0
    command -v curl >/dev/null 2>&1 || exit 127
    command -v jq >/dev/null 2>&1 || exit 127
    mkdir -p "$cache_dir"

    manifest_paths | while IFS= read -r manifest; do
        appid=$(manifest_value "$manifest" appid)
        name=$(manifest_value "$manifest" name)
        [ -n "$appid" ] && [ -n "$name" ] || continue
        is_runtime "$appid" "$name" && continue
        grid_cache_path "$appid" >/dev/null 2>&1 && continue

        endpoint="https://www.steamgriddb.com/api/v2/grids/steam/$appid?styles=alternate&dimensions=600x900,342x482&types=static&nsfw=false&humor=false&limit=1"
        response=$(printf 'header = "Authorization: Bearer %s"\nsilent\nshow-error\nfail\n' "$key" |
            curl --config - "$endpoint" 2>/dev/null || true)
        url=$(printf '%s' "$response" | jq -r '.data[0].url // empty' 2>/dev/null)
        [ -n "$url" ] || continue

        extension=${url%%\?*}
        extension=${extension##*.}
        case "$extension" in
            jpg|jpeg|png|webp) ;;
            *) extension=jpg ;;
        esac
        destination="$cache_dir/${appid}-alternate-auto.$extension"
        temporary="$cache_dir/.${appid}-alternate-auto.$extension.part"
        if curl -fsSL "$url" -o "$temporary"; then
            mv "$temporary" "$destination"
            printf 'downloaded\t%s\t%s\n' "$appid" "$destination"
        else
            rm -f "$temporary"
        fi
    done
}

list_artwork_choices() {
    appid=${2:-}
    case "$appid" in *[!0-9]*|'') exit 2 ;; esac
    key=${STEAMGRIDDB_API_KEY:-}
    if [ -z "$key" ] && [ -s "$key_file" ]; then
        IFS= read -r key < "$key_file"
    fi
    [ -n "$key" ] || exit 3
    command -v curl >/dev/null 2>&1 || exit 127
    command -v jq >/dev/null 2>&1 || exit 127

    endpoint="https://www.steamgriddb.com/api/v2/grids/steam/$appid?styles=alternate&dimensions=600x900,342x482&types=static&nsfw=false&humor=false&limit=30"
    response=$(printf 'header = "Authorization: Bearer %s"\nsilent\nshow-error\nfail\n' "$key" |
        curl --config - "$endpoint")
    printf '%s' "$response" | jq -r '
        .data[] | ["choice", (.id | tostring), .url, (.thumb // .url)] | @tsv
    '
}

select_artwork() {
    appid=${2:-}
    grid_id=${3:-}
    url=${4:-}
    case "$appid" in *[!0-9]*|'') exit 2 ;; esac
    case "$grid_id" in *[!0-9]*|'') exit 2 ;; esac
    case "$url" in
        https://cdn*.steamgriddb.com/*) ;;
        *) exit 2 ;;
    esac
    mkdir -p "$cache_dir"

    extension=${url%%\?*}
    extension=${extension##*.}
    case "$extension" in
        jpg|jpeg|png|webp) ;;
        *) extension=jpg ;;
    esac
    destination="$cache_dir/${appid}-alternate-${grid_id}.$extension"
    temporary="$cache_dir/.${appid}-alternate-${grid_id}.$extension.part"
    if curl -fsSL "$url" -o "$temporary"; then
        for old_extension in jpg jpeg png webp; do
            find "$cache_dir" -maxdepth 1 -type f \
                -name "${appid}-alternate-*.$old_extension" ! -path "$destination" \
                -delete 2>/dev/null || true
        done
        mv "$temporary" "$destination"
        printf 'selected\t%s\t%s\n' "$appid" "$destination"
    else
        rm -f "$temporary"
        exit 1
    fi
}

case "$action" in
    scan) scan_library ;;
    artwork) refresh_artwork ;;
    choices) list_artwork_choices "$@" ;;
    select-art) select_artwork "$@" ;;
    *) exit 2 ;;
esac
