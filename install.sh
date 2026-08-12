#!/usr/bin/env bash
set -Eeuo pipefail

readonly VERSION=0.3.0dev
repository=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
mode=system
with_lyra=0
with_sddm=0
install_dependencies=0
start_shell=1
dry_run=0
non_interactive=0
lyra_was_set=0
sddm_was_set=0

usage() {
    cat <<'EOF'
Install Voidline 0.3.0dev on Arch Linux with Hyprland.

Usage: ./install.sh [options]

  --system          Install to /usr (default; recommended)
  --user            Install to $VOIDLINE_PREFIX or ~/.local
  --with-lyra       Install Lyra — Extreme Beta (no model is downloaded)
  --without-lyra    Explicitly omit/remove packaged Lyra integration
  --with-sddm       Install and select the matching SDDM theme (system only)
  --without-sddm    Do not change SDDM
  --install-deps    Install missing repository packages with pacman
  --no-start        Install without starting the shell user service
  --non-interactive Never prompt; optional components default to off
  --dry-run         Print the selected operation without building or writing
  -h, --help        Show this help

The installer does not modify shell startup files, download AI models, or
delete personal settings. Existing Hyprland files are backed up before edits.
EOF
}

while (($#)); do
    case "$1" in
        --system) mode=system ;;
        --user) mode=user ;;
        --with-lyra) with_lyra=1; lyra_was_set=1 ;;
        --without-lyra) with_lyra=0; lyra_was_set=1 ;;
        --with-sddm) with_sddm=1; sddm_was_set=1 ;;
        --without-sddm) with_sddm=0; sddm_was_set=1 ;;
        --install-deps) install_dependencies=1 ;;
        --no-start) start_shell=0 ;;
        --non-interactive) non_interactive=1 ;;
        --dry-run) dry_run=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 64 ;;
    esac
    shift
done

[[ -r /etc/arch-release ]] || {
    printf '%s\n' 'Voidline 0.3.0dev currently supports Arch Linux.' >&2
    exit 69
}
[[ -r "$repository/VERSION" ]] || {
    printf '%s\n' 'Run the installer from a complete Voidline source tree.' >&2
    exit 66
}
[[ $(tr -d '\r\n' <"$repository/VERSION") == "$VERSION" ]] || {
    printf '%s\n' 'Installer and repository versions do not match.' >&2
    exit 65
}

if [[ $non_interactive -eq 0 && -t 0 ]]; then
    if [[ $lyra_was_set -eq 0 ]]; then
        read -r -p 'Install Lyra — Extreme Beta? No model will be downloaded. [y/N] ' answer
        [[ ${answer,,} == y || ${answer,,} == yes ]] && with_lyra=1
    fi
    if [[ $mode == system && $sddm_was_set -eq 0 ]]; then
        read -r -p 'Install and select the Voidline SDDM theme? [y/N] ' answer
        [[ ${answer,,} == y || ${answer,,} == yes ]] && with_sddm=1
    fi
fi
[[ $mode == system || $with_sddm -eq 0 ]] || {
    printf '%s\n' 'The SDDM theme requires --system.' >&2
    exit 64
}

printf 'Voidline %s installation\n' "$VERSION"
printf '  Mode: %s\n' "$mode"
printf '  Lyra — Extreme Beta: %s\n' "$([[ $with_lyra -eq 1 ]] && printf yes || printf no)"
printf '  SDDM theme: %s\n' "$([[ $with_sddm -eq 1 ]] && printf yes || printf no)"
if [[ $dry_run -eq 1 ]]; then
    printf '%s\n' 'Dry run complete; no files were changed.'
    exit 0
fi

required_packages=(
    rust pkgconf gcc gtk4 vte4 networkmanager polkit
    pipewire wireplumber bluez bluez-utils brightnessctl playerctl jq curl
    wl-clipboard cliphist grim slurp libnotify upower
)
optional_packages=(wf-recorder hyprpicker ddcutil cups sane-airscan)
[[ $with_sddm -eq 1 ]] && required_packages+=(sddm)

missing=()
for package in "${required_packages[@]}"; do
    pacman -Qq "$package" >/dev/null 2>&1 || missing+=("$package")
