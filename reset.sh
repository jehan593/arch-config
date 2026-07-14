#!/bin/bash

# ==============================================================================
# ARCH DOTFILES RESET
# ==============================================================================

DOTDIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"

source "$DOTDIR/helpers/colors-standard.sh"
source "$DOTDIR/helpers/printer.sh"
source "$DOTDIR/helpers/pkg-list.sh"
source "$DOTDIR/helpers/theme-settings.sh"
source "$DOTDIR/helpers/link-helpers.sh"

if [[ "$EUID" -eq 0 ]]; then
    printfc "$RED" "Do not run this script as root."
    exit 1
fi

# ==============================================================================
# START
# ==============================================================================

printfc "$CYAN" "\n┌───────────────────────┐"
printfc "$CYAN" "│  Arch Dotfiles Reset  │"
printfc "$CYAN" "└───────────────────────┘"
printfc "$YELLOW" "This will UNDO everything setup.sh configured."
printfc -n "$YELLOW" "Are you sure you want to reset? [y/N]: "
read -r confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo -e "\nAborted.\n"; exit 0; }
echo ""

sudo -v || { printfc "$RED" "Sudo authentication failed."; exit 1; }
printfc "$GREEN" "Sudo authenticated."
echo ""

# ==============================================================================
# 1. ENVIRONMENT VARIABLE
# ==============================================================================

printfc "$BLUE" "\n>Environment Variable"

if [[ -f "/etc/profile.d/arch-config.sh" ]]; then
    sudo rm -f /etc/profile.d/arch-config.sh
    printfc "$GREEN" "Removed ARCH_CONFIG_PATH (/etc/profile.d/arch-config.sh)"
else
    printfc "$YELLOW" "ARCH_CONFIG_PATH file not found, skipping."
fi
echo ""

# ==============================================================================
# 2. HOME FILES
# ==============================================================================

printfc "$BLUE" "\n>Removing Home Files\n"

