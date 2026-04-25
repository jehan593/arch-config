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

HEADER_LINE="${NORD_POLAR_4}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"

DOTDIR="$HOME/arch-config"

# --- UI Helpers ---
_print_header() {
    echo -e "\n${NORD_RED}!!${RST}  ${NORD_SNOW_1}${1}${RST}"
    echo -e "${HEADER_LINE}"
}

_print_footer() {
    echo -e "${HEADER_LINE}\n"
}

_pass_thru() {
    while IFS= read -r line; do
        printf '\e[38;2;118;138;161m│  %s\e[0m\n' "$line"
    done
}

ok()   { printf "${NORD_POLAR_4}│${RST}  ${NORD_GREEN}[OK]${RST}    %s\n" "$1"; }
info() { printf "${NORD_POLAR_4}│${RST}  ${NORD_BLUE}[INFO]${RST}  %s\n" "$1"; }
err()  { printf "${NORD_POLAR_4}│${RST}  ${NORD_RED}[ERR]${RST}   %s\n" "$1"; }
step() { _print_footer; _print_header "$1"; }

# --- Pre-flight checks ---

if [[ "$EUID" -eq 0 ]]; then
    echo -e "\n${NORD_RED}[ERR]  Do not run this script as root.${RST}\n"
    exit 1
fi

echo -e "\n${NORD_RED}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${RST}"
echo -e "${NORD_RED}┃${RST}           ${NORD_SNOW_1}Arch Dotfiles Reset${RST}              ${NORD_RED}┃${RST}"
echo -e "${NORD_RED}┃${RST}      ${NORD_ORANGE}This will UNDO everything setup!${RST}      ${NORD_RED}┃${RST}"
echo -e "${NORD_RED}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RST}"

_print_header "Pre-flight"
printf "${NORD_POLAR_4}│${RST}  ${NORD_ORANGE}[WARN]${RST}  Are you sure you want to reset? [y/N]: "
read -r confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { info "Aborted."; _print_footer; exit 0; }
_print_footer

# ==============================================================================
# 1. REMOVE SYMLINKS
# ==============================================================================
step "Removing symlinks"

# Root dotfiles
for file in .bashrc .vimrc; do
    if [[ -L "$HOME/$file" ]]; then
        rm "$HOME/$file"
        ok "Removed symlink: ~/$file"
    else
        info "Not a symlink, skipping: ~/$file"
    fi
done

# Direct .config files (e.g. starship.toml)
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

# .config subdirectory files
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

# ==============================================================================
# 2. REMOVE BAT CONFIG
# ==============================================================================
step "Removing bat config"

if [[ -f "$HOME/.config/bat/config" ]]; then
    rm "$HOME/.config/bat/config"
    ok "Removed bat config."
else
    info "bat config not found, skipping."
fi

# ==============================================================================
# 3. REMOVE NORD VIM THEME
# ==============================================================================
step "Removing Nord vim theme"

if [[ -f "$HOME/.vim/colors/nord.vim" ]]; then
    rm "$HOME/.vim/colors/nord.vim"
    ok "Removed Nord vim theme."
else
    info "Nord vim theme not found, skipping."
fi

# ==============================================================================
# 4. REMOVE SUDOERS RULE
# ==============================================================================
step "Removing passwordless updatedb rule"

SUDOERS_FILE="/etc/sudoers.d/updatedb-nopasswd"
if [[ -f "$SUDOERS_FILE" ]]; then
    sudo rm -f "$SUDOERS_FILE"
    ok "Removed sudoers rule."
else
    info "Sudoers rule not found, skipping."
fi

# ==============================================================================
# 5. REMOVE PACMAN CANDY
# ==============================================================================
step "Restoring pacman config"

if grep -q "ILoveCandy" /etc/pacman.conf; then
    sudo sed -i '/^ILoveCandy/d' /etc/pacman.conf
    ok "ILoveCandy removed from pacman.conf"
else
    info "ILoveCandy not found, skipping."
fi

# ==============================================================================
# 6. STOP AND REMOVE WARP
# ==============================================================================
step "Stopping warp tunnel"

if sudo wg show warp &>/dev/null; then
    sudo wg-quick down "$HOME/.config/warp/warp.conf" 2>&1 | _pass_thru
    ok "Warp tunnel stopped."
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

