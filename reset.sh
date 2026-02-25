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
    echo -e "\n  ${NORD_RED}!!${RST}  ${NORD_SNOW_1}${1}${RST}"
    echo -e "  ${HEADER_LINE}"
}

_print_footer() {
    echo -e "  ${HEADER_LINE}\n"
}

ok()   { printf "  ${NORD_POLAR_4}│${RST}  ${NORD_GREEN}[OK]${RST}    %s\n" "$1"; }
info() { printf "  ${NORD_POLAR_4}│${RST}  ${NORD_BLUE}[INFO]${RST}  %s\n" "$1"; }
err()  { printf "  ${NORD_POLAR_4}│${RST}  ${NORD_RED}[ERR]${RST}   %s\n" "$1"; }
step() { _print_footer; _print_header "$1"; }

# --- Pre-flight checks ---

if [[ "$EUID" -eq 0 ]]; then
    echo -e "\n  ${NORD_RED}[ERR]  Do not run this script as root.${RST}\n"
    exit 1
fi

echo -e "\n  ${NORD_RED}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${RST}"
echo -e "  ${NORD_RED}┃${RST}           ${NORD_SNOW_1}Arch Dotfiles Reset${RST}           ${NORD_RED}┃${RST}"
echo -e "  ${NORD_RED}┃${RST}      ${NORD_ORANGE}This will UNDO everything setup!${RST}      ${NORD_RED}┃${RST}"
echo -e "  ${NORD_RED}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RST}"

_print_header "Pre-flight"
printf "  ${NORD_POLAR_4}│${RST}  ${NORD_ORANGE}[WARN]${RST}  Are you sure you want to reset? [y/N]: "
read -r confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { info "Aborted."; _print_footer; exit 0; }

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

# .config symlinks
if [[ -d "$DOTDIR/.config" ]]; then
    for item in "$DOTDIR/.config/"*; do
        target="$HOME/.config/$(basename "$item")"
        if [[ -L "$target" ]]; then
            rm "$target"
            ok "Removed symlink: ~/.config/$(basename "$item")"
        else
            info "Not a symlink, skipping: ~/.config/$(basename "$item")"
        fi
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
# 5. BACKUP WIREPROXY CONFIGS
# ==============================================================================
step "Backing up wireproxy configs"

BACKUP_DIR="$HOME/Desktop/wireproxy-backup-$(date +%Y%m%d_%H%M%S)"

if [[ -d "/etc/wireproxy" ]] && [[ -n "$(ls /etc/wireproxy/*.conf 2>/dev/null)" ]]; then
    mkdir -p "$BACKUP_DIR"
    sudo cp /etc/wireproxy/*.conf "$BACKUP_DIR/"
    sudo chown "$USER:$USER" "$BACKUP_DIR/"*.conf
    ok "Configs backed up to $BACKUP_DIR"
else
    info "No wireproxy configs found, skipping backup."
fi

# ==============================================================================
# 6. REMOVE WG-SOCKS
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
    info "Found wg-socks tunnels, removing..."
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
    info "No wg-socks tunnels found, skipping."
fi

# ==============================================================================
# 7. OPTIONALLY REMOVE PACKAGES
# ==============================================================================
step "Optional: Package Removal"

printf "  ${NORD_POLAR_4}│${RST}  ${NORD_D_BLUE}Targets: wireproxy bat plocate gvim starship fzf zoxide mpv...${RST}\n"
printf "  ${NORD_POLAR_4}│${RST}\n"
printf "  ${NORD_POLAR_4}│${RST}  ${NORD_SNOW_1}Remove these packages? [y/N]: ${RST}"
read -r remove_pkgs

if [[ "$remove_pkgs" =~ ^[Yy]$ ]]; then
    info "Uninstalling packages..."
    yay -Rns --noconfirm \
        wireproxy bat plocate gvim starship fzf zoxide mpv \
        wl-clipboard xclip reflector pacman-contrib 2>/dev/null
    ok "Packages removed."
else
    info "Skipping package removal."
fi

# ==============================================================================
# DONE
# ==============================================================================
_print_footer
echo -e "  ${NORD_GREEN}Reset complete!${RST}"
echo -e "  ${NORD_D_BLUE}>> Your dotfiles repository remains intact.${RST}"
echo -e "  ${NORD_D_BLUE}>> Open a new terminal session to finish.${RST}\n"