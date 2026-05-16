#!/bin/bash

# ==============================================================================
# ARCH DOTFILES RESET (Nord Aesthetic)
# ==============================================================================

# Nord Colors
NORD_POLAR_4='\e[38;2;76;86;106m'
NORD_SNOW_1='\e[38;2;216;222;233m'
NORD_CYAN='\e[38;2;143;188;187m'
NORD_BLUE='\e[38;2;136;192;208m'
NORD_D_BLUE='\e[38;2;129;161;193m'
NORD_GREEN='\e[38;2;163;190;140m'
NORD_RED='\e[38;2;191;97;106m'
NORD_ORANGE='\e[38;2;208;135;112m'
RST='\e[0m'

DOTDIR="$HOME/arch-config"

# --- UI Helpers ---

_print_header() {
    echo -e "\n${NORD_RED}${1}  ${NORD_SNOW_1}${2}${RST}"
    echo -e "${NORD_POLAR_4}─────────────────────────────────────────────────────${RST}"
}

_print_status() {
    local color=$NORD_BLUE
    [[ "$1" == "󰄬" ]] && color=$NORD_GREEN
    [[ "$1" == "󰅙" ]] && color=$NORD_RED
    [[ "$1" == "󰀦" ]] && color=$NORD_ORANGE
    echo -e "${color}${1}  ${2}${RST}"
}

ok()   { _print_status "󰄬" "$1"; }
err()  { _print_status "󰅙" "$1"; }
info() { _print_status "󰋼" "$1"; }

# --- Pre-flight ---

if [[ "$EUID" -eq 0 ]]; then
    echo -e "\n${NORD_RED}󰅙  Do not run this script as root.${RST}\n"
    exit 1
fi

echo -e "\n${NORD_RED}󰀦  Arch Dotfiles Reset${RST}"
echo -e "${NORD_ORANGE}This will UNDO everything setup.sh configured.${RST}\n"

_print_header "󰒓" "Pre-flight"
read -p "$(echo -e "${NORD_ORANGE}Are you sure you want to reset? [y/N]: ${RST}")" confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { info "Aborted."; echo ""; exit 0; }
echo ""

# ==============================================================================
# 1. REMOVE SYMLINKS
# ==============================================================================
_print_header "󰆑" "Removing Symlinks"

for file in .bashrc; do
    if [[ -L "$HOME/$file" ]]; then
        rm "$HOME/$file"
        ok "Removed symlink: ~/$file"
    else
        info "Not a symlink, skipping: ~/$file"
    fi
done

if [[ -d "$DOTDIR/.config" ]]; then
    for file in "$DOTDIR/.config/"*; do
        [[ -f "$file" ]] || continue
        target="$HOME/.config/$(basename "$file")"
        if [[ -L "$target" ]]; then
            rm "$target"
            ok "Removed symlink: ~/.config/$(basename "$file")"
        else
            info "Not a symlink, skipping: ~/.config/$(basename "$file")"
        fi
    done
fi

if [[ -d "$DOTDIR/.config" ]]; then
    for item in "$DOTDIR/.config/"*/; do
        dir=$(basename "$item")
        for file in "$item"*; do
            [[ -f "$file" ]] || continue
            target="$HOME/.config/$dir/$(basename "$file")"
            if [[ -L "$target" ]]; then
                rm "$target"
                ok "Removed symlink: ~/.config/$dir/$(basename "$file")"
            else
                info "Not a symlink, skipping: ~/.config/$dir/$(basename "$file")"
            fi
        done
    done
else
    info "No .config directory found in repo, skipping."
fi
echo ""

# ==============================================================================
# 2. REMOVE BAT CONFIG
# ==============================================================================
_print_header "󰅌" "Bat Config"

if [[ -f "$HOME/.config/bat/config" ]]; then
    rm "$HOME/.config/bat/config"
    ok "Removed bat config."
else
    info "bat config not found, skipping."
fi
echo ""

# ==============================================================================
# 3. REMOVE NEOVIM SYMLINK
# ==============================================================================
_print_header "󰕮" "Neovim Configuration"

