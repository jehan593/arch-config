#!/bin/bash

# ==============================================================================
# ARCH DOTFILES SETUP (Nord Aesthetic)
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

# --- UI Helpers ---
_print_header() {
    echo -e "\n${NORD_CYAN}>>${RST}  ${NORD_SNOW_1}${1}${RST}"
    echo -e "${HEADER_LINE}"
}

_print_footer() {
    echo -e "${HEADER_LINE}\n"
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

DOTDIR="$HOME/arch-config"

echo -e "\n${NORD_CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${RST}"
echo -e "${NORD_CYAN}┃${RST}          ${NORD_SNOW_1}Arch Dotfiles Setup${RST}               ${NORD_CYAN}┃${RST}"
echo -e "${NORD_CYAN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RST}"

_print_header "Pre-flight Checks"

if [[ ! -d "$DOTDIR" ]]; then
    err "arch-config not found at $DOTDIR"
    err "Clone your repo first: git clone <url> ~/arch-config"
    _print_footer
    exit 1
fi
ok "arch-config found at $DOTDIR"

# ==============================================================================
# 1. AUR HELPER (yay)
# ==============================================================================
step "Checking AUR helper (yay)"

if ! command -v yay &>/dev/null; then
    info "Installing yay..."
    sudo pacman -S --needed --noconfirm base-devel git
    rm -rf /tmp/yay-install
    git clone https://aur.archlinux.org/yay.git /tmp/yay-install
    (cd /tmp/yay-install && makepkg -si --noconfirm)
    rm -rf /tmp/yay-install
    ok "yay installed."
else
    ok "yay already installed."
fi

# ==============================================================================
# 2. CHAOTIC-AUR
# ==============================================================================
step "Setting up Chaotic-AUR"

if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
    info "Adding Chaotic-AUR keyring and mirrorlist..."
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key 3056513887B78AEB
    sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
    sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf > /dev/null
    sudo pacman -Sy
    ok "Chaotic-AUR added."
else
    ok "Chaotic-AUR already configured."
fi

# ==============================================================================
# 3. CORE DEPENDENCIES
# ==============================================================================
step "Installing dependencies"

# Replace vim with gvim for clipboard support
if pacman -Qq vim &>/dev/null && ! pacman -Qq gvim &>/dev/null; then
    info "Replacing vim with gvim for clipboard support..."
    sudo pacman -Rdd --noconfirm vim
fi

DEPENDENCIES=(
    "wireproxy"
    "wgcf"
    "wireguard-tools"
    "bat"
    "plocate"
    "curl"
    "gvim"
    "starship"
    "fzf"
    "zoxide"
    "mpv"
    "wl-clipboard"
    "xclip"
    "reflector"
    "pacman-contrib"
    "git"
    "expac"
)

info "Updating package database..."
yay -S --needed --noconfirm "${DEPENDENCIES[@]}" \
    && ok "Dependencies installed." \
    || err "Some dependencies failed to install."

info "Initializing plocate database..."
sudo updatedb

# ==============================================================================
# 4. SYMLINKS
# ==============================================================================
step "Creating symlinks"

mkdir -p "$HOME/.config"

# Root dotfiles
ln -sf "$DOTDIR/.bashrc" "$HOME/.bashrc"
ok "Linked .bashrc -> ~/.bashrc"

ln -sf "$DOTDIR/.vimrc" "$HOME/.vimrc"
ok "Linked .vimrc -> ~/.vimrc"

# Direct .config files (e.g. starship.toml)
for file in "$DOTDIR/.config/"*; do
    [[ -f "$file" ]] || continue
    ln -sf "$file" "$HOME/.config/$(basename "$file")"
    ok "Linked .config/$(basename "$file")"
done

# .config subdirectory files - link files only, not folders
for item in "$DOTDIR/.config/"*/; do
    dir=$(basename "$item")
    mkdir -p "$HOME/.config/$dir"
    for file in "$item"*; do
        [[ -f "$file" ]] || continue
        ln -sf "$file" "$HOME/.config/$dir/$(basename "$file")"
        ok "Linked .config/$dir/$(basename "$file")"
    done
done

# Nord vim theme
mkdir -p "$HOME/.vim/colors"
if [[ ! -f "$HOME/.vim/colors/nord.vim" ]]; then
    info "Downloading Nord vim theme..."
    curl -fsSL -o "$HOME/.vim/colors/nord.vim" \
        https://raw.githubusercontent.com/nordtheme/vim/main/colors/nord.vim \
        && ok "Nord vim theme downloaded." \
        || err "Failed to download Nord vim theme."
else
    ok "Nord vim theme already exists."
fi

# bat Nord theme
info "Configuring bat theme..."
mkdir -p "$HOME/.config/bat"
echo '--theme="Nord"' > "$HOME/.config/bat/config"
ok "bat configured with Nord theme."

# ==============================================================================
# 5. PASSWORDLESS UPDATEDB
# ==============================================================================
step "Configuring passwordless updatedb"

SUDOERS_FILE="/etc/sudoers.d/updatedb-nopasswd"

if [[ ! -f "$SUDOERS_FILE" ]]; then
    SUDOERS_TMP="${SUDOERS_FILE}.tmp"
    echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/updatedb" | sudo tee "$SUDOERS_TMP" > /dev/null
    if sudo visudo -c -f "$SUDOERS_TMP" &>/dev/null; then
        sudo mv "$SUDOERS_TMP" "$SUDOERS_FILE"
        sudo chmod 440 "$SUDOERS_FILE"
        ok "Sudoers rule added for updatedb."
    else
        sudo rm -f "$SUDOERS_TMP"
        err "Sudoers validation failed. Skipping passwordless updatedb."
    fi
else
    ok "Sudoers rule already exists."
fi

# ==============================================================================
# 6. PACMAN CANDY
# ==============================================================================
step "Configuring pacman"

if ! grep -q "ILoveCandy" /etc/pacman.conf; then
    sudo sed -i 's/^#Color/Color/' /etc/pacman.conf
    sudo sed -i '/^Color/a ILoveCandy' /etc/pacman.conf
    ok "Color + ILoveCandy added to pacman.conf"
else
    ok "ILoveCandy already set."
fi

# ==============================================================================
# 7. WG-SOCKS SETUP
# ==============================================================================
step "Setting up wg-socks manager"

if [[ -f "$DOTDIR/scripts/wg-socks.sh" ]]; then
    chmod +x "$DOTDIR/scripts/wg-socks.sh"
    sudo ln -sf "$DOTDIR/scripts/wg-socks.sh" "/usr/local/bin/wg-socks"
    ok "wg-socks linked to /usr/local/bin/wg-socks"
else
    info "wg-socks script not found in $DOTDIR/scripts/"
fi

# ==============================================================================
# 8. WARP SETUP
# ==============================================================================
step "Setting up warp manager"

if [[ -f "$DOTDIR/scripts/warp.sh" ]]; then
    chmod +x "$DOTDIR/scripts/warp.sh"
    sudo ln -sf "$DOTDIR/scripts/warp.sh" "/usr/local/bin/warp"
    ok "warp linked to /usr/local/bin/warp"
else
    info "warp.sh not found in $DOTDIR/scripts/"
fi

# ==============================================================================
# 9. BRAVE POLICIES
# ==============================================================================
step "Configuring Brave policies"

BRAVE_POLICY_DIR="/etc/brave/policies/managed"
BRAVE_POLICY_SRC="$DOTDIR/.config/brave/policies.json"

if [[ -f "$BRAVE_POLICY_SRC" ]]; then
    sudo mkdir -p "$BRAVE_POLICY_DIR"
    sudo cp "$BRAVE_POLICY_SRC" "$BRAVE_POLICY_DIR/arch-config.json"
    ok "Brave policies applied."
else
    info "policies.json not found in repo, skipping."
fi

# ==============================================================================
# 10. WALLPAPERS
# ==============================================================================
step "Setting up wallpapers"

WALLPAPERS_DIR="$HOME/Pictures/arch-config-wallpapers"
WALLPAPERS_REPO="https://github.com/jehan593/my-wallpapers"

if [[ ! -d "$WALLPAPERS_DIR" ]]; then
    info "Cloning wallpapers repo..."
    git clone "$WALLPAPERS_REPO" "$WALLPAPERS_DIR" \
        && ok "Wallpapers cloned to $WALLPAPERS_DIR" \
        || err "Failed to clone wallpapers repo."
    git -C "$WALLPAPERS_DIR" config --local credential.helper store
    ok "Git credential store configured for wallpapers repo."
else
    ok "Wallpapers already cloned."
fi

# ==============================================================================
# 11. THEMES
# ==============================================================================
step "Installing themes"

yay -S --noconfirm --needed \
    xcursor-simp1e-nord-light \
    nordic-darker-standard-buttons-theme \
    papirus-icon-theme \
    && ok "Theme packages installed." \
    || err "Failed to install some theme packages."

# Papirus Nord folder colors
info "Applying Papirus Nord folder colors (Frost Blue 4)..."
PAPIRUS_NORD_DIR="/tmp/papirus-nord-install"
rm -rf "$PAPIRUS_NORD_DIR"
if git clone https://github.com/Adapta-Projects/Papirus-Nord "$PAPIRUS_NORD_DIR" &>/dev/null; then
    if [[ -f "$PAPIRUS_NORD_DIR/install" ]]; then
        sudo bash "$PAPIRUS_NORD_DIR/install" \
            && ok "Papirus Nord icons installed." \
            || err "Failed to install Papirus Nord icons."
        papirus-folders -C frostblue4 --theme Papirus-Dark \
            && ok "Frost Blue 4 folder color applied." \
            || err "Failed to apply folder color."
    else
        err "install script not found in Papirus-Nord repo."
    fi
    rm -rf "$PAPIRUS_NORD_DIR"
else
    err "Failed to clone Papirus-Nord repo."
fi

# ==============================================================================
# DONE
# ==============================================================================
_print_footer
echo -e "${NORD_GREEN}Setup complete!${RST}"
echo -e "${NORD_D_BLUE}>> Run: source ~/.bashrc${RST}"
echo -e "${NORD_D_BLUE}>> Note: Install a Nerd Font for full icon support${RST}\n"
