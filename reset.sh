#!/bin/bash
# Arch Dotfiles Reset

source "$HOME/arch-config/scripts/setup-helpers.sh"

DOTDIR="$HOME/arch-config"

if [[ "$EUID" -eq 0 ]]; then
    echo -e "\n\e[31m[!] Do not run this script as root.\e[0m\n"
    exit 1
fi

echo -e "\n${COLOR_RED}[!] Arch Dotfiles Reset${RST}"
echo -e "${COLOR_YELLOW}This will UNDO everything setup.sh configured.${RST}\n"

_print_header "󰒓" "Pre-flight"
read -p "$(echo -e "${COLOR_YELLOW}Are you sure you want to reset? [y/N]: ${RST}")" confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { info "Aborted."; echo ""; exit 0; }
echo ""

# Remove Symlinks
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

# Remove Neovim Symlink
_print_header "󰕮" "Neovim Configuration"

NVIM_INIT="$HOME/.config/nvim/init.lua"
if [[ -L "$NVIM_INIT" ]]; then
    rm "$NVIM_INIT"
    ok "Removed symlink: ~/.config/nvim/init.lua"
else
    info "Not a symlink, skipping: ~/.config/nvim/init.lua"
fi
echo ""

# Remove Sudoers Rule
_print_header "󰒓" "Passwordless updatedb"

SUDOERS_FILE="/etc/sudoers.d/updatedb-nopasswd"
if [[ -f "$SUDOERS_FILE" ]]; then
    sudo rm -f "$SUDOERS_FILE"
    ok "Removed sudoers rule."
else
    info "Sudoers rule not found, skipping."
fi
echo ""

# Remove Pacman Candy
_print_header "󰮯" "Pacman Config"

if grep -q "ILoveCandy" /etc/pacman.conf; then
    sudo sed -i '/^ILoveCandy/d' /etc/pacman.conf
    ok "ILoveCandy removed from pacman.conf"
else
    info "ILoveCandy not found, skipping."
fi
echo ""

# Stop and Remove VPN
_print_header "󰖂" "VPN / WARP"

VPN_ROOT="$HOME/.config/vpn"
STATUS_FILE="$VPN_ROOT/active_tunnel"
CONFIGS_DIR="$VPN_ROOT/configs"
WARP_DIR="$HOME/.config/warp"
WG_DIR="/etc/wireguard"
VPN_BACKUP="$HOME/Documents/vpn-configs-backup/reset-$(date +%Y%m%d_%H%M%S)"

active=""
if sudo test -f "$STATUS_FILE"; then
    active=$(sudo sed 's/^[^[:space:]]*[[:space:]]*//' "$STATUS_FILE")
fi
if [[ -z "$active" ]]; then
    active=$(sudo wg show interfaces 2>/dev/null | awk '{print $1; exit}')
fi

if [[ -n "$active" ]]; then
    sudo systemctl disable --now "wg-quick@$active" &>/dev/null
    [ $? -eq 0 ] && ok "Stopped tunnel: $active" || err "Failed to stop tunnel: $active"
    sudo rm -f "$WG_DIR/$active.conf"
    sudo test -f "$STATUS_FILE" && sudo truncate -s 0 "$STATUS_FILE"
else
    info "No active tunnel found, skipping."
fi

