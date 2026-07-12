#!/bin/bash
# Arch Dotfiles Reset

if [[ "$EUID" -eq 0 ]]; then
    echo -e "\e[31mDo not run this script as root.\e[0m"
    exit 1
fi

DOTDIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"

source "$DOTDIR/helpers/setup-helpers.sh"

echo -e "${COLOR_RED}Arch Dotfiles Reset${RST}"
echo -e "${COLOR_YELLOW}This will UNDO everything setup.sh configured.${RST}\n"

_print_header "Pre-flight" ""
read -p "$(echo -e "${COLOR_YELLOW}Are you sure you want to reset? [y/N]: ${RST}")" confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { info "Aborted."; echo ""; exit 0; }
echo ""

_print_header "Sudo Authentication" ""
sudo -v || { err "Sudo authentication failed."; exit 1; }
ok "Sudo authenticated."
echo ""

# Remove Environment Variable
_print_header "Environment Variable" ""

if [[ -f "/etc/profile.d/arch-config.sh" ]]; then
    sudo rm -f /etc/profile.d/arch-config.sh
    ok "Removed ARCH_CONFIG_PATH (/etc/profile.d/arch-config.sh)"
else
    info "ARCH_CONFIG_PATH file not found, skipping."
fi
echo ""

# Home Files
_print_header "Removing Home Files" ""

