#!/bin/sh
set -eu

# Installs only repository-owned files. User configuration, service activation,
# Hyprland integration, and the optional SDDM theme are handled by /install.sh.
# DESTDIR makes the exact package layout testable without touching the host.

workspace=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repository=$(CDPATH= cd -- "$workspace/.." && pwd)
destination=${DESTDIR:-}
with_lyra=${VOIDLINE_WITH_LYRA:-0}

case "$with_lyra" in 0|1) ;; *)
    printf '%s\n' 'VOIDLINE_WITH_LYRA must be 0 or 1.' >&2
    exit 64
esac
if [ -n "$destination" ]; then
    case "$destination" in /*) ;; *)
        printf '%s\n' 'DESTDIR must be an absolute path.' >&2
        exit 64
    esac
else
    [ "$(id -u)" -eq 0 ] || {
        printf '%s\n' 'Run this installation step as root, or set DESTDIR for staging.' >&2
        exit 77
    }
fi

at() { printf '%s%s' "$destination" "$1"; }

for binary in voidlined voidlinectl voidline-terminal; do
    [ -x "$workspace/target/release/$binary" ] || {
        printf 'Missing release binary: %s\n' "$binary" >&2
        printf '%s\n' 'Build first with: cargo build --locked --release --workspace' >&2
        exit 66
    }
done
[ -x "$workspace/target/release/voidline-network" ] || {
    printf '%s\n' 'Missing release binary: voidline-network' >&2
    printf '%s\n' 'Build first with: backend/build-network-helper.sh' >&2
    exit 66
}

install -d -m 755 \
    "$(at /usr/bin)" \
    "$(at /usr/lib/voidline)" \
    "$(at /usr/lib/systemd/user)" \
    "$(at /usr/share/voidline/material-symbols)" \
    "$(at /usr/share/voidline/hypr)" \
    "$(at /usr/share/voidline/xdg-desktop-portal)" \
    "$(at /usr/share/backgrounds/voidline)" \
    "$(at /usr/share/polkit-1/actions)" \
    "$(at /usr/share/applications)" \
    "$(at /usr/share/icons/hicolor/scalable/apps)" \
    "$(at /usr/share/licenses/voidline)" \
    "$(at /usr/share/bash-completion/completions)" \
    "$(at /usr/share/zsh/site-functions)" \
    "$(at /usr/share/fish/vendor_completions.d)"

install -m 755 "$workspace/target/release/voidlined" \
    "$(at /usr/lib/voidline/voidlined)"
install -m 755 "$workspace/target/release/voidlinectl" \
    "$(at /usr/bin/voidlinectl)"
install -m 755 "$workspace/target/release/voidline-terminal" \
    "$(at /usr/lib/voidline/voidline-terminal)"
install -m 755 "$workspace/target/release/voidline-network" \
    "$(at /usr/lib/voidline/voidline-network)"
install -m 755 "$repository/.local/bin/voidline-terminal" \
    "$(at /usr/bin/voidline-terminal)"
install -m 755 "$repository/.local/bin/voidline-settings" \
    "$(at /usr/bin/voidline-settings)"
install -m 755 "$repository/.local/bin/voidline-shell" \
    "$(at /usr/bin/voidline-shell)"
install -m 755 "$repository/.local/bin/voidline-display-safe-mode" \
    "$(at /usr/bin/voidline-display-safe-mode)"
install -m 755 "$repository/.config/quickshell/void/scripts/voidline-share-picker" \
    "$(at /usr/bin/voidline-share-picker)"
install -m 755 "$repository/.config/quickshell/void/helpers/network-secret-helper" \
    "$(at /usr/lib/voidline/network-secret-helper)"

install -m 644 "$repository/.config/quickshell/void/helpers/org.voidline.network.policy" \
    "$(at /usr/share/polkit-1/actions/org.voidline.network.policy)"
# Stage the shell next to its final location and swap it in, so files removed
# upstream do not linger and a running shell never sees a half-copied tree.
shell_target=$(at /usr/share/voidline/quickshell)
shell_staging=$(at /usr/share/voidline/.quickshell.new)
shell_previous=$(at /usr/share/voidline/.quickshell.old)
rm -rf -- "$shell_staging" "$shell_previous"
cp -R "$repository/.config/quickshell/void/." "$shell_staging/"
find "$shell_staging" -type d -exec chmod 755 {} +
find "$shell_staging" -type f -exec chmod 644 {} +
find "$shell_staging/scripts" -type f \
    \( -name '*.sh' -o -name 'voidline-share-picker' \) -exec chmod 755 {} +
[ ! -d "$shell_target" ] || mv -- "$shell_target" "$shell_previous"
mv -- "$shell_staging" "$shell_target"
rm -rf -- "$shell_previous"

cp -R "$repository/.local/share/icons/Voidline/source/material-symbols/." \
    "$(at /usr/share/voidline/material-symbols/)"
find "$(at /usr/share/voidline/material-symbols)" -type f -exec chmod 644 {} +
cp -R "$repository/assets/wallpapers/." "$(at /usr/share/backgrounds/voidline/)"
find "$(at /usr/share/backgrounds/voidline)" -type f -exec chmod 644 {} +

install -m 644 "$repository/packaging/hypr/voidline.conf" \
    "$(at /usr/share/voidline/hypr/voidline.conf)"
install -m 644 "$repository/packaging/hypr/voidline.lua" \
    "$(at /usr/share/voidline/hypr/voidline.lua)"
install -m 644 "$repository/.config/xdg-desktop-portal/portals.conf" \
    "$(at /usr/share/voidline/xdg-desktop-portal/portals.conf)"
install -m 644 "$repository/VERSION" "$(at /usr/share/voidline/VERSION)"

for application in terminal settings; do
    install -m 644 "$repository/.local/share/applications/voidline-$application.desktop" \
        "$(at /usr/share/applications/voidline-$application.desktop)"
    install -m 644 "$repository/.local/share/icons/hicolor/scalable/apps/voidline-$application.svg" \
        "$(at /usr/share/icons/hicolor/scalable/apps/voidline-$application.svg)"
done

install -m 644 "$repository/.config/systemd/user/voidline-shell.service" \
    "$(at /usr/lib/systemd/user/voidline-shell.service)"
sed 's|@VOIDLINE_BACKEND@|/usr/lib/voidline/voidlined|g' \
    "$workspace/packaging/voidline-backend.service.in" \
    >"$(at /usr/lib/systemd/user/voidline-backend.service)"
chmod 644 "$(at /usr/lib/systemd/user/voidline-backend.service)"

if [ "$with_lyra" -eq 1 ]; then
    install -d -m 755 "$(at /usr/share/voidline/features)"
    install -m 755 "$repository/.local/bin/voidline-lyra" \
        "$(at /usr/bin/voidline-lyra)"
    install -m 644 "$repository/.local/share/applications/voidline-lyra.desktop" \
        "$(at /usr/share/applications/voidline-lyra.desktop)"
    install -m 644 "$repository/.local/share/icons/hicolor/scalable/apps/voidline-lyra.svg" \
        "$(at /usr/share/icons/hicolor/scalable/apps/voidline-lyra.svg)"
    install -m 644 "$repository/.local/share/voidline/features/ai.json" \
        "$(at /usr/share/voidline/features/ai.json)"
    install -m 644 "$repository/.config/systemd/user/voidline-ai.service" \
        "$(at /usr/lib/systemd/user/voidline-ai.service)"
else
    rm -f -- \
        "$(at /usr/bin/voidline-lyra)" \
        "$(at /usr/share/applications/voidline-lyra.desktop)" \
        "$(at /usr/share/icons/hicolor/scalable/apps/voidline-lyra.svg)" \
        "$(at /usr/share/voidline/features/ai.json)" \
        "$(at /usr/lib/systemd/user/voidline-ai.service)"
fi

install -m 644 "$repository/LICENSE" "$(at /usr/share/licenses/voidline/LICENSE)"
"$workspace/target/release/voidlinectl" completions bash \
    >"$(at /usr/share/bash-completion/completions/voidlinectl)"
"$workspace/target/release/voidlinectl" completions zsh \
    >"$(at /usr/share/zsh/site-functions/_voidlinectl)"
"$workspace/target/release/voidlinectl" completions fish \
    >"$(at /usr/share/fish/vendor_completions.d/voidlinectl.fish)"
chmod 644 \
    "$(at /usr/share/bash-completion/completions/voidlinectl)" \
    "$(at /usr/share/zsh/site-functions/_voidlinectl)" \
    "$(at /usr/share/fish/vendor_completions.d/voidlinectl.fish)"

printf 'Installed Voidline %s into %s.\n' \
    "$(tr -d '\r\n' <"$repository/VERSION")" "${destination:-/}"
