COLOR_GRAY='\e[90m'
COLOR_WHITE='\e[97m'
COLOR_CYAN='\e[36m'
COLOR_BLUE='\e[34m'
COLOR_GREEN='\e[32m'
COLOR_RED='\e[31m'
COLOR_YELLOW='\e[33m'
RST='\e[0m'

_print_header() {
    echo -e "\n${COLOR_CYAN}${1}${COLOR_WHITE}${2}${RST}"
    echo -e "${COLOR_GRAY}─────────────────────────────────────────────────────${RST}"
}

ok()   { echo -e "${COLOR_GREEN}${1}${RST}"; }
err()  { echo -e "${COLOR_RED}${1}${RST}"; }
info() { echo -e "${COLOR_YELLOW}${1}${RST}"; }
note() { echo -e "${COLOR_GRAY}${1}${RST}"; }

# Shared package lists — single source of truth for setup.sh and reset.sh
DEPENDENCIES=(
    "wireproxy" "wgcf" "wireguard-tools"
    "plocate" "curl"
    "starship" "fzf" "zoxide"
    "mpv" "xclip" "neovim"
    "reflector" "pacman-contrib" "git" "expac" "qview"
    "tldr" "topgrade"
)

THEME_PACKAGES=(
    "xcursor-simp1e-nord-light"
    "nordic-bluish-accent-standard-buttons-theme"
    "ttf-martian-mono-nerd"
    "papirus-icon-theme"
)

# Theme/font settings applied by setup.sh via gsettings — reset.sh resets the
# same (schema, key) pairs back to their compiled schema defaults.
THEME_SETTINGS=(
    "org.cinnamon.desktop.interface|cursor-theme|Simp1e-Nord-Light"
    "org.cinnamon.desktop.interface|gtk-theme|Nordic-bluish-accent-standard-buttons"
    "org.cinnamon.desktop.interface|icon-theme|Papirus-Dark"
    "org.cinnamon.desktop.interface|font-name|MartianMono Nerd Font 9"
    "org.cinnamon.desktop.wm.preferences|theme|Nordic-bluish-accent-standard-buttons"
    "org.cinnamon.desktop.wm.preferences|titlebar-font|MartianMono Nerd Font Bold 9"
    "org.cinnamon.theme|name|Nordic-bluish-accent-standard-buttons"
    "org.nemo.desktop|font|MartianMono Nerd Font 9"
    "org.gnome.desktop.interface|cursor-theme|Simp1e-Nord-Light"
    "org.gnome.desktop.interface|gtk-theme|Nordic-bluish-accent-standard-buttons"
    "org.gnome.desktop.interface|icon-theme|Papirus-Dark"
    "org.gnome.desktop.interface|font-name|MartianMono Nerd Font 9"
    "org.gnome.desktop.interface|monospace-font-name|MartianMono Nerd Font Mono 9"
    "org.gnome.desktop.wm.preferences|theme|Nordic-bluish-accent-standard-buttons"
    "org.gnome.desktop.wm.preferences|titlebar-font|MartianMono Nerd Font Bold 9"
    "org.gnome.desktop.interface|color-scheme|prefer-dark"
)

# Walks every file under etc/ (mirrors /etc exactly, any depth)
# calling _etc_file_action(src, dest) for each — the caller (setup.sh/reset.sh)
# defines that function to either install or remove the policy file.
_each_etc_file() {
    [[ -d "$DOTDIR/etc" ]] || return 0

    local file rel
    while IFS= read -r -d '' file; do
        rel="${file#"$DOTDIR"/}"
        _etc_file_action "$file" "/$rel"
    done < <(find "$DOTDIR/etc" -type f -print0)
}

# Walks every file under home/ (mirrors $HOME's structure exactly, any depth)
# calling _home_file_action(src, target) for each — the caller
# (setup.sh/reset.sh) defines that function to either create or remove the symlink.
_each_home_file() {
    [[ -d "$DOTDIR/home" ]] || return 0

    local file rel
    while IFS= read -r -d '' file; do
        rel="${file#"$DOTDIR"/home/}"
        _home_file_action "$file" "$HOME/$rel"
    done < <(find "$DOTDIR/home" -type f -print0)
}

# Walks each tool folder under scripts/ (e.g. scripts/wpm/) that has a matching
# <name>/<name>.sh entry point, calling _script_file_action(name, src) for each —
# the caller (setup.sh/reset.sh) defines that function to either link or unlink
# it from /usr/local/bin. Helper files (e.g. wpm-helper.sh) never match since
# the filename must equal the folder name.
_each_script_file() {
    [[ -d "$DOTDIR/scripts" ]] || return 0

    local dir name src
    for dir in "$DOTDIR/scripts/"*/; do
        name=$(basename "$dir")
        src="${dir}${name}.sh"
        [[ -f "$src" ]] || continue
        _script_file_action "$name" "$src"
    done
}
