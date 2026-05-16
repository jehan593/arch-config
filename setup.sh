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

# --- UI Helpers ---

_print_header() {
    echo -e "\n${NORD_CYAN}${1}  ${NORD_SNOW_1}${2}${RST}"
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

# --- Pre-flight checks ---

if [[ "$EUID" -eq 0 ]]; then
    echo -e "\n${NORD_RED}󰅙  Do not run this script as root.${RST}\n"
    exit 1
fi

DOTDIR="$HOME/arch-config"

echo -e "\n${NORD_CYAN}󰣇  Arch Dotfiles Setup${RST}\n"

_print_header "󰒓" "Pre-flight Checks"

if [[ ! -d "$DOTDIR" ]]; then
    err "arch-config not found at $DOTDIR"
    err "Clone your repo first: git clone <url> ~/arch-config"
    echo ""
    exit 1
fi
ok "arch-config found at $DOTDIR"
echo ""

# ==============================================================================
# 1. AUR HELPER (yay)
# ==============================================================================
_print_header "󰏖" "AUR Helper (yay)"

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
echo ""

# ==============================================================================
# 2. CHAOTIC-AUR
# ==============================================================================
_print_header "󰒓" "Chaotic-AUR"

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
echo ""

# ==============================================================================
# 3. CORE DEPENDENCIES
# ==============================================================================
_print_header "󰏖" "Installing Dependencies"

DEPENDENCIES=(
    "wireproxy" "wgcf" "wireguard-tools"
    "plocate" "curl" 
    "starship" "fzf" "zoxide"
    "mpv" "xclip" "neovim"
    "reflector" "pacman-contrib" "git" "expac" "qview"
)

info "Updating package database..."
yay -S --needed --noconfirm "${DEPENDENCIES[@]}" \
    && ok "Dependencies installed." \
    || err "Some dependencies failed to install."

info "Initializing plocate database..."
sudo updatedb
echo ""

# ==============================================================================
# 4. SYMLINKS
# ==============================================================================
_print_header "󰈔" "Creating Symlinks"

mkdir -p "$HOME/.config"

ln -sf "$DOTDIR/.bashrc" "$HOME/.bashrc"
ok "Linked .bashrc → ~/.bashrc"

for file in "$DOTDIR/.config/"*; do
    [[ -f "$file" ]] || continue
    ln -sf "$file" "$HOME/.config/$(basename "$file")"
    ok "Linked .config/$(basename "$file")"
done

for item in "$DOTDIR/.config/"*/; do
    dir=$(basename "$item")
    mkdir -p "$HOME/.config/$dir"
    for file in "$item"*; do
        [[ -f "$file" ]] || continue
        ln -sf "$file" "$HOME/.config/$dir/$(basename "$file")"
        ok "Linked .config/$dir/$(basename "$file")"
    done
done

# ==============================================================================
# 5. PASSWORDLESS UPDATEDB
# ==============================================================================
_print_header "󰒓" "Passwordless updatedb"

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
        err "Sudoers validation failed — skipping passwordless updatedb."
    fi
else
    ok "Sudoers rule already exists."
fi
echo ""

# ==============================================================================
# 6. PACMAN CANDY
# ==============================================================================
_print_header "󰮯" "Pacman Configuration"

if ! grep -q "ILoveCandy" /etc/pacman.conf; then
    sudo sed -i 's/^#Color/Color/' /etc/pacman.conf
    sudo sed -i '/^Color/a ILoveCandy' /etc/pacman.conf
    ok "Color + ILoveCandy added to pacman.conf"
else
    ok "ILoveCandy already set."
fi
echo ""

# ==============================================================================
# 7. WG-SOCKS SETUP
# ==============================================================================
_print_header "󰒄" "wg-socks Manager"

if [[ -f "$DOTDIR/scripts/wg-socks.sh" ]]; then
    chmod +x "$DOTDIR/scripts/wg-socks.sh"
    sudo ln -sf "$DOTDIR/scripts/wg-socks.sh" "/usr/local/bin/wg-socks"
    ok "wg-socks linked to /usr/local/bin/wg-socks"
else
    info "wg-socks script not found in $DOTDIR/scripts/"
fi
echo ""

# ==============================================================================
# 8. WARP SETUP
# ==============================================================================
_print_header "󰖂" "WARP Manager"

if [[ -f "$DOTDIR/scripts/warp.sh" ]]; then
    chmod +x "$DOTDIR/scripts/warp.sh"
    sudo ln -sf "$DOTDIR/scripts/warp.sh" "/usr/local/bin/warp"
    ok "warp linked to /usr/local/bin/warp"
else
    info "warp.sh not found in $DOTDIR/scripts/"
fi
echo ""

# ==============================================================================
# 9. BRAVE POLICIES
# ==============================================================================
_print_header "󰈹" "Brave Policies"

BRAVE_POLICY_DIR="/etc/brave/policies/managed"
BRAVE_POLICY_SRC="$DOTDIR/.config/brave/policies.json"

if [[ -f "$BRAVE_POLICY_SRC" ]]; then
    sudo mkdir -p "$BRAVE_POLICY_DIR"
    sudo cp "$BRAVE_POLICY_SRC" "$BRAVE_POLICY_DIR/arch-config.json"
    ok "Brave policies applied."
else
    info "policies.json not found in repo, skipping."
fi
echo ""

# ==============================================================================
# 10. WALLPAPERS
# ==============================================================================
_print_header "󰹧" "Wallpapers"

WALLPAPERS_DIR="$HOME/Pictures/config-wallpapers"
WALLPAPERS_REPO="https://github.com/jehan593/my-wallpapers"

if [[ ! -d "$WALLPAPERS_DIR" ]]; then
    info "Cloning wallpapers repo..."
    git clone --depth 1 "$WALLPAPERS_REPO" "$WALLPAPERS_DIR" \
        && ok "Wallpapers cloned to $WALLPAPERS_DIR" \
        || err "Failed to clone wallpapers repo."
    git -C "$WALLPAPERS_DIR" config --local credential.helper store
    ok "Git credential store configured."
else
    ok "Wallpapers already cloned."
fi
echo ""

# ==============================================================================
# 11. THEMES
# ==============================================================================
_print_header "󰔎" "Installing Themes"

yay -S --noconfirm --needed \
    xcursor-simp1e-nord-light \
    nordic-bluish-accent-standard-buttons-theme \
    ttf-martian-mono-nerd \
    papirus-icon-theme \
    && ok "Theme packages installed." \
    || err "Failed to install some theme packages."

info "Applying Papirus Nord folder colors (Frost Blue 4)..."
PAPIRUS_NORD_DIR="/tmp/papirus-nord-install"
rm -rf "$PAPIRUS_NORD_DIR"
if git clone https://github.com/Adapta-Projects/Papirus-Nord "$PAPIRUS_NORD_DIR" &>/dev/null; then
    if [[ -f "$PAPIRUS_NORD_DIR/install" ]]; then
        cd "$PAPIRUS_NORD_DIR" || exit 1
        echo "N" | sudo bash install \
            && ok "Papirus Nord icons installed." \
            || err "Failed to install Papirus Nord icons."
        cd "$OLDPWD" || exit
        if command -v papirus-folders &>/dev/null; then
            papirus-folders -C frostblue4 --theme Papirus-Dark \
                && ok "Frost Blue 4 folder color applied." \
                || err "Failed to apply folder color."
        else
            sudo /usr/bin/papirus-folders -C frostblue4 --theme Papirus-Dark \
                && ok "Frost Blue 4 folder color applied." \
                || err "papirus-folders not found after install."
        fi
    else
        err "install script not found in Papirus-Nord repo."
    fi
    rm -rf "$PAPIRUS_NORD_DIR"
else
    err "Failed to clone Papirus-Nord repo."
fi
echo ""

# ==============================================================================
# 12. NEOVIM CONFIGURATION
# ==============================================================================
_print_header "󰕮" "Neovim Configuration"

NVIM_CONFIG_DIR="$HOME/.config/nvim"
REPO_INIT_LUA="$DOTDIR/.config/nvim/init.lua"
INIT_TARGET="$NVIM_CONFIG_DIR/init.lua"

if [[ ! -f "$REPO_INIT_LUA" ]]; then
    info ".config/nvim/init.lua not found in repo — skipping."
else
    mkdir -p "$NVIM_CONFIG_DIR"
    if [[ -L "$INIT_TARGET" && "$(readlink "$INIT_TARGET")" == "$REPO_INIT_LUA" ]]; then
        ok "Already linked: ~/.config/nvim/init.lua"
    else
        ln -sf "$REPO_INIT_LUA" "$INIT_TARGET"
        ok "Linked: ~/.config/nvim/init.lua"
    fi
fi
echo ""

# ==============================================================================
# 13. TIMER SCRIPT
# ==============================================================================
_print_header "󰔛" "Timer Script"

if [[ -f "$DOTDIR/scripts/timer.sh" ]]; then
    chmod +x "$DOTDIR/scripts/timer.sh"
    sudo ln -sf "$DOTDIR/scripts/timer.sh" "/usr/local/bin/timer"
    ok "timer linked to /usr/local/bin/timer"
else
    info "timer.sh not found in $DOTDIR/scripts/"
fi
echo ""

# ==============================================================================
# DONE
# ==============================================================================
_print_status "󰄬" "Setup complete! Please restart your shell."
echo ""
echo -e "${NORD_D_BLUE}󰁔  Run: source ~/.bashrc${RST}"
echo -e "${NORD_D_BLUE}󰁔  Install a Nerd Font for full icon support${RST}"
echo ""