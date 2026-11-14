#!/usr/bin/env bash
# Voidline installer. Run as your normal user (never with sudo):
#
#   ./install.sh                 install the shell and hook it into your compositor(s)
#   ./install.sh --install-deps  also install missing packages with pacman (asks for sudo)
#   ./install.sh --sddm          install the Voidline login screen theme (asks for sudo)
#   ./install.sh --uninstall     remove Voidline and the lines it added
#
# It never replaces your compositor config. It copies one Voidline file next to
# it and adds a single include line, after making a backup.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
config=${XDG_CONFIG_HOME:-$HOME/.config}
shell_dir=$config/quickshell/voidline
stamp=$(date +%Y%m%d-%H%M%S)

say()  { printf '\033[1;35m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || die "Run this as your normal user, not with sudo."

required=(quickshell ttf-material-symbols-variable)
recommended=(inter-font papirus-icon-theme brightnessctl networkmanager bluez upower pipewire wireplumber
    libnotify grim slurp wl-clipboard cliphist wf-recorder swappy gammastep pacman-contrib
    xdg-desktop-portal xdg-desktop-portal-gtk)
# Screen sharing and file dialogs for apps need the portal of the compositor in use.
command -v Hyprland >/dev/null && recommended+=(xdg-desktop-portal-hyprland hyprsunset)
command -v niri >/dev/null && recommended+=(xdg-desktop-portal-gnome)

hypr_main=$config/hypr/hyprland.lua
hypr_line='require("voidline")'
niri_main=$config/niri/config.kdl
niri_line='include "voidline.kdl"'

missing() { local out=(); for p in "$@"; do pacman -Qq "$p" &>/dev/null || out+=("$p"); done; echo "${out[*]}"; }

unhook() { # file line
    [[ -f $1 ]] && grep -qxF "$2" "$1" || return 0
    cp "$1" "$1.voidline-bak-$stamp"
    grep -vxF "$2" "$1.voidline-bak-$stamp" > "$1" || true
    say "Removed Voidline line from $1"
}

hook() { # file line
    grep -qxF "$2" "$1" && return 0
    cp "$1" "$1.voidline-bak-$stamp"
    printf '\n%s\n' "$2" >> "$1"
    say "Added '$2' to $1 (backup: $(basename "$1").voidline-bak-$stamp)"
}

if [[ ${1:-} == --uninstall ]]; then
    unhook "$hypr_main" "$hypr_line"
    unhook "$niri_main" "$niri_line"
    rm -f "$config/hypr/voidline.lua" "$config/niri/voidline.kdl" "$config/hypr/voidline-settings.lua" "$config/niri/voidline-settings.kdl" "$HOME/.local/bin/voidlinectl" "${XDG_DATA_HOME:-$HOME/.local/share}/applications/voidline-settings.desktop"
    rm -rf "$shell_dir" "${XDG_DATA_HOME:-$HOME/.local/share}/icons/Voidline"
    say "Voidline removed. Your settings in $config/voidline were kept."
    exit 0
fi

if [[ ${1:-} == --sddm ]]; then
    command -v sddm >/dev/null || die "SDDM is not installed."
    say "Installing the login screen theme (needs sudo)"
    sudo mkdir -p /usr/share/sddm/themes /etc/sddm.conf.d
    sudo rm -rf /usr/share/sddm/themes/voidline
    sudo cp -r "$here/sddm/voidline" /usr/share/sddm/themes/voidline
    wall=${XDG_DATA_HOME:-$HOME/.local/share}/voidline/wallpapers/16x10/voidline-orbit.png
    [[ -f $wall ]] || wall=$here/assets/wallpapers/16x10/voidline-orbit.png
    sudo cp "$wall" /usr/share/sddm/themes/voidline/background.png
    printf '[Theme]\nCurrent=voidline\n' | sudo tee /etc/sddm.conf.d/voidline.conf >/dev/null
    say "Done. You see it at the next login. Remove /etc/sddm.conf.d/voidline.conf to go back."
    exit 0
fi

command -v pacman >/dev/null || die "Voidline currently supports Arch Linux (pacman not found)."

# --- packages -----------------------------------------------------------------
need=$(missing "${required[@]}")
want=$(missing "${recommended[@]}")
if [[ ${1:-} == --install-deps ]]; then
    if [[ -n "$need$want" ]]; then
        say "Installing: $need $want"
        # shellcheck disable=SC2086
        sudo pacman -S --needed $need $want
    fi
elif [[ -n $need ]]; then
    die "Missing required packages: $need  (re-run with --install-deps)"
elif [[ -n $want ]]; then
    warn "Optional packages not installed (some features stay hidden): $want"
fi

# --- shell --------------------------------------------------------------------
if [[ -e $shell_dir ]]; then
    mv "$shell_dir" "$shell_dir.bak-$stamp"
    say "Existing shell moved to $shell_dir.bak-$stamp"
fi
mkdir -p "$(dirname "$shell_dir")"
cp -r "$here/shell" "$shell_dir"
say "Shell installed to $shell_dir"

# --- wallpapers ---------------------------------------------------------------
papers=${XDG_DATA_HOME:-$HOME/.local/share}/voidline/wallpapers
mkdir -p "$papers"
for shape in 16x9 16x10; do
    mkdir -p "$papers/$shape"
    cp "$here"/assets/wallpapers/$shape/*.png "$papers/$shape/"
done
# Live wallpapers (QML packages); yours in the same folder are left alone.
mkdir -p "$papers/live"
cp -r "$here"/assets/wallpapers/live/. "$papers/live/"
say "Wallpapers copied to $papers"

# --- mouse pointer ------------------------------------------------------------
# The Voidline pointer theme; pick it in Settings > Apps & startup > Mouse pointer.
pointer=${XDG_DATA_HOME:-$HOME/.local/share}/icons/Voidline
rm -rf "$pointer"
mkdir -p "$pointer"
cp -r "$here"/assets/cursors/Voidline/. "$pointer/"
while read -r real aliases; do
    [[ -z $real || $real == \#* ]] && continue
    for a in $aliases; do ln -sf "$real" "$pointer/cursors/$a"; done
done < "$here/assets/cursors/aliases.txt"
# Icons live in the same theme folder, so "Voidline" is one theme for both.
cp -r "$here"/assets/icons/Voidline/. "$pointer/"
while read -r dir real aliases; do
    [[ -z $dir ]] && continue
    for a in $aliases; do ln -sf "$real" "$pointer/$dir/$a"; done
done < "$here/assets/icons/Voidline/aliases.txt"
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q -f "$pointer" 2>/dev/null || true
say "Mouse pointer and icon theme installed to $pointer"

# --- Files (Nautilus): right-click scripts ------------------------------------
if command -v nautilus >/dev/null; then
    scripts=${XDG_DATA_HOME:-$HOME/.local/share}/nautilus/scripts
    mkdir -p "$scripts"
    cp "$here"/assets/nautilus/scripts/* "$scripts/"
    chmod +x "$scripts"/*
    say "Files: added Scripts > Set as Voidline wallpaper, Open terminal here, Copy path"
fi

# --- launcher entry for Settings ------------------------------------------------
apps=${XDG_DATA_HOME:-$HOME/.local/share}/applications
mkdir -p "$apps"
cat > "$apps/voidline-settings.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Voidline Settings
Comment=Appearance, style and wallpaper of the Voidline shell
Exec=qs -c voidline ipc call shell settings
Icon=voidline-settings
Categories=Settings;
EOF

# --- compositors --------------------------------------------------------------
found=0
if command -v Hyprland >/dev/null || command -v hyprland >/dev/null; then
    found=1
    if [[ -f $hypr_main ]]; then
        cp "$here/config/hypr/voidline.lua" "$config/hypr/voidline.lua"
        # Filled in by the shell from Voidline Settings.
        [[ -f $config/hypr/voidline-settings.lua ]] || echo "-- Generated by Voidline Settings." > "$config/hypr/voidline-settings.lua"
        hook "$hypr_main" "$hypr_line"
    else
        warn "Hyprland found but $hypr_main does not exist (Voidline needs the Lua config, Hyprland 0.55+). Start Hyprland once, then re-run."
    fi
fi
if command -v niri >/dev/null; then
    found=1
    if [[ ! -f $niri_main && -f /usr/share/doc/niri/default-config.kdl ]]; then
        mkdir -p "$config/niri"
        cp /usr/share/doc/niri/default-config.kdl "$niri_main"
        say "Created $niri_main from Niri's default config"
    fi
    if [[ -f $niri_main ]]; then
        cp "$here/config/niri/voidline.kdl" "$config/niri/voidline.kdl"
        # Must exist before Niri reads the include; filled in by the shell.
        [[ -f $config/niri/voidline-settings.kdl ]] || echo "// Generated by Voidline Settings." > "$config/niri/voidline-settings.kdl"
        hook "$niri_main" "$niri_line"
        niri validate -c "$niri_main" >/dev/null 2>&1 || warn "niri reports a config problem: run 'niri validate'"
    fi
fi
[[ $found -eq 1 ]] || warn "No supported compositor found. Install hyprland or niri, then re-run."

# --- voidlinectl (optional) -----------------------------------------------------
if command -v cargo >/dev/null; then
    say "Building voidlinectl"
    cargo build --release --manifest-path "$here/helper/Cargo.toml" --quiet
    install -Dm755 "$here/helper/target/release/voidlinectl" "$HOME/.local/bin/voidlinectl"
    say "voidlinectl installed to ~/.local/bin"
else
    warn "Rust not installed: skipping voidlinectl (optional; the shell works without it)."
fi

say "Done. Log out and back in, or start it now with:  sh $shell_dir/start.sh"
say "Keys: Super+Space launcher, Super+A quick settings, Super+N minimise, Super+Shift+N restore, Super+Alt+S next style (change them in Settings > Keyboard shortcuts)"
