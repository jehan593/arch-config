#!/bin/bash

# ==============================================================================
# ARCH DOTFILES RESET
# ==============================================================================

# Nord RGB Colors
CYAN='\033[38;2;143;188;187m'
BLUE='\033[38;2;136;192;208m'
GREEN='\033[38;2;163;190;140m'
RED='\033[38;2;191;97;106m'
D_BLUE='\033[38;2;129;161;193m'
RST='\033[0m'

# --- Helpers ---
ok()   { echo -e "${GREEN}[OK]${RST}    $1"; }
info() { echo -e "${BLUE}[INFO]${RST}  $1"; }
err()  { echo -e "${RED}[ERR]${RST}   $1"; }
step() { echo -e "\n${CYAN}==> $1${RST}"; }

# --- Pre-flight checks ---

if [[ "$EUID" -eq 0 ]]; then
    err "Do not run this script as root."
    exit 1
fi

echo -e "${RED}"
echo "  ================================================"
echo "       Arch Dotfiles Reset"
echo "       This will UNDO everything setup.sh did."
echo "  ================================================"
echo -e "${RST}"

read -rp "$(echo -e ${RED}[WARN]${RST}   Are you sure you want to reset? [y/N]: )" confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { info "Aborted."; exit 0; }

# ==============================================================================
# 1. REMOVE SYMLINKS
# ==============================================================================
step "Removing symlinks..."

for target in \
    "$HOME/.bashrc" \
    "$HOME/.vimrc" \
    "$HOME/.config/mpv/input.conf" \
    "$HOME/.config/mpv/mpv.conf" \
    "$HOME/.config/starship.toml"; do
    if [[ -L "$target" ]]; then
        rm "$target"
        ok "Removed symlink: $target"
    else
        info "Not a symlink, skipping: $target"
    fi
done

# ==============================================================================
# 2. REMOVE BAT CONFIG
# ==============================================================================
step "Removing bat config..."

if [[ -f "$HOME/.config/bat/config" ]]; then
    rm "$HOME/.config/bat/config"
    ok "Removed bat config."
else
    info "bat config not found, skipping."
fi

# ==============================================================================
# 3. REMOVE NORD VIM THEME
# ==============================================================================
step "Removing Nord vim theme..."

if [[ -f "$HOME/.vim/colors/nord.vim" ]]; then
    rm "$HOME/.vim/colors/nord.vim"
    ok "Removed Nord vim theme."
else
    info "Nord vim theme not found, skipping."
fi

# ==============================================================================
# 4. REMOVE SUDOERS RULE
# ==============================================================================
step "Removing passwordless updatedb sudoers rule..."

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
step "Backing up wireproxy configs..."

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
step "Removing wg-socks..."

if [[ -L "/usr/local/bin/wg-socks" ]]; then
    sudo rm -f "/usr/local/bin/wg-socks"
    ok "Removed wg-socks from /usr/local/bin."
else
    info "wg-socks symlink not found, skipping."
fi

# Stop and remove any active wg-socks tunnels
shopt -s nullglob
services=(/etc/systemd/system/*-wgsocks.service)
if [[ ${#services[@]} -gt 0 ]]; then
    info "Found active wg-socks tunnels, removing..."
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
step "Remove installed packages?"
echo -e "${D_BLUE}  wireproxy bat plocate gvim starship fzf zoxide mpv wl-clipboard xclip reflector pacman-contrib${RST}\n"
read -rp "$(echo -e ${BLUE}[INFO]${RST}   Remove these packages? [y/N]: )" remove_pkgs

if [[ "$remove_pkgs" =~ ^[Yy]$ ]]; then
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
echo -e "\n${CYAN}  ================================================${RST}"
echo -e "${GREEN}  Reset complete!${RST}"
echo -e "${D_BLUE}  - Your dotfiles repo is untouched${RST}"
echo -e "${D_BLUE}  - Open a new terminal to apply changes${RST}"
echo -e "${CYAN}  ================================================${RST}\n"