_home_file_action() {
    local src="$1" target="$2"
    if [[ -L "$target" ]]; then
        rm "$target"
        ok "Removed symlink: ${target/#$HOME/\~}"

        local backups=("$target".bak.*)
        if [[ -e "${backups[0]}" ]]; then
            local latest="${backups[-1]}"
            mv "$latest" "$target"
            ok "Restored backup: ${target/#$HOME/\~}"
            if [[ ${#backups[@]} -gt 1 ]]; then
                info "$(( ${#backups[@]} - 1 )) older backup(s) of ${target/#$HOME/\~} remain, not auto-restored"
            fi
        fi
    else
        info "Not a symlink, skipping: ${target/#$HOME/\~}"
    fi
}
_each_home_file
echo ""

# Scripts
_print_header "Removing Scripts" ""

_script_file_action() {
    local name="$1" src="$2"
    if [[ -L "/usr/local/bin/$name" ]]; then
        sudo rm -f "/usr/local/bin/$name"
        ok "Removed $name from /usr/local/bin."
    else
        info "$name symlink not found, skipping."
    fi
}
_each_script_file
echo ""

# Etc Files
_print_header "Removing Etc Files" ""

_etc_file_action() {
    local src="$1" dest="$2"
    if [[ -f "$dest" ]]; then
        sudo rm -f "$dest"
        ok "Removed policy: $dest"
    else
        info "Policy not found, skipping: $dest"
    fi
}
_each_etc_file
echo ""

# Remove Sudoers Rule
_print_header "Passwordless updatedb" ""

SUDOERS_FILE="/etc/sudoers.d/updatedb-nopasswd"
if [[ -f "$SUDOERS_FILE" ]]; then
    sudo rm -f "$SUDOERS_FILE"
    ok "Removed sudoers rule."
else
    info "Sudoers rule not found, skipping."
fi
echo ""

# Remove Pacman Candy
_print_header "Pacman Config" ""

if grep -q "ILoveCandy" /etc/pacman.conf; then
    sudo sed -i '/^ILoveCandy/d' /etc/pacman.conf
    ok "ILoveCandy removed from pacman.conf"
else
    info "ILoveCandy not found, skipping."
fi
echo ""

# Stop and Remove wgm
_print_header "wgm / WARP" ""

source "$DOTDIR/scripts/wgm/wgm-helper.sh"
_wgm_set_paths "$HOME"
WGM_BACKUP="$BACKUP_ROOT"

active=$(_get_active_tunnel)

if [[ -n "$active" ]]; then
    sudo systemctl disable --now "wg-quick@$active"
    [ $? -eq 0 ] && ok "Stopped tunnel: $active" || err "Failed to stop tunnel: $active"
    sudo rm -f "$WG_DIR/$active.conf"
else
    info "No active tunnel found, skipping."
fi

if sudo test -d "$CONFIGS_DIR"; then
    shopt -s nullglob
    confs=("$CONFIGS_DIR"/*.conf)
    shopt -u nullglob
    if [[ ${#confs[@]} -gt 0 ]]; then
        sudo mkdir -p "$WGM_BACKUP"
        for conf in "${confs[@]}"; do
            sudo cp "$conf" "$WGM_BACKUP/"
            ok "Backed up: $(basename "$conf")"
        done
        sudo chown -R "$USER:$USER" "$WGM_BACKUP"
        ok "User configs backed up to $WGM_BACKUP"
    fi
fi

sudo test -d "$WGM_ROOT" && sudo rm -rf "$WGM_ROOT" && ok "Removed ~/.config/arch-config-files/wgm"
echo ""

# Remove wpm tunnels
_print_header "wpm" ""

shopt -s nullglob
services=(/etc/systemd/system/*-wpm.service)
shopt -u nullglob
if [[ ${#services[@]} -gt 0 ]]; then
    read -p "$(echo -e "${COLOR_YELLOW}Found ${#services[@]} wpm tunnel(s). Stop and remove them? [y/N]: ${RST}")" remove_services
    if [[ "$remove_services" =~ ^[Yy]$ ]]; then
        echo ""
        source "$DOTDIR/scripts/wpm/wpm-helper.sh"
        _wpm_set_paths "$HOME"
        BACKUP_DIR="$BACKUP_ROOT"
        if [[ -d "$CONF_DIR" ]]; then
            CONFS=$(sudo find "$CONF_DIR" -maxdepth 1 -name "*.conf" 2>/dev/null)
            if [[ -n "$CONFS" ]]; then
                mkdir -p "$BACKUP_DIR"
                sudo cp "$CONF_DIR"/*.conf "$BACKUP_DIR/"
                sudo chmod 644 "$BACKUP_DIR/"*.conf
                sudo chown "$USER:$USER" "$BACKUP_DIR/"*.conf
                ok "Configs backed up to $BACKUP_DIR"
            fi
        fi
        for service in "${services[@]}"; do
            NAME=$(basename "$service" .service)
            sudo systemctl stop "$NAME"
            sudo systemctl disable "$NAME"
            sudo rm -f "$service"
            ok "Removed tunnel: $NAME"
        done
        sudo rm -rf "$CONF_DIR"
        sudo systemctl daemon-reload
        ok "All tunnels removed."
    else
        info "Skipping tunnel removal."
    fi
else
    info "No wpm tunnels found, skipping."
fi
echo ""

# Remove Chaotic-AUR
_print_header "Chaotic-AUR" ""

if grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
    sudo sed -i '/\[chaotic-aur\]/,/Include.*chaotic-mirrorlist/d' /etc/pacman.conf
    sudo pacman -Rns --noconfirm chaotic-keyring chaotic-mirrorlist
    sudo pacman -Syy
    ok "Chaotic-AUR removed."
else
    info "Chaotic-AUR not configured, skipping."
fi
echo ""

# Remove Wallpapers
_print_header "Wallpapers" ""

WALLPAPERS_DIR="$HOME/Pictures/config-wallpapers"
if [[ -d "$WALLPAPERS_DIR" ]]; then
    read -p "$(echo -e "${COLOR_YELLOW}Remove wallpapers directory? [y/N]: ${RST}")" remove_wallpapers
    if [[ "$remove_wallpapers" =~ ^[Yy]$ ]]; then
        rm -rf "$WALLPAPERS_DIR"
        ok "Wallpapers removed."
    else
        info "Skipping wallpapers removal."
    fi
else
    info "Wallpapers directory not found, skipping."
fi
echo ""

# Restore Theme & Font Defaults
_print_header "Restoring Theme & Font Defaults" ""

for entry in "${THEME_SETTINGS[@]}"; do
    IFS='|' read -r schema key _ <<< "$entry"
    gsettings reset "$schema" "$key" \
        && ok "Reset $schema $key" \
        || err "Failed to reset $schema $key"
done
echo ""

# Optional Package Removal
_print_header "Optional: Package Removal" ""

info "Packages installed by setup.sh — remove manually if you no longer use them:"
for pkg in "${DEPENDENCIES[@]}"; do
    if [[ "$pkg" == "wireproxy" && -n "$remove_services" && ! "$remove_services" =~ ^[Yy]$ ]]; then
        info "  $pkg (still running wpm tunnel service(s) you chose to keep — removing it will break them)"
    else
        note "  $pkg"
    fi
done
for pkg in "${THEME_PACKAGES[@]}"; do
    note "  $pkg"
done
echo ""

# Done
ok "Reset complete! Open a new terminal session."
echo ""
echo -e "${COLOR_BLUE}-> Your dotfiles repository remains intact.${RST}"
