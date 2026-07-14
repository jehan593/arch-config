#!/bin/bash

# ==============================================================================
# ARCH DOTFILES INSTALLER
# ==============================================================================

DOTDIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"

source "$DOTDIR/helpers/colors-standard.sh"
source "$DOTDIR/helpers/printer.sh"
source "$DOTDIR/helpers/pkg-list.sh"
source "$DOTDIR/helpers/theme-settings.sh"
source "$DOTDIR/helpers/link-helpers.sh"

# ==============================================================================
# START
# ==============================================================================

printfc "$CYAN" "\n┌───────────────────────┐"
printfc "$CYAN" "│  Arch Dotfiles Setup  │"
printfc "$CYAN" "└───────────────────────┘"

# ==============================================================================
# 0. PREREQUISITES CHECK
# ==============================================================================

printfc "$BLUE" "\n>Pre-flight Checks"

if [[ "$EUID" -eq 0 ]]; then
    printfc "$RED" "Do not run this script as root."
    exit 1
fi

if [[ ! -d "$DOTDIR/tools" ]]; then
    printfc "$RED" "Unexpected repo layout: %s/tools not found" "$DOTDIR"
    printfc "$RED" "Make sure setup.sh is run from within a full arch-config checkout"
    echo ""
    exit 1
fi
printfc "$GREEN" "arch-config found at %s" "$DOTDIR"
echo ""

printfc "$BLUE" "\n>Sudo Authentication"
sudo -v || { printfc "$RED" "Sudo authentication failed."; exit 1; }
printfc "$GREEN" "Sudo authenticated."
echo ""

# ==============================================================================
# 1. ENVIRONMENT VARIABLE
# ==============================================================================

printfc "$BLUE" "\n>Environment Variable"

echo "export ARCH_CONFIG_PATH=\"$DOTDIR\"" | sudo tee /etc/profile.d/arch-config.sh > /dev/null
sudo chmod 644 /etc/profile.d/arch-config.sh
printfc "$GREEN" "ARCH_CONFIG_PATH set to %s" "$DOTDIR"
echo ""

# ==============================================================================
# 2. USER CONFIG DIRECTORY
# ==============================================================================

printfc "$BLUE" "\n>User Config Directory"

mkdir -p "$HOME/.config/arch-config-files"
printfc "$GREEN" "Created ~/.config/arch-config-files (owned by %s)" "$USER"
echo ""

# ==============================================================================
# 3. HOME FILES
# ==============================================================================

printfc "$BLUE" "\n>Linking Home Files\n"

_home_file_action() {
    local src="$1" target="$2"
    mkdir -p "$(dirname "$target")"

    if [[ ( -e "$target" || -L "$target" ) && "$(readlink "$target" 2>/dev/null)" != "$src" ]]; then
        local backup="$target.bak.$(date +%Y%m%d_%H%M%S)"
        mv "$target" "$backup"
        printfc "$YELLOW" "Backed up existing %s to %s" "$(basename "$target")" "$(basename "$backup")"
    fi

    ln -sf "$src" "$target"
    printfc "$GREEN" "Linked %s" "${target/#$HOME/\~}"
}
_each_home_file
echo ""

# ==============================================================================
# 4. TOOLS
# ==============================================================================

printfc "$BLUE" "\n>Linking Tools\n"

_tool_file_action() {
    local name="$1" src="$2"
    chmod +x "$src"
    sudo ln -sf "$src" "/usr/local/bin/$name"
    printfc "$GREEN" "%s linked to /usr/local/bin/%s" "$name" "$name"
}
_each_tool_file
echo ""

# ==============================================================================
# 5. ETC FILES
# ==============================================================================

printfc "$BLUE" "\n>Installing Etc Files\n"

_etc_file_action() {
    local src="$1" dest="$2"
    sudo mkdir -p "$(dirname "$dest")"
    sudo cp "$src" "$dest"
    sudo chmod 644 "$dest"
    sudo chown root:root "$dest"
    printfc "$GREEN" "Installed policy: %s" "$dest"
}
_each_etc_file
echo ""

# ==============================================================================
# 6. AUR HELPER (yay)
# ==============================================================================

printfc "$BLUE" "\n>AUR Helper (yay)"

if ! command -v yay &>/dev/null; then
    printfc "$YELLOW" "Installing yay..."
    sudo pacman -S --needed --noconfirm base-devel git
    rm -rf /tmp/yay-install
    git clone https://aur.archlinux.org/yay.git /tmp/yay-install
    (cd /tmp/yay-install && makepkg -si --noconfirm)
    rm -rf /tmp/yay-install
    printfc "$GREEN" "yay installed."
else
    printfc "$GREEN" "yay already installed."
fi
echo ""

# ==============================================================================
# 7. CHAOTIC-AUR
# ==============================================================================

printfc "$BLUE" "\n>Chaotic-AUR"

if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
    printfc "$YELLOW" "Adding Chaotic-AUR keyring and mirrorlist..."
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key 3056513887B78AEB
    sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
    sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf > /dev/null
    sudo pacman -Sy
    printfc "$GREEN" "Chaotic-AUR added."
else
    printfc "$GREEN" "Chaotic-AUR already configured."
fi
echo ""

# ==============================================================================
# 8. DEPENDENCIES
# ==============================================================================

printfc "$BLUE" "\n>Installing Dependencies\n"

