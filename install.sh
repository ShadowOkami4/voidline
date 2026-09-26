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

if [[ -t 1 ]]; then
    bold=$'\e[1m' dim=$'\e[2m' red=$'\e[31m' yellow=$'\e[33m' green=$'\e[32m' reset=$'\e[0m'
else
    bold='' dim='' red='' yellow='' green='' reset=''
fi
step() { printf '\n%s==> %s%s\n' "$bold" "$*" "$reset"; }
note() { printf '%s  • %s%s\n' "$dim" "$*" "$reset"; }
warn() { printf '%sWarning:%s %s\n' "$yellow" "$reset" "$*" >&2; }
die() {
    local status=$1
    shift
    printf '%sError:%s %s\n' "$red" "$reset" "$*" >&2
    exit "$status"
}
on_error() {
    local status=$? line=$1 command=$2
    printf '\n%sInstallation failed%s (exit %s) at install.sh:%s\n  %s\n' \
        "$red" "$reset" "$status" "$line" "$command" >&2
    printf '%s\n' 'Nothing outside the steps shown above was changed. Fix the error and re-run the installer.' >&2
}
trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR

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
  --install-deps    Install missing packages with pacman (and an AUR helper
                    such as paru or yay for packages not in the repositories)
  --no-start        Install without starting the shell user service
  --non-interactive Never prompt; optional components default to off
  --dry-run         Print the selected operation without building or writing
  -h, --help        Show this help

Run the installer as your normal desktop user, not with sudo. It asks for
sudo only for the packaged files under /usr.

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

# Running as root would build into root-owned directories and configure
# Hyprland and the user services for root instead of the desktop user.
((EUID != 0)) || die 77 'Run ./install.sh as your normal desktop user, not as root or with sudo. It uses sudo itself where needed.'
[[ -r /etc/arch-release ]] || die 69 'Voidline 0.3.0dev currently supports Arch Linux.'
[[ -r "$repository/VERSION" ]] || die 66 'Run the installer from a complete Voidline source tree.'
[[ $(tr -d '\r\n' <"$repository/VERSION") == "$VERSION" ]] || \
    die 65 'Installer and repository versions do not match.'

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
[[ $mode == system || $with_sddm -eq 0 ]] || die 64 'The SDDM theme requires --system.'

printf '%sVoidline %s installation%s\n' "$bold" "$VERSION" "$reset"
printf '  Mode: %s\n' "$mode"
printf '  Lyra — Extreme Beta: %s\n' "$([[ $with_lyra -eq 1 ]] && printf yes || printf no)"
printf '  SDDM theme: %s\n' "$([[ $with_sddm -eq 1 ]] && printf yes || printf no)"
if [[ $dry_run -eq 1 ]]; then
    printf '%s\n' 'Dry run complete; no files were changed.'
    exit 0
fi

if [[ $mode == system || $with_sddm -eq 1 || $install_dependencies -eq 1 ]]; then
    command -v sudo >/dev/null 2>&1 || die 69 'sudo is required for a system install and for --install-deps.'
fi

# ---------------------------------------------------------------------------
step 'Checking dependencies'

# Runtime packages. Build tooling is checked by capability below so that a
# rustup toolchain is accepted instead of forcing the conflicting rust package.
required_packages=(
    hyprland quickshell xdg-desktop-portal-hyprland
    networkmanager polkit pipewire wireplumber bluez bluez-utils
    brightnessctl playerctl jq curl wl-clipboard cliphist grim slurp
    libnotify upower gtk4 vte4 glib2
)
optional_packages=(wf-recorder hyprpicker ddcutil cups sane-airscan)
[[ $with_sddm -eq 1 ]] && required_packages+=(sddm)
[[ $with_lyra -eq 1 ]] && required_packages+=(ollama)
command -v cargo >/dev/null 2>&1 || required_packages+=(rust)
command -v pkg-config >/dev/null 2>&1 || required_packages+=(pkgconf)
command -v cc >/dev/null 2>&1 || required_packages+=(gcc)

package_installed() {
    # `pacman -T` also resolves provides, so e.g. quickshell-git satisfies
    # quickshell and ollama-vulkan satisfies ollama.
    pacman -T "$1" >/dev/null 2>&1
}

missing=()
for package in "${required_packages[@]}"; do
    package_installed "$package" || missing+=("$package")
