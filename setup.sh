#!/bin/bash

# ==============================================================================
# ARCH DOTFILES SETUP
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

# Do not run as root
if [[ "$EUID" -eq 0 ]]; then
    err "Do not run this script as root."
    exit 1
fi

# Check arch-config repo exists
DOTDIR="$HOME/arch-config"
if [[ ! -d "$DOTDIR" ]]; then
    err "arch-config not found at $DOTDIR"
    err "Please clone your repo first: git clone <your-repo-url> ~/arch-config"
    exit 1
fi

echo -e "${CYAN}"
echo "  ================================================"
echo "       Arch Dotfiles Setup"
echo "  ================================================"
echo -e "${RST}"

# ==============================================================================
# 1. AUR HELPER (yay)
# ==============================================================================
step "Checking AUR helper (yay)..."

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
# 2. CORE DEPENDENCIES
# ==============================================================================
step "Installing dependencies..."

DEPENDENCIES=(
    "wireproxy"
    "bat"
    "plocate"
    "curl"
    "gvim"
    "starship"
    "fzf"
    "zoxide"
    "mpv"
    "wl-clipboard"      # provides wl-copy and wl-paste
    "xclip"
    "reflector"
    "pacman-contrib"    # provides checkupdates
)

yay -S --needed --noconfirm "${DEPENDENCIES[@]}"

info "Initializing plocate database..."
sudo updatedb
ok "Dependencies installed."

# ==============================================================================
# 3. SYMLINKS
# ==============================================================================
step "Creating symlinks..."

mkdir -p "$HOME/.config"

# bashrc and vimrc
ln -sf "$DOTDIR/bashrc" "$HOME/.bashrc"
ok "Linked bashrc -> ~/.bashrc"

ln -sf "$DOTDIR/vimrc" "$HOME/.vimrc"
ok "Linked vimrc -> ~/.vimrc"

# starship config
if [[ -f "$DOTDIR/starship.toml" ]]; then
    ln -sf "$DOTDIR/starship.toml" "$HOME/.config/starship.toml"
    ok "Linked starship.toml -> ~/.config/starship.toml"
else
    info "starship.toml not found in repo, skipping."
fi

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
# 4. PASSWORDLESS UPDATEDB
# ==============================================================================
step "Configuring passwordless updatedb..."

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
# 5. WG-SOCKS SETUP
# ==============================================================================
step "Setting up wg-socks manager..."

if [[ -f "$DOTDIR/scripts/wg-socks.sh" ]]; then
    chmod +x "$DOTDIR/scripts/wg-socks.sh"
    sudo ln -sf "$DOTDIR/scripts/wg-socks.sh" "/usr/local/bin/wg-socks"
    ok "wg-socks linked to /usr/local/bin/wg-socks"
else
    err "wg-socks.sh not found in $DOTDIR/scripts/, skipping."
fi

# ==============================================================================
# DONE
# ==============================================================================
echo -e "\n${CYAN}  ================================================${RST}"
echo -e "${GREEN}  Setup complete!${RST}"
echo -e "${D_BLUE}  - Open a new terminal or run: source ~/.bashrc${RST}"
echo -e "${D_BLUE}  - Note: Install a Nerd Font for full icon support${RST}"
echo -e "${CYAN}  ================================================${RST}\n"