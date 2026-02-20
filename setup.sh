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
    (cd /tmp/yay && makepkg -si --noconfirm)
else
    echo -e "${CYAN}✅ yay is already installed.${RST}"
fi

# 2. Install Core Dependencies
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
    "wl-clipboard"      # provides wl-copy and wl-paste
    "xclip"
    "reflector"
    "pacman-contrib"    # provides checkupdates
)
yay -S --needed --noconfirm "${DEPENDENCIES[@]}"

# 3. Create Symlinks
echo -e "${BLUE}🔗 Creating symlinks...${RST}"
DOTDIR="$HOME/arch-config"

# Ensure .config exists
mkdir -p "$HOME/.config"

# Symlink bashrc and vimrc
ln -sf "$DOTDIR/bashrc" "$HOME/.bashrc"
ln -sf "$DOTDIR/vimrc" "$HOME/.vimrc"

# Download Nord theme for vim only if not already present
mkdir -p ~/.vim/colors
if [ ! -f ~/.vim/colors/nord.vim ]; then
    echo -e "${BLUE}🎨 Downloading Nord vim theme...${RST}"
    curl -o ~/.vim/colors/nord.vim https://raw.githubusercontent.com/nordtheme/vim/main/colors/nord.vim
else
    echo -e "${CYAN}✅ Nord vim theme already exists.${RST}"
fi

# Symlink starship config if present in repo
if [ -f "$DOTDIR/starship.toml" ]; then
    ln -sf "$DOTDIR/starship.toml" "$HOME/.config/starship.toml"
fi

# Configure Bat for Nord Theme
echo -e "${BLUE}🦇 Configuring bat theme...${RST}"
mkdir -p "$HOME/.config/bat"
echo '--theme="Nord"' > "$HOME/.config/bat/config"

# 4. Configure passwordless updatedb
echo -e "${BLUE}🔐 Configuring passwordless updatedb...${RST}"
SUDOERS_FILE="/etc/sudoers.d/updatedb-nopasswd"
if [ ! -f "$SUDOERS_FILE" ]; then
    SUDOERS_TMP="${SUDOERS_FILE}.tmp"
    echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/updatedb" | sudo tee "$SUDOERS_TMP" > /dev/null
    # Validate before applying
    if sudo visudo -c -f "$SUDOERS_TMP"; then
        sudo mv "$SUDOERS_TMP" "$SUDOERS_FILE"
        sudo chmod 440 "$SUDOERS_FILE"
        echo -e "${CYAN}✅ Sudoers rule added.${RST}"
    else
        sudo rm -f "$SUDOERS_TMP"
        echo -e "${RED}❌ Sudoers rule validation failed. Skipping.${RST}"
    fi
else
    echo -e "${CYAN}✅ Sudoers rule already exists.${RST}"
fi

# 5. Wireproxy & wg-socks Setup
echo -e "${BLUE}🛡️ Setting up wg-socks manager...${RST}"
if [ -f "$DOTDIR/scripts/wg-socks.sh" ]; then
    chmod +x "$DOTDIR/scripts/wg-socks.sh"
    sudo ln -sf "$DOTDIR/scripts/wg-socks.sh" "/usr/local/bin/wg-socks"
    echo -e "${CYAN}✅ wg-socks command linked to /usr/local/bin/wg-socks${RST}"
else
    echo -e "${RED}⚠️  wg-socks.sh not found in $DOTDIR/scripts/, skipping.${RST}"
fi

echo -e "${CYAN}✅ Setup complete! Run 'source ~/.bashrc' to reload your shell.${RST}"