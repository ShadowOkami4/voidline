#!/bin/sh
set -eu

prefix=${VOIDLINE_PREFIX:-${HOME:?}/.local}
case "$prefix" in /*) ;; *)
    printf '%s\n' 'VOIDLINE_PREFIX must be an absolute path.' >&2; exit 64
esac
[ "$prefix" != / ] || {
    printf '%s\n' 'Refusing to use the filesystem root as VOIDLINE_PREFIX.' >&2
    exit 64
}

systemctl --user stop voidline-shell.service voidline-backend.service \
    voidline-ai.service 2>/dev/null || true
for file in \
    "$prefix/bin/voidlinectl" \
    "$prefix/bin/voidline-terminal" \
    "$prefix/bin/voidline-settings" \
    "$prefix/bin/voidline-lyra" \
    "$prefix/bin/voidline-shell" \
    "$prefix/bin/voidline-display-safe-mode" \
    "$prefix/bin/voidline-share-picker" \
    "$prefix/lib/voidline/voidlined" \
    "$prefix/lib/voidline/voidline-terminal" \
    "$prefix/lib/voidline/voidline-network" \
    "$prefix/share/systemd/user/voidline-backend.service" \
    "$prefix/share/systemd/user/voidline-shell.service" \
    "$prefix/share/systemd/user/voidline-ai.service" \
    "$prefix/share/applications/voidline-terminal.desktop" \
    "$prefix/share/applications/voidline-settings.desktop" \
    "$prefix/share/applications/voidline-lyra.desktop" \
    "$prefix/share/icons/hicolor/scalable/apps/voidline-terminal.svg" \
    "$prefix/share/icons/hicolor/scalable/apps/voidline-settings.svg" \
    "$prefix/share/icons/hicolor/scalable/apps/voidline-lyra.svg" \
    "$prefix/share/bash-completion/completions/voidlinectl" \
    "$prefix/share/zsh/site-functions/_voidlinectl" \
    "$prefix/share/fish/vendor_completions.d/voidlinectl.fish" \
    "$prefix/share/licenses/voidline/LICENSE"; do
    rm -f -- "$file"
done
for directory in \
    "$prefix/share/voidline" \
    "$prefix/share/backgrounds/voidline"; do
    [ -d "$directory" ] && rm -R -- "$directory"
done
rmdir -- "$prefix/lib/voidline" 2>/dev/null || true
rmdir -- "$prefix/share/licenses/voidline" 2>/dev/null || true
systemctl --user daemon-reload 2>/dev/null || true
printf 'Removed user-installed Voidline files from %s.\n' "$prefix"
