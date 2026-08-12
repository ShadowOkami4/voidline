#!/bin/sh

case "${1:-list}" in
    list)
        pictures_dir=
        if command -v xdg-user-dir >/dev/null 2>&1; then
            pictures_dir=$(xdg-user-dir PICTURES 2>/dev/null || true)
        fi

        {
            for directory in \
                "/usr/share/backgrounds/voidline" \
                "${XDG_DATA_HOME:-$HOME/.local/share}/backgrounds/voidline" \
                "$HOME/.background" \
                "$pictures_dir/Wallpapers" \
                "$HOME/Pictures/Wallpapers" \
                "$HOME/Bilder/Wallpapers"; do
                if [ -n "$directory" ] && [ -d "$directory" ]; then
                    find "$directory" -maxdepth 2 -type f \
                        \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
                        -o -iname '*.webp' -o -iname '*.avif' \) -print
                fi
            done
        } | awk '!seen[$0]++' | sort
        ;;
    *)
        exit 2
        ;;
esac
