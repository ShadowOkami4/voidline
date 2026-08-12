#!/bin/sh
set -eu

destination=${DESTDIR:-}
if [ -n "$destination" ]; then
    case "$destination" in /*) ;; *)
        printf '%s\n' 'DESTDIR must be an absolute path.' >&2
        exit 64
    esac
else
    [ "$(id -u)" -eq 0 ] || {
        printf '%s\n' 'System uninstall must run as root, or use DESTDIR.' >&2
        exit 77
    }
fi
at() { printf '%s%s' "$destination" "$1"; }

# This list contains only files installed by backend/install-system.sh.
for file in \
    /usr/bin/voidlinectl \
    /usr/bin/voidline-terminal \
    /usr/bin/voidline-settings \
    /usr/bin/voidline-lyra \
    /usr/bin/voidline-shell \
    /usr/bin/voidline-display-safe-mode \
    /usr/bin/voidline-share-picker \
    /usr/lib/voidline/network-secret-helper \
    /usr/lib/voidline/voidlined \
    /usr/lib/voidline/voidline-terminal \
    /usr/lib/voidline/voidline-network \
    /usr/lib/systemd/user/voidline-backend.service \
    /usr/lib/systemd/user/voidline-shell.service \
    /usr/lib/systemd/user/voidline-ai.service \
    /usr/share/polkit-1/actions/org.voidline.network.policy \
    /usr/share/applications/voidline-terminal.desktop \
    /usr/share/applications/voidline-settings.desktop \
    /usr/share/applications/voidline-lyra.desktop \
    /usr/share/icons/hicolor/scalable/apps/voidline-terminal.svg \
    /usr/share/icons/hicolor/scalable/apps/voidline-settings.svg \
    /usr/share/icons/hicolor/scalable/apps/voidline-lyra.svg \
    /usr/share/bash-completion/completions/voidlinectl \
    /usr/share/zsh/site-functions/_voidlinectl \
    /usr/share/fish/vendor_completions.d/voidlinectl.fish \
    /usr/share/licenses/voidline/LICENSE; do
    rm -f -- "$(at "$file")"
done

for directory in \
    /usr/share/voidline \
    /usr/share/backgrounds/voidline; do
    target=$(at "$directory")
    [ -d "$target" ] && rm -R -- "$target"
done

for directory in \
    /usr/lib/voidline \
    /usr/share/licenses/voidline; do
    rmdir -- "$(at "$directory")" 2>/dev/null || true
done

printf 'Removed system-installed Voidline files from %s.\n' "${destination:-/}"