NVIM_INIT="$HOME/.config/nvim/init.lua"
if [[ -L "$NVIM_INIT" ]]; then
    rm "$NVIM_INIT"
    ok "Removed symlink: ~/.config/nvim/init.lua"
else
    info "Not a symlink, skipping: ~/.config/nvim/init.lua"
fi
echo ""



# ==============================================================================
# 4. REMOVE SUDOERS RULE
# ==============================================================================
_print_header "󰒓" "Passwordless updatedb"

SUDOERS_FILE="/etc/sudoers.d/updatedb-nopasswd"
if [[ -f "$SUDOERS_FILE" ]]; then
    sudo rm -f "$SUDOERS_FILE"
    ok "Removed sudoers rule."
else
    info "Sudoers rule not found, skipping."
fi
echo ""

# ==============================================================================
# 5. REMOVE PACMAN CANDY
# ==============================================================================
_print_header "󰮯" "Pacman Config"

if grep -q "ILoveCandy" /etc/pacman.conf; then
    sudo sed -i '/^ILoveCandy/d' /etc/pacman.conf
    ok "ILoveCandy removed from pacman.conf"
else
    info "ILoveCandy not found, skipping."
fi
echo ""

# ==============================================================================
# 6. STOP AND REMOVE WARP
# ==============================================================================
_print_header "󰖂" "WARP Tunnel"

if sudo wg show warp &>/dev/null; then
    sudo wg-quick down "$HOME/.config/warp/warp.conf"
    _print_status "$([ $? -eq 0 ] && echo 󰄬 || echo 󰅙)" "Warp tunnel stopped"
else
    info "Warp tunnel not running, skipping."
fi

if [[ -f "$HOME/.config/warp/warp.conf" ]]; then
    mkdir -p "$HOME/Desktop"
    cp "$HOME/.config/warp/warp.conf" "$HOME/Desktop/warp-backup-$(date +%Y%m%d_%H%M%S).conf"
    ok "Warp config backed up to Desktop."
    rm -rf "$HOME/.config/warp"
    ok "Removed ~/.config/warp"
fi

if [[ -L "/usr/local/bin/warp" ]]; then
    sudo rm -f "/usr/local/bin/warp"
    ok "Removed warp from /usr/local/bin."
else
    info "warp symlink not found, skipping."
fi
echo ""

# ==============================================================================
# 7. REMOVE WG-SOCKS
# ==============================================================================
_print_header "󰒄" "wg-socks"

if [[ -L "/usr/local/bin/wg-socks" ]]; then
    sudo rm -f "/usr/local/bin/wg-socks"
    ok "Removed wg-socks from /usr/local/bin."
else
    info "wg-socks symlink not found, skipping."
fi