if sudo test -d "$CONFIGS_DIR"; then
    shopt -s nullglob
    confs=("$CONFIGS_DIR"/*.conf)
    shopt -u nullglob
    if [[ ${#confs[@]} -gt 0 ]]; then
        sudo mkdir -p "$VPN_BACKUP"
        for conf in "${confs[@]}"; do
            sudo cp "$conf" "$VPN_BACKUP/"
            ok "Backed up: $(basename "$conf")"
        done
        sudo chown -R "$USER:$USER" "$VPN_BACKUP"
        ok "User configs backed up to $VPN_BACKUP"
    fi
fi

if sudo test -f "$WARP_DIR/warp.conf"; then
    sudo mkdir -p "$VPN_BACKUP"
    sudo cp "$WARP_DIR/warp.conf" "$VPN_BACKUP/warp.conf"
    sudo chown -R "$USER:$USER" "$VPN_BACKUP"
    ok "Warp config backed up to $VPN_BACKUP"
fi

sudo test -d "$WARP_DIR" && sudo rm -rf "$WARP_DIR" && ok "Removed ~/.config/warp"
sudo test -d "$VPN_ROOT" && sudo rm -rf "$VPN_ROOT" && ok "Removed ~/.config/vpn"

if [[ -L "/usr/local/bin/vpn" ]]; then
    sudo rm -f "/usr/local/bin/vpn"
    ok "Removed vpn from /usr/local/bin."
else
    info "vpn symlink not found, skipping."
fi
echo ""

# Remove wg-socks
_print_header "󰒄" "wg-socks"

if [[ -L "/usr/local/bin/wg-socks" ]]; then
    sudo rm -f "/usr/local/bin/wg-socks"
    ok "Removed wg-socks from /usr/local/bin."
else
    info "wg-socks symlink not found, skipping."
fi

shopt -s nullglob
services=(/etc/systemd/system/*-wgsocks.service)
shopt -u nullglob
if [[ ${#services[@]} -gt 0 ]]; then
    read -p "$(echo -e "${COLOR_YELLOW}Found ${#services[@]} wg-socks tunnel(s). Stop and remove them? [y/N]: ${RST}")" remove_services
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

# Remove Brave Policies
_print_header "󰈹" "Brave Policies"

BRAVE_POLICY_FILE="/etc/brave/policies/managed/arch-config.json"
if [[ -f "$BRAVE_POLICY_FILE" ]]; then
    sudo rm -f "$BRAVE_POLICY_FILE"
    ok "Brave policies removed."
else
    info "Brave policies not found, skipping."
fi
echo ""

# Remove Firefox Policies
_print_header "󰈹" "Firefox Policies"

FIREFOX_POLICY_FILE="/etc/firefox/policies/policies.json"
if [[ -f "$FIREFOX_POLICY_FILE" ]]; then
    sudo rm -f "$FIREFOX_POLICY_FILE"
    ok "Firefox policies removed."
else
    info "Firefox policies not found, skipping."
fi
echo ""

# Remove Chaotic-AUR
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

# Remove Wallpapers
_print_header "󰹧" "Wallpapers"

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

# Remove Themes
_print_header "󰔎" "Themes"

read -p "$(echo -e "${COLOR_YELLOW}Remove theme packages? [y/N]: ${RST}")" remove_themes
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

# Optional Package Removal
_print_header "󰏖" "Optional: Package Removal"

info "Targets: wireproxy wgcf wireguard-tools plocate neovim starship"
info "         fzf zoxide mpv xclip reflector pacman-contrib expac qview tldr topgrade"
read -p "$(echo -e "${COLOR_YELLOW}Remove these packages? [y/N]: ${RST}")" remove_pkgs

if [[ "$remove_pkgs" =~ ^[Yy]$ ]]; then
    yay -Rns --noconfirm \
        wireproxy wgcf wireguard-tools plocate neovim starship \
        fzf zoxide mpv xclip reflector pacman-contrib expac qview tldr topgrade
    [ $? -eq 0 ] && ok "Packages removed" || err "Failed to remove some packages"
else
    info "Skipping package removal."
fi
echo ""

# Remove Timer Script
_print_header "󰔛" "Timer Script"

if [[ -L "/usr/local/bin/timer" ]]; then
    sudo rm -f "/usr/local/bin/timer"
    ok "Removed timer from /usr/local/bin."
else
    info "timer symlink not found, skipping."
fi
echo ""

# Done
ok "Reset complete! Open a new terminal session."
echo ""
echo -e " ${COLOR_BLUE}->  Your dotfiles repository remains intact.${RST}"
echo ""