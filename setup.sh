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
    sudo pacman -S --needed base-devel git
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
# 2. CORE DEPENDENCIES
# ==============================================================================
step "Installing dependencies"

DEPENDENCIES=(
    "wireproxy"
    "wgcf"
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
)

info "Updating package database..."
yay -S --needed --noconfirm "${DEPENDENCIES[@]}"

info "Initializing plocate database..."
sudo updatedb
ok "Dependencies installed."

# ==============================================================================
# 3. SYMLINKS
# ==============================================================================
step "Creating symlinks"

mkdir -p "$HOME/.config"

# Root dotfiles
ln -sf "$DOTDIR/.bashrc" "$HOME/.bashrc"
ok "Linked .bashrc -> ~/.bashrc"

ln -sf "$DOTDIR/.vimrc" "$HOME/.vimrc"
ok "Linked .vimrc -> ~/.vimrc"

# .config symlinks - link files only, not folders
for item in "$DOTDIR/.config/"*/; do
    dir=$(basename "$item")
    mkdir -p "$HOME/.config/$dir"
    for file in "$item"*; do
        [[ -f "$file" ]] || continue
        ln -sf "$file" "$HOME/.config/$dir/$(basename "$file")"
        ok "Linked $dir/$(basename "$file") -> ~/.config/$dir/$(basename "$file")"
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

# Wallpapers
if [[ -d "$DOTDIR/wallpapers" ]]; then
    ln -sf "$DOTDIR/wallpapers" "$HOME/Pictures/arch-config-wallpapers"
    ok "Linked wallpapers -> ~/Pictures/arch-config-wallpapers"
else
    info "No wallpapers directory found in repo, skipping."
fi

# ==============================================================================
# 4. PASSWORDLESS UPDATEDB
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
# 4.5 PACMAN CANDY
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
# 5. WG-SOCKS SETUP
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
# 6. WARP SETUP
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
# 7. BRAVE POLICIES
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
# DONE
# ==============================================================================
_print_footer
echo -e "${NORD_GREEN}Setup complete!${RST}"
echo -e "${NORD_D_BLUE}>> Run: source ~/.bashrc${RST}"
echo -e "${NORD_D_BLUE}>> Note: Install a Nerd Font for full icon support${RST}\n"