shopt -s nullglob
services=(/etc/systemd/system/*-wgsocks.service)
if [[ ${#services[@]} -gt 0 ]]; then
    read -p "$(echo -e "${NORD_ORANGE}Found ${#services[@]} wg-socks tunnel(s). Stop and remove them? [y/N]: ${RST}")" remove_services
    if [[ "$remove_services" =~ ^[Yy]$ ]]; then
        echo ""
        BACKUP_DIR="$HOME/Desktop/wireproxy-backup-$(date +%Y%m%d_%H%M%S)"
        if [[ -d "/etc/wireproxy" ]]; then
            CONFS=$(sudo find /etc/wireproxy -maxdepth 1 -name "*.conf" 2>/dev/null)
            if [[ -n "$CONFS" ]]; then
                mkdir -p "$BACKUP_DIR"
                sudo cp /etc/wireproxy/*.conf "$BACKUP_DIR/"
                sudo chmod 644 "$BACKUP_DIR/"*.conf
                sudo chown "$USER:$USER" "$BACKUP_DIR/"*.conf
                ok "Configs backed up to $BACKUP_DIR"
            fi
        fi
        for service in "${services[@]}"; do
            NAME=$(basename "$service" .service)
            sudo systemctl stop "$NAME"
            sudo systemctl disable "$NAME" &>/dev/null
            sudo rm -f "$service"
            ok "Removed tunnel: $NAME"
        done
        sudo rm -rf /etc/wireproxy
        sudo systemctl daemon-reload
        ok "All tunnels removed."
    else
        info "Skipping tunnel removal."
    fi
else
    info "No wg-socks tunnels found, skipping."
fi
echo ""

# ==============================================================================
# 8. REMOVE BRAVE POLICIES
# ==============================================================================
_print_header "󰈹" "Brave Policies"

BRAVE_POLICY_FILE="/etc/brave/policies/managed/arch-config.json"
if [[ -f "$BRAVE_POLICY_FILE" ]]; then
    sudo rm -f "$BRAVE_POLICY_FILE"
    ok "Brave policies removed."
else
    info "Brave policies not found, skipping."
fi
echo ""

# ==============================================================================
# 9. REMOVE CHAOTIC-AUR
# ==============================================================================
_print_header "󰒓" "Chaotic-AUR"

if grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
    sudo sed -i '/\[chaotic-aur\]/,/Include.*chaotic-mirrorlist/d' /etc/pacman.conf
    sudo pacman -Rns --noconfirm chaotic-keyring chaotic-mirrorlist
    sudo pacman -Syy
    ok "Chaotic-AUR removed."
else
    info "Chaotic-AUR not configured, skipping."
fi
echo ""

# ==============================================================================
# 10. REMOVE WALLPAPERS
# ==============================================================================
_print_header "󰹧" "Wallpapers"

WALLPAPERS_DIR="$HOME/Pictures/config-wallpapers"
if [[ -d "$WALLPAPERS_DIR" ]]; then
    read -p "$(echo -e "${NORD_ORANGE}Remove wallpapers directory? [y/N]: ${RST}")" remove_wallpapers
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

# ==============================================================================
# 11. REMOVE THEMES
# ==============================================================================
_print_header "󰔎" "Themes"

read -p "$(echo -e "${NORD_ORANGE}Remove theme packages? [y/N]: ${RST}")" remove_themes
if [[ "$remove_themes" =~ ^[Yy]$ ]]; then
    if yay -Rns --noconfirm \
        xcursor-simp1e-nord-light \
        nordic-bluish-accent-standard-buttons-theme \
        ttf-martian-mono-nerd 2>/dev/null; then
        ok "Themes removed."
    else
        err "Could not remove some theme packages."
    fi
    info "papirus-icon-theme kept (required by cinnamon)."
else
    info "Skipping theme removal."
fi
echo ""

# ==============================================================================
# 12. OPTIONAL: PACKAGE REMOVAL
# ==============================================================================
_print_header "󰏖" "Optional: Package Removal"

info "Targets: wireproxy wgcf wireguard-tools plocate neovim starship"
info "         fzf zoxide mpv xclip reflector pacman-contrib expac"
read -p "$(echo -e "${NORD_ORANGE}Remove these packages? [y/N]: ${RST}")" remove_pkgs

if [[ "$remove_pkgs" =~ ^[Yy]$ ]]; then
    yay -Rns --noconfirm \
        wireproxy wgcf wireguard-tools plocate neovim starship \
        fzf zoxide mpv xclip reflector pacman-contrib expac
    _print_status "$([ $? -eq 0 ] && echo 󰄬 || echo 󰅙)" "Packages removed"
else
    info "Skipping package removal."
fi
echo ""

# ==============================================================================
# 13. REMOVE TIMER
# ==============================================================================
_print_header "󰔛" "Timer Script"

if [[ -L "/usr/local/bin/timer" ]]; then
    sudo rm -f "/usr/local/bin/timer"
    ok "Removed timer from /usr/local/bin."
else
    info "timer symlink not found, skipping."
fi
echo ""

# ==============================================================================
# DONE
# ==============================================================================
_print_status "󰄬" "Reset complete! Please open a new terminal session."
echo ""
echo -e "${NORD_D_BLUE}󰁔  Your dotfiles repository remains intact.${RST}"
echo ""