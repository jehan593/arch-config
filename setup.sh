#!/bin/bash
# Arch Dotfiles Setup

if [[ "$EUID" -eq 0 ]]; then
    echo -e "\e[31mDo not run this script as root.\e[0m"
    exit 1
fi

DOTDIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"

source "$DOTDIR/helpers/setup-helpers.sh"

echo -e "${COLOR_CYAN}:: Arch Dotfiles Setup${RST}\n"

_print_header "Pre-flight Checks" ""

if [[ ! -d "$DOTDIR/scripts" ]]; then
    err "Unexpected repo layout: $DOTDIR/scripts not found"
    err "Make sure setup.sh is run from within a full arch-config checkout"
    echo ""
    exit 1
fi
ok "arch-config found at $DOTDIR"
echo ""

_print_header "Sudo Authentication" ""
sudo -v || { err "Sudo authentication failed."; exit 1; }
ok "Sudo authenticated."
echo ""

# Environment Variable
_print_header "Environment Variable" ""

echo "export ARCH_CONFIG_PATH=\"$DOTDIR\"" | sudo tee /etc/profile.d/arch-config.sh > /dev/null
sudo chmod 644 /etc/profile.d/arch-config.sh
ok "ARCH_CONFIG_PATH set to $DOTDIR"
echo ""

# User Config Directory
_print_header "User Config Directory" ""

mkdir -p "$HOME/.config/arch-config-files"
ok "Created ~/.config/arch-config-files (owned by $USER)"
echo ""

# Home Files
_print_header "Linking Home Files" ""

_home_file_action() {
    local src="$1" target="$2"
    mkdir -p "$(dirname "$target")"

    if [[ ( -e "$target" || -L "$target" ) && "$(readlink "$target" 2>/dev/null)" != "$src" ]]; then
        local backup="$target.bak.$(date +%Y%m%d_%H%M%S)"
        mv "$target" "$backup"
        info "Backed up existing $(basename "$target") to $(basename "$backup")"
    fi

    ln -sf "$src" "$target"
    ok "Linked ${target/#$HOME/\~}"
}
_each_home_file
echo ""

# Scripts
_print_header "Linking Scripts" ""

_script_file_action() {
    local name="$1" src="$2"
    chmod +x "$src"
    sudo ln -sf "$src" "/usr/local/bin/$name"
    ok "$name linked to /usr/local/bin/$name"
}
_each_script_file
echo ""

# Etc Files
_print_header "Installing Etc Files" ""

_etc_file_action() {
    local src="$1" dest="$2"
    sudo mkdir -p "$(dirname "$dest")"
    sudo cp "$src" "$dest"
    sudo chmod 644 "$dest"
    sudo chown root:root "$dest"
    ok "Installed policy: $dest"
}
_each_etc_file
echo ""

# AUR Helper (yay)
_print_header "AUR Helper (yay)" ""

if ! command -v yay &>/dev/null; then
    note "Installing yay..."
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
_print_header "Chaotic-AUR" ""

if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
    note "Adding Chaotic-AUR keyring and mirrorlist..."
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
_print_header "Installing Dependencies" ""

note "Updating package database..."
yay -S --needed --noconfirm "${DEPENDENCIES[@]}" \
    && ok "Dependencies installed." \
    || err "Some dependencies failed to install."

note "Initializing plocate database..."
sudo updatedb

note "Updating tldr pages..."
tldr --update \
    && ok "tldr pages updated." \
    || err "Failed to update tldr pages."
echo ""

# Passwordless updatedb
_print_header "Passwordless updatedb" ""

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
_print_header "Pacman Configuration" ""

if ! grep -q "ILoveCandy" /etc/pacman.conf; then
    sudo sed -i 's/^#Color/Color/' /etc/pacman.conf
    sudo sed -i '/^Color/a ILoveCandy' /etc/pacman.conf
    ok "Color + ILoveCandy added to pacman.conf"
else
    ok "ILoveCandy already set."
fi
echo ""

# Wallpapers
_print_header "Wallpapers" ""

WALLPAPERS_DIR="$HOME/Pictures/config-wallpapers"
WALLPAPERS_REPO="https://github.com/jehan593/my-wallpapers"

if [[ ! -d "$WALLPAPERS_DIR" ]]; then
    note "Cloning wallpapers repo..."
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
_print_header "Installing Themes" ""

yay -S --noconfirm --needed "${THEME_PACKAGES[@]}" \
    && ok "Theme packages installed." \
    || err "Failed to install some theme packages."

note "Applying Papirus Nord folder colors (Frost Blue 4)..."
PAPIRUS_NORD_DIR="/tmp/papirus-nord-install"
rm -rf "$PAPIRUS_NORD_DIR"
if git clone https://github.com/Adapta-Projects/Papirus-Nord "$PAPIRUS_NORD_DIR"; then
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

# Apply Theme & Font Settings
_print_header "Applying Theme & Font Settings" ""

for entry in "${THEME_SETTINGS[@]}"; do
    IFS='|' read -r schema key value <<< "$entry"
    gsettings set "$schema" "$key" "$value" \
        && ok "$schema $key -> $value" \
        || err "Failed to set $schema $key"
done
echo ""

# Done
ok "Setup complete! Restart your shell."
echo ""
echo -e "${COLOR_BLUE}-> Run: source ~/.bashrc${RST}"
