#!/bin/sh
set -eu

workspace=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repository=$(CDPATH= cd -- "$workspace/.." && pwd)
prefix=${VOIDLINE_PREFIX:-${HOME:?}/.local}
with_lyra=${VOIDLINE_WITH_LYRA:-0}
case "$prefix" in /*) ;; *)
    printf '%s\n' 'VOIDLINE_PREFIX must be an absolute path.' >&2; exit 64
esac
[ "$prefix" != / ] || {
    printf '%s\n' 'Refusing to use the filesystem root as VOIDLINE_PREFIX.' >&2
    exit 64
}
case "$with_lyra" in 0|1) ;; *)
    printf '%s\n' 'VOIDLINE_WITH_LYRA must be 0 or 1.' >&2; exit 64
esac

command -v cargo >/dev/null 2>&1 || {
    printf '%s\n' 'Rust is required: sudo pacman -S --needed rust pkgconf vte4' >&2
    exit 69
}

# /install.sh builds before calling this script; a direct invocation builds
# here. The target directory is pinned because the steps below read from it.
if [ "${VOIDLINE_SKIP_BUILD:-0}" != 1 ]; then
    CARGO_TARGET_DIR="$workspace/target" cargo build --locked --release \
        --manifest-path "$workspace/Cargo.toml" --workspace
    "$workspace/build-network-helper.sh"
fi
for binary in voidlined voidlinectl voidline-terminal voidline-network; do
    [ -x "$workspace/target/release/$binary" ] || {
        printf 'Missing release binary: %s\n' "$binary" >&2
        exit 66
    }
done
install -d -m 755 \
    "$prefix/lib/voidline" \
    "$prefix/bin" \
    "$prefix/share/voidline/material-symbols" \
    "$prefix/share/voidline/hypr" \
    "$prefix/share/voidline/xdg-desktop-portal" \
    "$prefix/share/backgrounds/voidline" \
    "$prefix/share/applications" \
    "$prefix/share/icons/hicolor/scalable/apps" \
    "$prefix/share/licenses/voidline" \
    "$prefix/share/systemd/user" \
    "$prefix/share/bash-completion/completions" \
    "$prefix/share/zsh/site-functions" \
    "$prefix/share/fish/vendor_completions.d"

install -m 755 "$workspace/target/release/voidlined" "$prefix/lib/voidline/voidlined"
install -m 755 "$workspace/target/release/voidline-terminal" "$prefix/lib/voidline/voidline-terminal"
install -m 755 "$workspace/target/release/voidline-network" "$prefix/lib/voidline/voidline-network"
install -m 755 "$workspace/target/release/voidlinectl" "$prefix/bin/voidlinectl"
for launcher in voidline-terminal voidline-settings voidline-shell voidline-display-safe-mode; do
    install -m 755 "$repository/.local/bin/$launcher" "$prefix/bin/$launcher"
done
install -m 755 "$repository/.config/quickshell/void/scripts/voidline-share-picker" \
    "$prefix/bin/voidline-share-picker"

# Stage the shell next to its final location and swap it in, so files removed
# upstream do not linger and a running shell never sees a half-copied tree.
shell_target="$prefix/share/voidline/quickshell"
shell_staging="$prefix/share/voidline/.quickshell.new"
rm -rf -- "$shell_staging" "$prefix/share/voidline/.quickshell.old"
cp -R "$repository/.config/quickshell/void/." "$shell_staging/"
find "$shell_staging" -type d -exec chmod 755 {} +
find "$shell_staging" -type f -exec chmod 644 {} +
find "$shell_staging/scripts" -type f \
    \( -name '*.sh' -o -name 'voidline-share-picker' \) -exec chmod 755 {} +
[ ! -d "$shell_target" ] || mv -- "$shell_target" "$prefix/share/voidline/.quickshell.old"
mv -- "$shell_staging" "$shell_target"
rm -rf -- "$prefix/share/voidline/.quickshell.old"
cp -R "$repository/.local/share/icons/Voidline/source/material-symbols/." \
    "$prefix/share/voidline/material-symbols/"
cp -R "$repository/assets/wallpapers/." "$prefix/share/backgrounds/voidline/"
install -m 644 "$repository/packaging/hypr/voidline.conf" "$prefix/share/voidline/hypr/voidline.conf"
install -m 644 "$repository/packaging/hypr/voidline.lua" "$prefix/share/voidline/hypr/voidline.lua"
install -m 644 "$repository/.config/xdg-desktop-portal/portals.conf" \
    "$prefix/share/voidline/xdg-desktop-portal/portals.conf"
install -m 644 "$repository/VERSION" "$prefix/share/voidline/VERSION"
install -m 644 "$repository/LICENSE" "$prefix/share/licenses/voidline/LICENSE"

for application in terminal settings; do
    install -m 644 "$repository/.local/share/applications/voidline-$application.desktop" \
        "$prefix/share/applications/voidline-$application.desktop"
    install -m 644 "$repository/.local/share/icons/hicolor/scalable/apps/voidline-$application.svg" \
        "$prefix/share/icons/hicolor/scalable/apps/voidline-$application.svg"
done

sed "s|ExecStart=/usr/bin/voidline-shell|ExecStart=$prefix/bin/voidline-shell|" \
    "$repository/.config/systemd/user/voidline-shell.service" \
    >"$prefix/share/systemd/user/voidline-shell.service"
sed "s|@VOIDLINE_BACKEND@|$prefix/lib/voidline/voidlined|g" \
    "$workspace/packaging/voidline-backend.service.in" \
    >"$prefix/share/systemd/user/voidline-backend.service"
chmod 644 "$prefix/share/systemd/user/voidline-shell.service" \
    "$prefix/share/systemd/user/voidline-backend.service"

if [ "$with_lyra" -eq 1 ]; then
    install -d -m 755 "$prefix/share/voidline/features"
    install -m 755 "$repository/.local/bin/voidline-lyra" "$prefix/bin/voidline-lyra"
    install -m 644 "$repository/.local/share/applications/voidline-lyra.desktop" \
        "$prefix/share/applications/voidline-lyra.desktop"
    install -m 644 "$repository/.local/share/icons/hicolor/scalable/apps/voidline-lyra.svg" \
        "$prefix/share/icons/hicolor/scalable/apps/voidline-lyra.svg"
    install -m 644 "$repository/.local/share/voidline/features/ai.json" \
        "$prefix/share/voidline/features/ai.json"
    install -m 644 "$repository/.config/systemd/user/voidline-ai.service" \
        "$prefix/share/systemd/user/voidline-ai.service"
else
    rm -f -- \
        "$prefix/bin/voidline-lyra" \
        "$prefix/share/applications/voidline-lyra.desktop" \
        "$prefix/share/icons/hicolor/scalable/apps/voidline-lyra.svg" \
        "$prefix/share/voidline/features/ai.json" \
        "$prefix/share/systemd/user/voidline-ai.service"
fi

"$prefix/bin/voidlinectl" completions bash >"$prefix/share/bash-completion/completions/voidlinectl"
"$prefix/bin/voidlinectl" completions zsh >"$prefix/share/zsh/site-functions/_voidlinectl"
"$prefix/bin/voidlinectl" completions fish >"$prefix/share/fish/vendor_completions.d/voidlinectl.fish"
systemctl --user daemon-reload 2>/dev/null || true

case ":${PATH:-}:" in *":$prefix/bin:"*) ;; *)
    printf 'Warning: %s is not currently on PATH.\n' "$prefix/bin" >&2
    printf '%s\n' 'No shell startup file was modified; prefer the system installation for /usr/bin.' >&2
esac
printf 'Installed Voidline %s under %s.\n' "$(tr -d '\r\n' <"$repository/VERSION")" "$prefix"
printf '%s\n' 'User installs cannot provide the system Polkit helper or SDDM theme.'