done
if ((${#missing[@]})); then
    if [[ $install_dependencies -eq 0 ]]; then
        printf 'Missing required packages: %s\n' "${missing[*]}" >&2
        printf '%s\n' 'Re-run with --install-deps, or install them first.' >&2
        exit 69
    fi
    official=()
    unavailable=()
    for package in "${missing[@]}"; do
        if pacman -Si "$package" >/dev/null 2>&1; then
            official+=("$package")
        else
            unavailable+=("$package")
        fi
    done
    if ((${#official[@]})); then
        sudo pacman -S --needed "${official[@]}"
    fi
    if ((${#unavailable[@]})); then
        printf 'These required packages are not in enabled pacman repositories: %s\n' \
            "${unavailable[*]}" >&2
        printf '%s\n' 'Install them from a trusted Arch/AUR source, then re-run the installer.' >&2
        exit 69
    fi
fi

required_commands=(cargo pkg-config cc quickshell hyprctl)
[[ $with_lyra -eq 1 ]] && required_commands+=(ollama)
missing_commands=()
for executable in "${required_commands[@]}"; do
    command -v "$executable" >/dev/null 2>&1 || missing_commands+=("$executable")
done
if ((${#missing_commands[@]})); then
    printf 'Missing required commands: %s\n' "${missing_commands[*]}" >&2
    printf '%s\n' 'Quickshell and Ollama may use distribution or AUR package names different from their executable names.' >&2
    exit 69
fi

for package in ttf-roboto-flex ttf-material-symbols-variable papirus-icon-theme; do
    pacman -Qq "$package" >/dev/null 2>&1 || \
        printf 'Recommended package not installed: %s\n' "$package" >&2
done
for package in "${optional_packages[@]}"; do
    pacman -Qq "$package" >/dev/null 2>&1 || \
        printf 'Optional integration unavailable until installed: %s\n' "$package"
done

printf '%s\n' 'Building the validated Rust backend, CLI, terminal, and NetworkManager helper…'
cargo build --locked --release --workspace \
    --manifest-path "$repository/backend/Cargo.toml"
"$repository/backend/build-network-helper.sh"

if [[ $mode == system ]]; then
    sudo env VOIDLINE_WITH_LYRA="$with_lyra" \
        "$repository/backend/install-system.sh"
else
    VOIDLINE_WITH_LYRA="$with_lyra" \
        "$repository/backend/install-user.sh"
fi

state_home=${XDG_STATE_HOME:-$HOME/.local/state}
backup_root="$state_home/voidline/backups/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p -- "$backup_root"
chmod 700 "$state_home/voidline" "$state_home/voidline/backups" "$backup_root"
backup_file() {
    local source=$1 name=$2
    [[ -e $source ]] || return 0
    cp -a -- "$source" "$backup_root/$name"
    printf 'Backed up %s to %s\n' "$source" "$backup_root/$name"
}

config_home=${XDG_CONFIG_HOME:-$HOME/.config}
mkdir -p -- "$config_home/hypr" "$config_home/xdg-desktop-portal"
if [[ $mode == system ]]; then
    installed_hypr=/usr/share/voidline/hypr
    installed_portal=/usr/share/voidline/xdg-desktop-portal/portals.conf
else
    prefix=${VOIDLINE_PREFIX:-$HOME/.local}
    installed_hypr=$prefix/share/voidline/hypr
    installed_portal=$prefix/share/voidline/xdg-desktop-portal/portals.conf
fi

for integration in voidline.conf voidline.lua; do
    target="$config_home/hypr/$integration"
    if [[ -e $target ]] && ! cmp -s -- "$installed_hypr/$integration" "$target"; then
        backup_file "$target" "hypr-$integration"
    fi
    install -m 644 "$installed_hypr/$integration" "$target"
done

if ! grep -Rqs 'quickshell:toggleLauncher' \
        "$config_home/hypr/hyprland.conf" "$config_home/hypr/hyprland.lua" 2>/dev/null; then
    if [[ -f $config_home/hypr/hyprland.lua ]]; then
        main_config="$config_home/hypr/hyprland.lua"
        backup_file "$main_config" hyprland.lua
        printf '\n-- Added by Voidline %s\nrequire("voidline")\n' "$VERSION" >>"$main_config"
    elif [[ -f $config_home/hypr/hyprland.conf ]]; then
        main_config="$config_home/hypr/hyprland.conf"
        backup_file "$main_config" hyprland.conf
        printf '\n# Added by Voidline %s\nsource = ~/.config/hypr/voidline.conf\n' \
            "$VERSION" >>"$main_config"
    else
        printf '%s\n' 'No main Hyprland config was found. Integration templates were installed under ~/.config/hypr.' >&2
    fi
fi

portal_target="$config_home/xdg-desktop-portal/portals.conf"
if [[ ! -e $portal_target ]]; then
    install -m 644 "$installed_portal" "$portal_target"
elif ! cmp -s -- "$installed_portal" "$portal_target"; then
    printf '%s\n' 'Existing xdg-desktop-portal configuration was preserved.'
fi

# Old source-tree service overrides take precedence over packaged units. Keep a
# recoverable copy, then let systemd use the installed release unit.
if [[ $mode == system ]]; then
    for service in voidline-shell.service voidline-backend.service voidline-ai.service; do
        override="$config_home/systemd/user/$service"
        if [[ -f $override ]] && grep -qs 'Voidline' "$override"; then
            backup_file "$override" "user-$service"
            rm -f -- "$override"
        fi
    done
fi

if [[ $with_sddm -eq 1 ]]; then
    sudo "$repository/sddm/install.sh"
fi

systemctl --user daemon-reload
if [[ $start_shell -eq 1 ]]; then
    systemctl --user enable --now voidline-shell.service
    systemctl --user try-restart voidline-shell.service || true
fi
if [[ $with_lyra -eq 0 ]]; then
    systemctl --user stop voidline-ai.service 2>/dev/null || true
fi
command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1 || true
if [[ $mode == system ]]; then
    command -v update-desktop-database >/dev/null 2>&1 && \
        sudo update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
    command -v gtk-update-icon-cache >/dev/null 2>&1 && \
        sudo gtk-update-icon-cache -f -t /usr/share/icons/hicolor >/dev/null 2>&1 || true
else
    command -v update-desktop-database >/dev/null 2>&1 && \
        update-desktop-database "$prefix/share/applications" >/dev/null 2>&1 || true
    command -v gtk-update-icon-cache >/dev/null 2>&1 && \
        gtk-update-icon-cache -f -t "$prefix/share/icons/hicolor" >/dev/null 2>&1 || true
fi

printf '\nVoidline %s installed successfully.\n' "$VERSION"
printf '%s\n' 'Try: voidlinectl status'
printf '%s\n' 'Settings: voidline-settings'
printf '%s\n' 'Terminal: voidline-terminal'
if [[ -n ${main_config:-} ]]; then
    printf 'Hyprland configuration backup: %s\n' "$backup_root"
fi
