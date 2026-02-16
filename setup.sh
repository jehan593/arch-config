#!/bin/bash

# Define colors for output (Nord-inspired)
CYAN='\033[0;36m'
BLUE='\033[0;34m'
RED='\033[0;31m'
RST='\033[0m'

echo -e "${CYAN}🚀 Starting Arch Dotfiles Setup...${RST}"

# 1. Check for AUR Helper (yay)
if ! command -v yay &> /dev/null; then
    echo -e "${BLUE}📦 Installing yay...${RST}"
    sudo pacman -S --needed base-devel git
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && makepkg -si --noconfirm && cd -
else
    echo -e "${CYAN}✅ yay is already installed.${RST}"
fi

# 2. Install Core Dependencies from your .bashrc
echo -e "${BLUE}📥 Installing dependencies...${RST}"
DEPENDENCIES=(
    "wireproxy"
    "bat"
    "plocate"
    "curl"
    "gvim"
    "starship" 
    "fzf" 
    "mpv" 
    "wl-copy" 
    "xclip" 
    "reflector" 
    "pacman-contrib" # provides checkupdates
)

yay -S --needed --noconfirm "${DEPENDENCIES[@]}"

# 3. Create Symlinks
echo -e "${BLUE}🔗 Creating symlinks...${RST}"
DOTDIR="$HOME/arch-config"

# Ensure .config exists
mkdir -p "$HOME/.config"

# Symlink bashrc (force overwrite)
ln -sf "$DOTDIR/bashrc" "$HOME/.bashrc"
ln -sf "$DOTDIR/vimrc" "$HOME/.vimrc"
mkdir -p ~/.vim/colors
curl -LSso ~/.vim/colors/nord.vim https://raw.githubusercontent.com/nordtheme/vim/main/colors/nord.vim

# Symlink starship (if you moved it to the repo)
if [ -f "$DOTDIR/starship.toml" ]; then
    ln -sf "$DOTDIR/starship.toml" "$HOME/.config/starship.toml"
fi

# --- NEW: Configure Bat for Nord Theme ---
echo -e "${BLUE}🦇 Configuring bat theme...${RST}"
mkdir -p "$HOME/.config/bat"
echo '--theme="Nord"' > "$HOME/.config/bat/config"
# -----------------------------------------

echo -e "${BLUE}🔐 Configuring passwordless updatedb...${RST}"
SUDOERS_FILE="/etc/sudoers.d/updatedb-nopasswd"
if [ ! -f "$SUDOERS_FILE" ]; then
    echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/updatedb" | sudo tee "$SUDOERS_FILE" > /dev/null
    sudo chmod 440 "$SUDOERS_FILE"
    echo -e "${CYAN}✅ Sudoers rule added.${RST}"
else
    echo -e "${CYAN}✅ Sudoers rule already exists.${RST}"
fi

# --- NEW: Wireproxy & wg-socks Setup ---
echo -e "${BLUE}🛡️ Setting up wg-socks manager...${RST}"
if [ -f "$DOTDIR/scripts/wg-socks.sh" ]; then
    sudo ln -sf "$DOTDIR/scripts/wg-socks.sh" "/usr/local/bin/wg-socks"
    sudo chmod +x "$DOTDIR/scripts/wg-socks.sh"
    echo -e "${CYAN}✅ wg-socks command linked to /usr/local/bin/wg-socks${RST}"
fi

echo -e "${CYAN}✅ Setup complete! Reloading bash...${RST}"
exec bash
