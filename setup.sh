#!/bin/bash
# Arch Dotfiles Setup

if [[ "$EUID" -eq 0 ]]; then
    echo -e "\n\e[31m[!] Do not run this script as root.\e[0m\n"
    exit 1
fi

source "$HOME/arch-config/scripts/setup-helpers.sh"

DOTDIR="$HOME/arch-config"

_link_script() {
    local name="$1"
    local src="$DOTDIR/scripts/${name}.sh"
    if [[ -f "$src" ]]; then
        chmod +x "$src"
        sudo ln -sf "$src" "/usr/local/bin/$name"
        ok "$name linked to /usr/local/bin/$name"
    else
        info "${name}.sh not found in $DOTDIR/scripts/"
    fi
}

echo -e "\n${COLOR_CYAN}:: Arch Dotfiles Setup${RST}\n"

_print_header "󰒓" "Pre-flight Checks"

if [[ ! -d "$DOTDIR" ]]; then
    err "arch-config not found at $DOTDIR"
    err "Clone your repo first: git clone <url> ~/arch-config"
    echo ""
    exit 1
fi
ok "arch-config found at $DOTDIR"
echo ""

# AUR Helper (yay)
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

# Chaotic-AUR
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

# Core Dependencies
_print_header "󰏖" "Installing Dependencies"

DEPENDENCIES=(
    "wireproxy" "wgcf" "wireguard-tools"
    "plocate" "curl" 
    "starship" "fzf" "zoxide"
    "mpv" "xclip" "neovim"
    "reflector" "pacman-contrib" "git" "expac" "qview"
    "tldr" "topgrade" "gnome-session"
)

info "Updating package database..."
yay -S --needed --noconfirm "${DEPENDENCIES[@]}" \
    && ok "Dependencies installed." \
    || err "Some dependencies failed to install."

info "Initializing plocate database..."
sudo updatedb

info "Updating tldr pages..."
tldr --update \
    && ok "tldr pages updated." \
    || err "Failed to update tldr pages."
echo ""

# Symlinks
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

# Passwordless updatedb
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

# Pacman Configuration
_print_header "󰮯" "Pacman Configuration"

if ! grep -q "ILoveCandy" /etc/pacman.conf; then
    sudo sed -i 's/^#Color/Color/' /etc/pacman.conf
    sudo sed -i '/^Color/a ILoveCandy' /etc/pacman.conf
    ok "Color + ILoveCandy added to pacman.conf"
else
    ok "ILoveCandy already set."
fi
echo ""

# wg-socks Setup
_print_header "󰒄" "wg-socks Manager"

_link_script "wg-socks"
echo ""

# VPN Setup
_print_header "󰖂" "VPN Manager"

_link_script "vpn"
echo ""

# Brave Policies
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

# Firefox Policies
_print_header "󰈹" "Firefox Policies"

FIREFOX_POLICY_DIR="/etc/firefox/policies"
FIREFOX_POLICY_SRC="$DOTDIR/.config/firefox/policies.json"

if [[ -f "$FIREFOX_POLICY_SRC" ]]; then
    sudo mkdir -p "$FIREFOX_POLICY_DIR"
    sudo cp "$FIREFOX_POLICY_SRC" "$FIREFOX_POLICY_DIR/policies.json"
    ok "Firefox policies applied."
else
    info "policies.json not found in repo, skipping."
fi
echo ""

# VS Code Policies
_print_header "󰨞" "VS Code Policies"

VSCODE_POLICY_DIR="/etc/vscode"
VSCODE_POLICY_SRC="$DOTDIR/.config/vscode/policy.json"

if [[ -f "$VSCODE_POLICY_SRC" ]]; then
    sudo mkdir -p "$VSCODE_POLICY_DIR"
    sudo cp "$VSCODE_POLICY_SRC" "$VSCODE_POLICY_DIR/policy.json"
    sudo chmod 644 "$VSCODE_POLICY_DIR/policy.json"
    sudo chown root:root "$VSCODE_POLICY_DIR/policy.json"
    ok "VS Code policies applied."
else
    info "policy.json not found in repo, skipping."
fi
echo ""

# Wallpapers
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

# Themes
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

# Neovim Configuration
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

# Timer Script
_print_header "󰔛" "Timer Script"

_link_script "timer"
echo ""

# Done
_print_status "󰄬" "Setup complete! Restart your shell."
echo ""
echo -e " ${COLOR_BLUE}->  Run: source ~/.bashrc${RST}"
echo -e " ${COLOR_BLUE}->  Install a Nerd Font for full icon support${RST}"
echo ""