printfc "$YELLOW" "Updating package database..."
yay -S --needed --noconfirm "${DEPENDENCIES[@]}" \
    && printfc "$GREEN" "Dependencies installed." \
    || printfc "$RED" "Some dependencies failed to install."

printfc "$YELLOW" "Initializing plocate database..."
sudo updatedb

printfc "$YELLOW" "Updating tldr pages..."
tldr --update \
    && printfc "$GREEN" "tldr pages updated." \
    || printfc "$RED" "Failed to update tldr pages."
echo ""

# ==============================================================================
# 9. PASSWORDLESS updatedb
# ==============================================================================

printfc "$BLUE" "\n>Passwordless updatedb"

SUDOERS_FILE="/etc/sudoers.d/updatedb-nopasswd"
if [[ ! -f "$SUDOERS_FILE" ]]; then
    SUDOERS_TMP="${SUDOERS_FILE}.tmp"
    echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/updatedb" | sudo tee "$SUDOERS_TMP" > /dev/null
    if sudo visudo -c -f "$SUDOERS_TMP" &>/dev/null; then
        sudo mv "$SUDOERS_TMP" "$SUDOERS_FILE"
        sudo chmod 440 "$SUDOERS_FILE"
        printfc "$GREEN" "Sudoers rule added for updatedb."
    else
        sudo rm -f "$SUDOERS_TMP"
        printfc "$RED" "Sudoers validation failed — skipping passwordless updatedb."
    fi
else
    printfc "$GREEN" "Sudoers rule already exists."
fi
echo ""

# ==============================================================================
# 10. PACMAN CONFIGURATION
# ==============================================================================

printfc "$BLUE" "\n>Pacman Configuration"

if ! grep -q "ILoveCandy" /etc/pacman.conf; then
    sudo sed -i 's/^#Color/Color/' /etc/pacman.conf
    sudo sed -i '/^Color/a ILoveCandy' /etc/pacman.conf
    printfc "$GREEN" "Color + ILoveCandy added to pacman.conf"
else
    printfc "$GREEN" "ILoveCandy already set."
fi
echo ""

# ==============================================================================
# 11. WALLPAPERS
# ==============================================================================

printfc "$BLUE" "\n>Wallpapers"

WALLPAPERS_DIR="$HOME/Pictures/config-wallpapers"
WALLPAPERS_REPO="https://github.com/jehan593/my-wallpapers"

if [[ ! -d "$WALLPAPERS_DIR" ]]; then
    printfc "$YELLOW" "Cloning wallpapers repo..."
    git clone --depth 1 "$WALLPAPERS_REPO" "$WALLPAPERS_DIR" \
        && printfc "$GREEN" "Wallpapers cloned to %s" "$WALLPAPERS_DIR" \
        || printfc "$RED" "Failed to clone wallpapers repo."
    git -C "$WALLPAPERS_DIR" config --local credential.helper store
    printfc "$GREEN" "Git credential store configured."
else
    printfc "$GREEN" "Wallpapers already cloned."
fi
echo ""

# ==============================================================================
# 12. THEMES
# ==============================================================================

printfc "$BLUE" "\n>Installing Themes"

yay -S --noconfirm --needed "${THEME_PACKAGES[@]}" \
    && printfc "$GREEN" "Theme packages installed." \
    || printfc "$RED" "Failed to install some theme packages."

printfc "$YELLOW" "Applying Papirus Nord folder colors (Frost Blue 4)..."
PAPIRUS_NORD_DIR="/tmp/papirus-nord-install"
rm -rf "$PAPIRUS_NORD_DIR"
if git clone https://github.com/Adapta-Projects/Papirus-Nord "$PAPIRUS_NORD_DIR"; then
    if [[ -f "$PAPIRUS_NORD_DIR/install" ]]; then
        cd "$PAPIRUS_NORD_DIR" || exit 1
        echo "N" | sudo bash install \
            && printfc "$GREEN" "Papirus Nord icons installed." \
            || printfc "$RED" "Failed to install Papirus Nord icons."
        cd "$OLDPWD" || exit
        if command -v papirus-folders &>/dev/null; then
            papirus-folders -C frostblue4 --theme Papirus-Dark \
                && printfc "$GREEN" "Frost Blue 4 folder color applied." \
                || printfc "$RED" "Failed to apply folder color."
        else
            sudo /usr/bin/papirus-folders -C frostblue4 --theme Papirus-Dark \
                && printfc "$GREEN" "Frost Blue 4 folder color applied." \
                || printfc "$RED" "papirus-folders not found after install."
        fi
    else
        printfc "$RED" "install script not found in Papirus-Nord repo."
    fi
    rm -rf "$PAPIRUS_NORD_DIR"
else
    printfc "$RED" "Failed to clone Papirus-Nord repo."
fi
echo ""

# ==============================================================================
# 13. APPLY THEME & FONT SETTINGS
# ==============================================================================

printfc "$BLUE" "\n>Applying Theme & Font Settings"

for entry in "${THEME_SETTINGS[@]}"; do
    IFS='|' read -r schema key value <<< "$entry"
    gsettings set "$schema" "$key" "$value" \
        && printfc "$GREEN" "%s %s -> %s" "$schema" "$key" "$value" \
        || printfc "$RED" "Failed to set %s %s" "$schema" "$key"
done
echo ""

# ==============================================================================
# DONE
# ==============================================================================

printfc "$GREEN" "Setup complete! Restart your shell."
printfc "$YELLOW" "Run: source ~/.bashrc"
echo ""
