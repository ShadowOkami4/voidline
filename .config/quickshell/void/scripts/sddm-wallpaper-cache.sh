#!/bin/sh

case "${1:-}" in
    export)
        source_path=${2:-}
        [ -r "$source_path" ] || exit 2

        valid_color() {
            printf '%s\n' "$1" | grep -Eq '^#[0-9A-Fa-f]{6}$'
        }
        palette_color() {
            if valid_color "$1"; then printf '%s' "$1"; else printf '%s' "$2"; fi
        }

        background_color=$(palette_color "${3:-}" '#0B0C0C')
        panel_color=$(palette_color "${4:-}" '#161A19')
        surface_color=$(palette_color "${5:-}" '#242B29')
        raised_color=$(palette_color "${6:-}" '#2F3A37')
        text_color=$(palette_color "${7:-}" '#E7E9E9')
        muted_color=$(palette_color "${8:-}" '#B2BDBA')
        outline_color=$(palette_color "${9:-}" '#43514D')
        accent_color=$(palette_color "${10:-}" '#AFD4C9')
        accent_soft_color=$(palette_color "${11:-}" '#305A4D')

        safe_user=$(printf '%s' "${USER:-user}" | tr -cd 'A-Za-z0-9_.-')
        [ -n "$safe_user" ] || exit 2
        destination="/var/tmp/voidline-sddm-${safe_user}.wallpaper.png"
        metadata="/var/tmp/voidline-sddm-${safe_user}.meta"
        settings_file=${XDG_CONFIG_HOME:-${HOME:?}/.config}/voidline/settings.json

        # /var/tmp is sticky. Creating the temporary files first and then
        # renaming them avoids partial images and never follows a destination
        # symlink.
        temporary=$(mktemp "/var/tmp/.voidline-sddm-${safe_user}.XXXXXX")
        temporary_meta=$(mktemp "/var/tmp/.voidline-sddm-${safe_user}.meta.XXXXXX")
        trap 'rm -f "$temporary" "$temporary_meta"' EXIT HUP INT TERM

        cp -- "$source_path" "$temporary"
        chmod 0644 "$temporary"
        # SDDM only receives non-sensitive presentation settings. Never expose
        # the original wallpaper path through world-readable metadata.
        if command -v jq >/dev/null 2>&1 && [ -r "$settings_file" ]; then
            jq -r --arg user "$safe_user" \
                --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
                ["user=" + $user, "updated=" + $updated,
                 "clockStyle=" + (.lockClockStyle // "digital-large"),
                 "clockFont=" + (.lockClockFont // "Roboto Flex"),
                 "clockWeight=" + ((.lockClockWeight // 760) | tostring),
                 "clockColor=" + (.lockClockColor1 // "#FFFFFF")]
                | .[]' "$settings_file" >"$temporary_meta"
        else
            printf 'user=%s\nupdated=%s\nclockStyle=digital-large\nclockFont=Roboto Flex\nclockWeight=760\nclockColor=#FFFFFF\n' \
                "$safe_user" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$temporary_meta"
        fi
        printf 'backgroundColor=%s\npanelColor=%s\nsurfaceColor=%s\nraisedSurfaceColor=%s\ntextColor=%s\nmutedTextColor=%s\noutlineColor=%s\naccentColor=%s\naccentSoftColor=%s\n' \
            "$background_color" "$panel_color" "$surface_color" "$raised_color" \
            "$text_color" "$muted_color" "$outline_color" "$accent_color" \
            "$accent_soft_color" >>"$temporary_meta"
        chmod 0644 "$temporary_meta"

        [ ! -d "$destination" ] || exit 3
        [ ! -d "$metadata" ] || exit 3
        mv -f -- "$temporary" "$destination"
        mv -f -- "$temporary_meta" "$metadata"
        trap - EXIT HUP INT TERM
        printf '%s\n' "$destination"
        ;;
    *)
        exit 2
        ;;
esac