done
if ((${#missing[@]})); then
    if [[ $install_dependencies -eq 0 ]]; then
        printf 'Missing required packages: %s\n' "${missing[*]}" >&2
        die 69 'Re-run with --install-deps, or install them first.'
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
        note "Installing from the Arch repositories: ${official[*]}"
        sudo pacman -S --needed "${official[@]}"
    fi
    if ((${#unavailable[@]})); then
        aur_helper=
        for helper in paru yay; do
            command -v "$helper" >/dev/null 2>&1 && { aur_helper=$helper; break; }
        done
        [[ -n $aur_helper ]] || die 69 \
            "These required packages are not in the enabled pacman repositories: ${unavailable[*]}. Install them from the AUR (for example with paru or yay), then re-run the installer."
        note "Installing from the AUR with $aur_helper: ${unavailable[*]}"
        "$aur_helper" -S --needed "${unavailable[@]}"
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
    [[ " ${missing_commands[*]} " == *' cargo '* ]] && \
        printf '%s\n' 'With rustup, run: rustup default stable' >&2
    die 69 'Quickshell and Ollama may use distribution or AUR package names different from their executable names.'
fi
missing_libraries=()
for library in gtk4 vte-2.91-gtk4 libnm gio-unix-2.0; do
    pkg-config --exists "$library" || missing_libraries+=("$library")
done
((${#missing_libraries[@]} == 0)) || \
    die 69 "Missing development files (pkg-config): ${missing_libraries[*]}. Install gtk4, vte4, networkmanager, and glib2."

for package in ttf-roboto-flex ttf-material-symbols-variable papirus-icon-theme; do
    package_installed "$package" || warn "Recommended package not installed: $package"
done
for package in "${optional_packages[@]}"; do
    package_installed "$package" || note "Optional integration unavailable until installed: $package"
done

# ---------------------------------------------------------------------------
step 'Building the Rust backend, CLI, terminal, and NetworkManager helper'

# The install steps read binaries from backend/target/release. Pin the target
# directory so CARGO_TARGET_DIR or a global cargo `build.target-dir` cannot
# send the build somewhere the install step does not look.
target_directory="$repository/backend/target"
if [[ -e $target_directory && ! -w $target_directory ]]; then
    die 73 "$target_directory is not writable (probably left over from a sudo build). Remove it with: sudo rm -rf '$target_directory'"
fi
CARGO_TARGET_DIR="$target_directory" cargo build --locked --release --workspace \
    --manifest-path "$repository/backend/Cargo.toml"
"$repository/backend/build-network-helper.sh"

# ---------------------------------------------------------------------------
step "Installing Voidline files ($mode)"
if [[ $mode == system ]]; then
    sudo env VOIDLINE_WITH_LYRA="$with_lyra" \
        "$repository/backend/install-system.sh"
else
    VOIDLINE_WITH_LYRA="$with_lyra" VOIDLINE_SKIP_BUILD=1 \
        "$repository/backend/install-user.sh"
fi

# ---------------------------------------------------------------------------
step 'Configuring Hyprland integration'

state_home=${XDG_STATE_HOME:-$HOME/.local/state}
backup_root="$state_home/voidline/backups/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p -- "$backup_root"
chmod 700 "$state_home/voidline" "$state_home/voidline/backups" "$backup_root"
backed_up=0
backup_file() {
    local source=$1 name=$2
    [[ -e $source ]] || return 0
    cp -a -- "$source" "$backup_root/$name"
    backed_up=1
    note "Backed up $source to $backup_root/$name"
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

# Rewrite a file through a temporary copy so an interrupted install never
# leaves a truncated Hyprland config behind.
replace_file() {
    local target temporary
    # Follow symlinks so dotfile managers (stow, chezmoi links) keep working.
    target=$(readlink -f -- "$1")
    temporary=$(mktemp "$(dirname -- "$target")/.voidline-install.XXXXXX")
    cat >"$temporary"
    chmod --reference="$target" "$temporary" 2>/dev/null || chmod 644 "$temporary"
    mv -f -- "$temporary" "$target"
}

# Earlier installers appended the integration line on every run, which bound
# every shortcut several times so toggles opened and immediately closed.
# Remove every previous Voidline block (any version) and append exactly one.
strip_marker_blocks() {
    local comment=$1 file=$2
    awk -v marker="^${comment} Added by Voidline " '
        skip { skip = 0; next }
        $0 ~ marker { skip = 1; next }
        { print }
    ' "$file" | awk '
        # Drop the blank separator lines the removed blocks leave at the end.
        { lines[NR] = $0 }
        END {
            last = NR
            while (last > 0 && lines[last] == "") last--
            for (i = 1; i <= last; i++) print lines[i]
        }
    '
}

main_config=
if [[ -f $config_home/hypr/hyprland.lua ]]; then
    main_config="$config_home/hypr/hyprland.lua"
    comment='--'
    integration_line='require("voidline")'
elif [[ -f $config_home/hypr/hyprland.conf ]]; then
    main_config="$config_home/hypr/hyprland.conf"
    comment='#'
    integration_line='source = ~/.config/hypr/voidline.conf'
fi

if [[ -z $main_config ]]; then
    warn 'No main Hyprland config was found. Integration templates were installed under ~/.config/hypr.'
elif grep -qs 'quickshell:toggleLauncher' "$main_config" && \
        ! grep -qs "^${comment} Added by Voidline " "$main_config"; then
    note "$main_config already defines Voidline shortcuts; it was left unchanged."
else
    updated=$(strip_marker_blocks "$comment" "$main_config"
        printf '\n%s Added by Voidline %s\n%s\n' "$comment" "$VERSION" "$integration_line")
    if [[ $updated != "$(cat -- "$main_config")" ]]; then
        backup_file "$main_config" "$(basename -- "$main_config")"
        printf '%s\n' "$updated" | replace_file "$main_config"
        note "Linked Voidline from $main_config"
    else
        note "$main_config already includes Voidline."
    fi
fi

portal_target="$config_home/xdg-desktop-portal/portals.conf"
if [[ ! -e $portal_target ]]; then
    install -m 644 "$installed_portal" "$portal_target"
elif ! cmp -s -- "$installed_portal" "$portal_target"; then
    note 'Existing xdg-desktop-portal configuration was preserved.'
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
((backed_up)) || rmdir -- "$backup_root" 2>/dev/null || true

if [[ $with_sddm -eq 1 ]]; then
    step 'Installing the SDDM theme'
    sudo "$repository/sddm/install.sh"
fi

# ---------------------------------------------------------------------------
step 'Refreshing services and caches'

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

# systemctl --user needs the user's service manager. It is missing from a
# plain TTY/SSH login without lingering, which previously aborted the install
# after every file had already been written.
shell_started=0
if systemctl --user show-environment >/dev/null 2>&1; then
    systemctl --user daemon-reload
    if [[ $with_lyra -eq 0 ]]; then
        systemctl --user stop voidline-ai.service 2>/dev/null || true
    fi
    if [[ $start_shell -eq 1 ]]; then
        systemctl --user enable voidline-shell.service >/dev/null 2>&1 || \
            warn 'Could not enable voidline-shell.service; Hyprland still starts it through the integration file.'
        if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
            if systemctl --user is-active --quiet voidline-shell.service; then
                systemctl --user restart voidline-shell.service || \
                    warn 'The shell did not restart; check: journalctl --user -u voidline-shell'
            else
                systemctl --user start voidline-shell.service || \
                    warn 'The shell did not start; check: journalctl --user -u voidline-shell'
            fi
            systemctl --user is-active --quiet voidline-shell.service && shell_started=1
        else
            note 'Not inside a Hyprland session; the shell starts with your next Hyprland login.'
        fi
    fi
else
    warn 'No systemd user session is reachable; services will be picked up at your next graphical login.'
fi
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 || true
fi

if [[ $mode == user && ${VOIDLINE_PREFIX:-$HOME/.local} != "$HOME/.local" ]]; then
    warn "systemd only reads user units from ~/.local/share/systemd/user; link $prefix/share/systemd/user/*.service there to use them."
fi

printf '\n%sVoidline %s installed successfully.%s\n' "$green$bold" "$VERSION" "$reset"
((shell_started)) && printf '%s\n' 'The shell is running.'
printf '%s\n' 'Try: voidlinectl status'
printf '%s\n' 'Settings: voidline-settings'
printf '%s\n' 'Terminal: voidline-terminal'
if ((backed_up)); then
    printf 'Backups of changed files: %s\n' "$backup_root"
fi
