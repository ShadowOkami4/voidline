#!/bin/sh

cache_directory=${XDG_CACHE_HOME:-"$HOME/.cache"}/voidline/profile
cache_file=$cache_directory/avatar.png
shared_file=/var/tmp/voidline-sddm-$(id -un).avatar.png

status() {
    if [ -r "$cache_file" ]; then
        printf 'ready|%s\n' "$cache_file"
    else
        printf 'default|%s\n' "$cache_file"
    fi
}

crop_image() {
    source_file=$1
    zoom=$2
    offset_x=$3
    offset_y=$4

    [ -r "$source_file" ] || exit 4
    command -v magick >/dev/null 2>&1 || exit 5
    case "$zoom:$offset_x:$offset_y" in
        *[!0-9.:+-]*) exit 2 ;;
    esac

    mkdir -p "$cache_directory" || exit 3
    normalized=$(mktemp "$cache_directory/.profile-normalized.XXXXXX.png") || exit 3
    output=$(mktemp "$cache_directory/.profile-output.XXXXXX.png") || {
        rm -f "$normalized"
        exit 3
    }
    trap 'rm -f "$normalized" "$output"' EXIT HUP INT TERM

    magick "$source_file" -auto-orient "$normalized" || exit 4
    dimensions=$(magick identify -format '%w %h' "$normalized") || exit 4
    width=${dimensions%% *}
    height=${dimensions#* }
    crop_values=$(awk -v width="$width" -v height="$height" \
        -v zoom="$zoom" -v offset_x="$offset_x" -v offset_y="$offset_y" '
        BEGIN {
            side = width < height ? width : height
            if (zoom < 1) zoom = 1
            crop = int(side / zoom)
            if (crop < 1) crop = 1
            max_x = width - crop
            max_y = height - crop
            x = int(((offset_x + 1) / 2) * max_x)
            y = int(((offset_y + 1) / 2) * max_y)
            if (x < 0) x = 0
            if (x > max_x) x = max_x
            if (y < 0) y = 0
            if (y > max_y) y = max_y
            printf "%dx%d+%d+%d", crop, crop, x, y
        }')

    magick "$normalized" -crop "$crop_values" +repage \
        -resize 512x512 -strip -define png:compression-level=9 "$output" || exit 4
    chmod 600 "$output"
    mv "$output" "$cache_file" || exit 3

    shared_temporary=$(mktemp /var/tmp/.voidline-avatar.XXXXXX.png) || exit 3
    if ! cp "$cache_file" "$shared_temporary"; then
        rm -f "$shared_temporary"
        exit 3
    fi
    chmod 644 "$shared_temporary"
    mv "$shared_temporary" "$shared_file"
    printf 'ready|%s\n' "$cache_file"
}

remove_image() {
    rm -f "$cache_file" "$shared_file"
    printf 'default|%s\n' "$cache_file"
}

case "${1:-status}" in
    status) status ;;
    crop) crop_image "${2:-}" "${3:-1}" "${4:-0}" "${5:-0}" ;;
    remove) remove_image ;;
    *) exit 2 ;;
esac