# ==============================================================================
# 7. REMOVE WG-SOCKS
# ==============================================================================
step "Removing wg-socks"

if [[ -L "/usr/local/bin/wg-socks" ]]; then
    sudo rm -f "/usr/local/bin/wg-socks"
    ok "Removed wg-socks from /usr/local/bin."
else
    info "wg-socks symlink not found, skipping."
fi

shopt -s nullglob
services=(/etc/systemd/system/*-wgsocks.service)
if [[ ${#services[@]} -gt 0 ]]; then
    printf "${NORD_POLAR_4}│${RST}  ${NORD_ORANGE}[WARN]${RST}  Found ${#services[@]} wg-socks tunnel(s). Stop and remove them? [y/N]: "
    read -r remove_services
    if [[ "$remove_services" =~ ^[Yy]$ ]]; then

        # Backup first
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

        # Remove services
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

# ==============================================================================
# 8. REMOVE BRAVE POLICIES
# ==============================================================================
step "Removing Brave policies"

BRAVE_POLICY_FILE="/etc/brave/policies/managed/arch-config.json"
if [[ -f "$BRAVE_POLICY_FILE" ]]; then
    sudo rm -f "$BRAVE_POLICY_FILE"
    ok "Brave policies removed."
else
    info "Brave policies not found, skipping."
fi

# ==============================================================================
# 9. REMOVE CHAOTIC-AUR
# ==============================================================================
step "Removing Chaotic-AUR"

if grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
    sudo sed -i '/\[chaotic-aur\]/,/Include.*chaotic-mirrorlist/d' /etc/pacman.conf
    sudo pacman -Rns --noconfirm chaotic-keyring chaotic-mirrorlist 2>&1 | _pass_thru
    sudo pacman -Syy
    ok "Chaotic-AUR removed."
else
    info "Chaotic-AUR not configured, skipping."
fi

# ==============================================================================
# 10. REMOVE WALLPAPERS
# ==============================================================================
step "Removing wallpapers"

WALLPAPERS_DIR="$HOME/Pictures/config-wallpapers"
if [[ -d "$WALLPAPERS_DIR" ]]; then
    printf "${NORD_POLAR_4}│${RST}  ${NORD_ORANGE}[WARN]${RST}  Remove wallpapers directory? [y/N]: "
    read -r remove_wallpapers
    if [[ "$remove_wallpapers" =~ ^[Yy]$ ]]; then
        rm -rf "$WALLPAPERS_DIR"
        ok "Wallpapers removed."
    else
        info "Skipping wallpapers removal."
    fi
else
    info "Wallpapers directory not found, skipping."
fi

# ==============================================================================
# 11. REMOVE THEMES
# ==============================================================================
step "Removing themes"

printf "${NORD_POLAR_4}│${RST}  ${NORD_SNOW_1}Remove theme packages? [y/N]: ${RST}"
read -r remove_themes
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

# ==============================================================================
# 12. OPTIONALLY REMOVE PACKAGES
# ==============================================================================
step "Optional: Package Removal"

printf "${NORD_POLAR_4}│${RST}  ${NORD_D_BLUE}Targets: wireproxy wgcf wireguard-tools bat plocate gvim starship${RST}\n"
printf "${NORD_POLAR_4}│${RST}  ${NORD_D_BLUE}         fzf zoxide mpv wl-clipboard xclip reflector pacman-contrib expac${RST}\n"
printf "${NORD_POLAR_4}│${RST}\n"
printf "${NORD_POLAR_4}│${RST}  ${NORD_SNOW_1}Remove these packages? [y/N]: ${RST}"
read -r remove_pkgs

if [[ "$remove_pkgs" =~ ^[Yy]$ ]]; then
    info "Uninstalling packages..."
    yay -Rns --noconfirm \
        wireproxy wgcf wireguard-tools bat plocate gvim starship \
        fzf zoxide mpv wl-clipboard xclip reflector pacman-contrib expac 2>&1 | _pass_thru
    ok "Packages removed."
else
    info "Skipping package removal."
fi

# ==============================================================================
# DONE
# ==============================================================================
_print_footer
echo -e "${NORD_GREEN}Reset complete!${RST}"
echo -e "${NORD_D_BLUE}>> Your dotfiles repository remains intact.${RST}"
echo -e "${NORD_D_BLUE}>> Open a new terminal session to finish.${RST}\n"