_home_file_action() {
    local src="$1" target="$2"
    if [[ -L "$target" ]]; then
        rm "$target"
        printfc "$GREEN" "Removed symlink: %s" "${target/#$HOME/\~}"

        local backups=("$target".bak.*)
        if [[ -e "${backups[0]}" ]]; then
            local latest="${backups[-1]}"
            mv "$latest" "$target"
            printfc "$GREEN" "Restored backup: %s" "${target/#$HOME/\~}"
            if [[ ${#backups[@]} -gt 1 ]]; then
                printfc "$YELLOW" "%s older backup(s) of %s remain, not auto-restored" "$(( ${#backups[@]} - 1 ))" "${target/#$HOME/\~}"
            fi
        fi
    else
        printfc "$YELLOW" "Not a symlink, skipping: %s" "${target/#$HOME/\~}"
    fi
}
_each_home_file
echo ""

# ==============================================================================
# 3. TOOLS
# ==============================================================================

printfc "$BLUE" "\n>Removing Tools\n"

_tool_file_action() {
    local name="$1" src="$2"
    if [[ -L "/usr/local/bin/$name" ]]; then
        sudo rm -f "/usr/local/bin/$name"
        printfc "$GREEN" "Removed %s from /usr/local/bin." "$name"
    else
        printfc "$YELLOW" "%s symlink not found, skipping." "$name"
    fi
}
_each_tool_file
echo ""

# ==============================================================================
# 4. ETC FILES
# ==============================================================================

printfc "$BLUE" "\n>Removing Etc Files\n"

_etc_file_action() {
    local src="$1" dest="$2"
    if [[ -f "$dest" ]]; then
        sudo rm -f "$dest"
        printfc "$GREEN" "Removed policy: %s" "$dest"
    else
        printfc "$YELLOW" "Policy not found, skipping: %s" "$dest"
    fi
}
_each_etc_file
echo ""

# ==============================================================================
# 5. REMOVE SUDOERS RULE
# ==============================================================================

printfc "$BLUE" "\n>Passwordless updatedb"

SUDOERS_FILE="/etc/sudoers.d/updatedb-nopasswd"
if [[ -f "$SUDOERS_FILE" ]]; then
    sudo rm -f "$SUDOERS_FILE"
    printfc "$GREEN" "Removed sudoers rule."
else
    printfc "$YELLOW" "Sudoers rule not found, skipping."
fi
echo ""

# ==============================================================================
# 6. REMOVE PACMAN CANDY
# ==============================================================================

printfc "$BLUE" "\n>Pacman Config"

if grep -q "ILoveCandy" /etc/pacman.conf; then
    sudo sed -i '/^ILoveCandy/d' /etc/pacman.conf
    printfc "$GREEN" "ILoveCandy removed from pacman.conf"
else
    printfc "$YELLOW" "ILoveCandy not found, skipping."
fi
echo ""

# ==============================================================================
# 7. STOP AND REMOVE wgm
# ==============================================================================

printfc "$BLUE" "\n>wgm / WARP"

source "$DOTDIR/helpers/wgm-helper.sh"
_wgm_set_paths "$HOME"
WGM_BACKUP="$BACKUP_ROOT"

active=$(_get_active_tunnel)

if [[ -n "$active" ]]; then
    sudo systemctl disable --now "wg-quick@$active"
    if [ $? -eq 0 ]; then
        printfc "$GREEN" "Stopped tunnel: %s" "$active"
    else
        printfc "$RED" "Failed to stop tunnel: %s" "$active"
    fi
    sudo rm -f "$WG_DIR/$active.conf"
else
    printfc "$YELLOW" "No active tunnel found, skipping."
fi

if sudo test -d "$CONFIGS_DIR"; then
    shopt -s nullglob
    confs=("$CONFIGS_DIR"/*.conf)
    shopt -u nullglob
    if [[ ${#confs[@]} -gt 0 ]]; then
        sudo mkdir -p "$WGM_BACKUP"
        for conf in "${confs[@]}"; do
            sudo cp "$conf" "$WGM_BACKUP/"
            printfc "$GREEN" "Backed up: %s" "$(basename "$conf")"
        done
        sudo chown -R "$USER:$USER" "$WGM_BACKUP"
        printfc "$GREEN" "User configs backed up to %s" "$WGM_BACKUP"
    fi
fi

sudo test -d "$WGM_ROOT" && sudo rm -rf "$WGM_ROOT" && printfc "$GREEN" "Removed ~/.config/arch-config-files/wgm"
echo ""

# ==============================================================================
# 8. REMOVE wpm TUNNELS
# ==============================================================================

printfc "$BLUE" "\n>wpm"

shopt -s nullglob
services=(/etc/systemd/system/*-wpm.service)
shopt -u nullglob
wpm_kept=false
if [[ ${#services[@]} -gt 0 ]]; then
    printfc -n "$YELLOW" "Found ${#services[@]} wpm tunnel(s). Stop and remove them? [y/N]: "
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo ""
        source "$DOTDIR/helpers/wpm-helper.sh"
        _wpm_set_paths "$HOME"
        BACKUP_DIR="$BACKUP_ROOT"
        if [[ -d "$CONF_DIR" ]]; then
            CONFS=$(sudo find "$CONF_DIR" -maxdepth 1 -name "*.conf" 2>/dev/null)
            if [[ -n "$CONFS" ]]; then
                mkdir -p "$BACKUP_DIR"
                sudo cp "$CONF_DIR"/*.conf "$BACKUP_DIR/"
                sudo chmod 644 "$BACKUP_DIR/"*.conf
                sudo chown "$USER:$USER" "$BACKUP_DIR/"*.conf
                printfc "$GREEN" "Configs backed up to %s" "$BACKUP_DIR"
            fi
        fi
        for service in "${services[@]}"; do
            NAME=$(basename "$service" .service)
            sudo systemctl stop "$NAME"
            sudo systemctl disable "$NAME"
            sudo rm -f "$service"
            printfc "$GREEN" "Removed tunnel: %s" "$NAME"
        done
        sudo rm -rf "$CONF_DIR"
        sudo systemctl daemon-reload
        printfc "$GREEN" "All tunnels removed."
    else
        wpm_kept=true
        printfc "$YELLOW" "Skipping tunnel removal."
    fi
else
    printfc "$YELLOW" "No wpm tunnels found, skipping."
fi
echo ""

# ==============================================================================
# 9. REMOVE CHAOTIC-AUR
# ==============================================================================

printfc "$BLUE" "\n>Chaotic-AUR"

if grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
    sudo sed -i '/\[chaotic-aur\]/,/Include.*chaotic-mirrorlist/d' /etc/pacman.conf
    sudo pacman -Rns --noconfirm chaotic-keyring chaotic-mirrorlist
    sudo pacman -Syy
    printfc "$GREEN" "Chaotic-AUR removed."
else
    printfc "$YELLOW" "Chaotic-AUR not configured, skipping."
fi
echo ""

# ==============================================================================
# 10. REMOVE WALLPAPERS
# ==============================================================================

printfc "$BLUE" "\n>Wallpapers"

WALLPAPERS_DIR="$HOME/Pictures/config-wallpapers"
if [[ -d "$WALLPAPERS_DIR" ]]; then
    printfc -n "$YELLOW" "Remove wallpapers directory? [y/N]: "
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -rf "$WALLPAPERS_DIR"
        printfc "$GREEN" "Wallpapers removed."
    else
        printfc "$YELLOW" "Skipping wallpapers removal."
    fi
else
    printfc "$YELLOW" "Wallpapers directory not found, skipping."
fi
echo ""

# ==============================================================================
# 11. RESTORE THEME & FONT DEFAULTS
# ==============================================================================

printfc "$BLUE" "\n>Restoring Theme & Font Defaults"

for entry in "${THEME_SETTINGS[@]}"; do
    IFS='|' read -r schema key _ <<< "$entry"
    gsettings reset "$schema" "$key" \
        && printfc "$GREEN" "Reset %s %s" "$schema" "$key" \
        || printfc "$RED" "Failed to reset %s %s" "$schema" "$key"
done
echo ""

# ==============================================================================
# 12. OPTIONAL PACKAGE REMOVAL
# ==============================================================================

printfc "$BLUE" "\n>Optional: Package Removal"

printfc "$YELLOW" "Packages installed by setup.sh — remove manually if you no longer use them:"
for pkg in "${DEPENDENCIES[@]}"; do
    if [[ "$pkg" == "wireproxy" && "$wpm_kept" == true ]]; then
        printfc "$YELLOW" "  %s (still running wpm tunnel service(s) you chose to keep — removing it will break them)" "$pkg"
    else
        printfc "$YELLOW" "  %s" "$pkg"
    fi
done
for pkg in "${THEME_PACKAGES[@]}"; do
    printfc "$YELLOW" "  %s" "$pkg"
done
echo ""

# ==============================================================================
# DONE
# ==============================================================================

printfc "$GREEN" "Reset complete! Open a new terminal session."
printfc "$YELLOW" "Your dotfiles repository remains intact."
echo ""
