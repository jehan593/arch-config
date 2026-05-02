# ==============================================================================
# ARCH LINUX CUSTOM BASH CONFIGURATION (Nord Aesthetic)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. CORE SETUP & ENVIRONMENT
# ------------------------------------------------------------------------------
[[ $- != *i* ]] && return

export EDITOR='vim'
export VISUAL='zeditor'
export MANROFFOPT="-c"
export PAGER='most'
export TERM=xterm-256color
export HISTSIZE=-1
export HISTFILESIZE=-1
export PATH="$HOME/.local/bin:$PATH"

export FZF_DEFAULT_OPTS="
    --exact
    --cycle
    --layout=reverse
    --border=rounded
    --color=fg:#d8dee9,bg:#2e3440,hl:#81a1c1,fg+:#eceff4,bg+:#3b4252,hl+:#88c0d0,border:#88c0d0
    --bind=ctrl-p:toggle-preview
"

command -v starship &>/dev/null && eval "$(starship init bash)" || PS1='[\u@\h \W]\$ '
command -v zoxide &>/dev/null && eval "$(zoxide init bash)"

fzf_history() {
    local histfile="${HISTFILE:-$HOME/.bash_history}"
    history -a
    local output
    output=$(tac "$histfile" | grep -v '^#[0-9]*$' | awk '!visited[$0]++' | fzf \
        --height=40% --no-border \
        -m \
        --header='(Ctrl+D: delete, Enter: insert)' \
        --expect=ctrl-d \
        --prompt="  History > ")
    local key selections
    key=$(echo "$output" | head -n1)
    selections=$(echo "$output" | tail -n+2)
    [[ -z "$selections" ]] && return 0
    if [[ "$key" == "ctrl-d" ]]; then
        local tmpfile patfile
        tmpfile=$(mktemp)
        patfile=$(mktemp)
        cp "$histfile" "$tmpfile"
        echo "$selections" | grep -v '^$' > "$patfile"
        awk '
            NR==FNR { patterns[$0]=1; next }
            /^#[0-9]+$/ { pending=$0; next }
            $0 in patterns { pending=""; next }
            { if (pending) print pending; pending=""; print }
            END { if (pending) print pending }
        ' "$patfile" "$tmpfile" > "$tmpfile.new" && mv "$tmpfile.new" "$tmpfile"
        rm -f "$patfile"
        cp "$tmpfile" "$histfile"
        rm -f "$tmpfile"
        history -c
        history -r
    else
        local cmd=""
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            [[ -z "$cmd" ]] && cmd="$line" || cmd="$cmd & $line"
        done <<< "$selections"
        READLINE_LINE="$cmd"
        READLINE_POINT=${#cmd}
    fi
}
bind -x '"\C-h": fzf_history'

# ------------------------------------------------------------------------------
# 2. DEFINITIONS (Nord Theme Palette)
# ------------------------------------------------------------------------------
NORD_POLAR_4='\e[38;2;76;86;106m'
NORD_SNOW_1='\e[38;2;216;222;233m'
NORD_CYAN='\e[38;2;143;188;187m'
NORD_BLUE='\e[38;2;136;192;208m'
NORD_D_BLUE='\e[38;2;129;161;193m'
NORD_GREEN='\e[38;2;163;190;140m'
NORD_RED='\e[38;2;191;97;106m'
NORD_ORANGE='\e[38;2;208;135;112m'
NORD_MAGENTA='\e[38;2;180;142;173m'
NORD_YELLOW='\e[38;2;235;203;139m'
RST='\e[0m'

IDEAPAD_CONSERVATION="/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"

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

_info_group() {
    echo -e "\n ${NORD_YELLOW}${1}  ${2}${RST}"
}

_info_cmd() {
    printf "    ${NORD_CYAN}%-14s${RST}${NORD_POLAR_4} 󰁔 ${RST}${NORD_SNOW_1}%s${RST}\n" "$1" "$2"
}

# ------------------------------------------------------------------------------
# 3. ALIASES
# ------------------------------------------------------------------------------
alias ..='cd ..'
alias ls='ls --color=auto -F'
alias la='ls -aF --color=auto'
alias tree='tree -C'
alias ll='ls -lhF --color=auto'
alias lla='ls -alhF --color=auto'
alias grep='grep --color=auto'
alias clear='clear && sys'
alias reload='source ~/.bashrc && echo -e "${NORD_GREEN}󰑓  Profile reloaded.${RST}"'
rr() { echo -e "${NORD_CYAN}󰮯  Elevating last command...${RST}"; sudo $(fc -ln -1); }
alias conf='[[ -x $(command -v zeditor) ]] && (echo -e "${NORD_CYAN}󱃖  Opening configs...${RST}" && zeditor ~/arch-config/) || echo -e "${NORD_RED}󰅙  zed not found.${RST}"'
alias age='echo -e "${NORD_BLUE}󰃭  OS Age:${RST} $(( ($(date +%s) - $(stat -c %Y /lost+found 2>/dev/null || stat -c %Y /)) / 86400 )) days"'

# ------------------------------------------------------------------------------
# 4. SYSTEM & HARDWARE FUNCTIONS
# ------------------------------------------------------------------------------
sys() {
    local total_pkgs=$(pacman -Qq | wc -l)
    local ker=$(uname -r | cut -d '-' -f1)
    local mem=$(free -h | awk '/^Mem:/ {print $3 " / " $2}')
    local uptime=$(uptime -p | sed 's/up //')
    local age=$(( ($(date +%s) - $(stat -c %Y /lost+found 2>/dev/null || stat -c %Y /)) / 86400 ))

    local f="  ${NORD_BLUE}%s${RST}  %-12s ${NORD_SNOW_1}%s${RST}\n"

    _print_header "󰣇" "Arch Linux"
    printf "$f" "󱑎" "Uptime"   "$uptime"
    printf "$f" "󰟾" "Kernel"   "$ker"
    printf "$f" "󰏖" "Packages" "$total_pkgs"
    printf "$f" "󰍛" "Memory"   "$mem"
    printf "$f" "󰃭" "OS Age"   "$age days"

    if [[ -f "$IDEAPAD_CONSERVATION" ]]; then
        local status
        [[ $(< "$IDEAPAD_CONSERVATION") -eq 1 ]] && status="Conservation - ON" || status="Conservation - OFF"
        printf "$f" "󱊟" "Battery" "$status"
    fi
    printf "$f" "󰒍" "Shell" "Bash ${BASH_VERSION%%(*}"

    echo ""
}

if [[ -f "$IDEAPAD_CONSERVATION" ]]; then
    batt-on() {
        echo 1 | sudo tee "$IDEAPAD_CONSERVATION" > /dev/null
        _print_header "󱊟" "Battery Conservation"
        _print_status "󰄬" "Conservation mode enabled (80% limit)"
        echo ""
    }
    batt-off() {
        echo 0 | sudo tee "$IDEAPAD_CONSERVATION" > /dev/null
        _print_header "󱊟" "Battery Conservation"
        _print_status "󰋼" "Conservation mode disabled (100% limit)"
        echo ""
    }
fi

# ------------------------------------------------------------------------------
# 5. PACKAGE MANAGEMENT
# ------------------------------------------------------------------------------
cleanup() {
    _print_header "󰃨" "Cleaning System Cache"

    sudo rm -rf /var/cache/pacman/pkg/download-*
    _print_status "$([ $? -eq 0 ] && echo 󰄬 || echo 󰅙)" "Partial downloads"

    rm -f ~/.bash_history-*.tmp
    _print_status "$([ $? -eq 0 ] && echo 󰄬 || echo 󰅙)" "Bash history temp"

    rm -f ~/.cache/yay-pkg-list.cache
    _print_status "$([ $? -eq 0 ] && echo 󰄬 || echo 󰅙)" "Pkg list cache"

    yay -Sc --noconfirm
    _print_status "$([ $? -eq 0 ] && echo 󰄬 || echo 󰅙)" "Yay cache"

    yay -Yc --noconfirm
    _print_status "$([ $? -eq 0 ] && echo 󰄬 || echo 󰅙)" "Yay orphans"

    sudo paccache -rk2
    _print_status "$([ $? -eq 0 ] && echo 󰄬 || echo 󰅙)" "Paccache keep 2"

    sudo paccache -ruk0
    _print_status "$([ $? -eq 0 ] && echo 󰄬 || echo 󰅙)" "Paccache uninstalled"

    rm -rf ~/.cache/yay/*
    _print_status "$([ $? -eq 0 ] && echo 󰄬 || echo 󰅙)" "Yay build cache"

    _print_status "󰋊" "Cache: $(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1)"
    echo ""
}

cup() {
    sudo pacman -Sy --noconfirm &>/dev/null
    local any=false
    local all_updates=$(checkupdates 2>/dev/null)
    local aur_updates=$(yay -Qua 2>/dev/null)
    local repos=$(pacman -Sl 2>/dev/null | awk '{print $1}' | sort -u)

    while IFS= read -r repo; do
        local updates=$(echo "$all_updates" | grep -Fwf <(pacman -Sl "$repo" 2>/dev/null | awk '{print $2}'))
        [[ -z "$updates" ]] && continue
        any=true
        _print_header "󰏖" "$repo"
        echo "$updates" | while read -r line; do
            local pkg=$(echo "$line" | awk '{print $1}')
            local ver=$(echo "$line" | awk '{$1=""; print $0}' | xargs)
            printf "  ${NORD_GREEN}%-40s${RST} ${NORD_POLAR_4}%s${RST}\n" "$pkg" "$ver"
        done
        echo ""
    done <<< "$repos"

    if [[ -n "$aur_updates" ]]; then
        any=true
        _print_header "󰏖" "AUR"
        echo "$aur_updates" | while read -r line; do
            local pkg=$(echo "$line" | awk '{print $1}')
            local ver=$(echo "$line" | awk '{$1=""; print $0}' | xargs)
            printf "  ${NORD_GREEN}%-40s${RST} ${NORD_SNOW_1}%s${RST}\n" "$pkg" "$ver"
        done
        echo ""
    fi

    [[ "$any" == false ]] && _print_status "󰄬" "All packages up to date"
    echo ""
}

inst() {
    if [[ "$1" == "-refresh" ]]; then
        echo -e "${NORD_D_BLUE}󰒓  Refreshing package cache...${RST}"
        yay -Sl 2>/dev/null | awk '{print $1"/"$2}' > "$HOME/.cache/yay-pkg-list.cache"
        _print_status "󰄬" "Cache updated."
        inst
        return 0
    fi
    if [[ $# -gt 0 ]]; then
        _print_header "󰏖" "Installing Packages"
        yay -S "$@"
        history -s "yay -S $*"
        history -a
    else
        local cache="$HOME/.cache/yay-pkg-list.cache"
        if [[ ! -f "$cache" ]] || [[ -n $(find "$cache" -mmin +10080 2>/dev/null) ]]; then
            echo -e "${NORD_D_BLUE}󰒓  Refreshing package cache...${RST}"
            yay -Sl 2>/dev/null | awk '{print $1"/"$2}' > "$cache"
        fi
        [[ ! -s "$cache" ]] && return 1
        local selected
        selected=$(cat "$cache" | fzf --multi \
            --preview-window=right:60%:hidden \
            --header "󰏖 CTRL-P: Preview" \
            --preview '
                item={}; repo=${item%%/*}; pkg=${item#*/}
                if [ "$repo" = "aur" ]; then yay -Siai "$pkg" 2>/dev/null; else yay -Sii "$pkg"; fi | \
                awk "/^(Votes|Popularity)/ { stats = stats \"\033[1;33m\" \$0 \"\033[0m\n\" } !/^(Votes|Popularity)/ { body = body \$0 \"\n\" } END { printf \"%s%s\", stats, body }"
            ')
        [[ -z "$selected" ]] && return 0
        local pkgs
        pkgs=$(echo "$selected" | awk -F/ '{print $2}' | paste -sd' ')
        history -s "yay -S ${pkgs}"
        history -a
        yay -S --noconfirm $pkgs
    fi
}

_pkg_list() {
    local explicit=$(pacman -Qeq)
    {
        local repos=$(pacman -Sl 2>/dev/null | awk '{print $1}' | sort -u)
        while read -r repo; do
            pacman -Sl "$repo" 2>/dev/null | grep '\[installed\]' | awk -v r="$repo" '{print r"/"$2}'
        done <<< "$repos"
        pacman -Qm | awk '{print "aur/"$1}'
    } | while read -r line; do
        local pkg="${line#*/}"
        if echo "$explicit" | grep -qx "$pkg"; then
            echo "  $line"
        else
            echo " $line"
        fi
    done
}

uinst() {
    if [[ $# -gt 0 ]]; then
        _print_header "󰆑" "Uninstalling Packages"
        sudo pacman -Rns "$@"
        history -s "sudo pacman -Rns $*"
        history -a
    else
        local selected
        selected=$(_pkg_list | fzf --multi \
            --preview-window=right:50%:hidden \
            --header " Initially Installed | CTRL-P: Preview" \
            --preview 'echo {} | awk -F/ "{print \$2}" | xargs yay -Qi 2>/dev/null | awk "/^(Install Date|Installed Size)/ { stats = stats \"\033[1;31m\" \$0 \"\033[0m\n\" } !/^(Install Date|Installed Size)/ { body = body \$0 \"\n\" } END { printf \"%s%s\", stats, body }"')
        [[ -z "$selected" ]] && return 0
        local pkgs
        pkgs=$(echo "$selected" | awk '{print $NF}' | awk -F/ '{print $2}' | paste -sd' ')
        history -s "sudo pacman -Rns ${pkgs}"
        history -a
        sudo pacman -Rns $pkgs
    fi
}

# ------------------------------------------------------------------------------
# 6. NETWORK & CONNECTIVITY
# ------------------------------------------------------------------------------
cdns-on() {
    _print_header "󰛳" "DNS Status"

    sudo cp /etc/systemd/resolved.conf.bak /etc/systemd/resolved.conf
    _print_status "$([ $? -eq 0 ] && echo 󰄬 || echo 󰅙)" "Config restored"

    sudo systemctl restart systemd-resolved
    _print_status "$([ $? -eq 0 ] && echo 󰄬 || echo 󰅙)" "systemd-resolved restarted"

    _print_status "󰄬" "Custom DNS enabled — NextDNS"
    echo ""
}

cdns-off() {
    _print_header "󰛳" "DNS Status"

    sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak
    _print_status "$([ $? -eq 0 ] && echo 󰄬 || echo 󰅙)" "Config backed up"

    sudo truncate -s 0 /etc/systemd/resolved.conf
    _print_status "$([ $? -eq 0 ] && echo 󰄬 || echo 󰅙)" "Config cleared"

    sudo systemctl restart systemd-resolved
    _print_status "$([ $? -eq 0 ] && echo 󰄬 || echo 󰅙)" "systemd-resolved restarted"

    _print_status "󰋼" "Custom DNS disabled — ISP default"
    echo ""
}

upf() {
    local URL="https://raw.githubusercontent.com/yokoffing/Betterfox/main/user.js"
    local FF_DIR="$HOME/.config/mozilla/firefox"
    local TEMP_FILE="/tmp/betterfox_user.js"
    local OVERRIDES="$HOME/arch-config/.config/firefox/overrides.js"

    _print_header "󰈹" "Firefox Tweaks"

    if ! curl -fsSL "$URL" -o "$TEMP_FILE" &>/dev/null; then
        _print_status "󰅙" "Download failed"
        echo ""; return 1
    fi
    _print_status "󰄬" "Betterfox fetched"

    if [[ -f "$OVERRIDES" ]]; then
        cat "$OVERRIDES" >> "$TEMP_FILE"
        _print_status "󰄬" "Overrides applied"
    else
        _print_status "󰀦" "No overrides file found, skipping"
    fi

    local found=false
    while IFS= read -r times_file; do
        local profile_path=$(dirname "$times_file")
        cp "$TEMP_FILE" "$profile_path/user.js"
        _print_status "󰄬" "$(basename "$profile_path")"
        found=true
    done < <(find "$FF_DIR" -maxdepth 2 -mindepth 2 -name "times.json")

    rm "$TEMP_FILE"
    [[ "$found" = false ]] && _print_status "󰅙" "No profiles found"
    echo ""
}

upc() {
    _print_header "󰚰" "Config Update"
    git -C "$HOME/arch-config" pull --rebase --autostash
    if [[ $? -eq 0 ]]; then
        _print_status "󰄬" "Configs up to date"
        echo ""
        echo -e "${NORD_GREEN}󰑓  Sourcing updated profile...${RST}"
        source ~/.bashrc
    else
        _print_status "󰅙" "Update failed"
        echo ""
        return 1
    fi
}

upall() {
    yay -Syu --noconfirm && upf && wp && upc
}

upp() {
    local repos=$(pacman -Sl 2>/dev/null | awk '{print $1}' | sort -u | sed 's/^/  /')
    local choice=$(printf "  All\n%s\n  AUR" "$repos" | \
        fzf --header "Upgrade Packages:" --height=12 --no-info --no-sort --no-input)
    [[ -z "$choice" ]] && return 0
    local label=$(echo "$choice" | xargs)
    echo ""

    _print_header "󰑮" "Upgrading — $label"
    case "$label" in
        All) yay -Syu --noconfirm ;;
        AUR) yay -Sua --noconfirm ;;
        *)
            sudo pacman -Sy --noconfirm &>/dev/null
            local repo_pkgs=$(pacman -Sl "$label" 2>/dev/null | awk '{print $2}')
            local to_upgrade=$(checkupdates 2>/dev/null | awk '{print $1}' | grep -Fwf <(echo "$repo_pkgs"))
            if [[ -z "$to_upgrade" ]]; then
                _print_status "󰄬" "Up to date"
            else
                sudo pacman -S --noconfirm $to_upgrade
            fi
            ;;
    esac
    echo ""
}

up-mirrors() {
    _print_header "󰈀" "Updating Mirrors"
    sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
    sudo pacman -Syyu
    _print_status "$([ $? -eq 0 ] && echo 󰄬 || echo 󰅙)" "Mirrors updated"
    echo ""
}

# ------------------------------------------------------------------------------
# 7. PRODUCTIVITY TOOLS
# ------------------------------------------------------------------------------
exp() {
    local target="${1:-.}"
    if [[ -d "$target" ]]; then
        xdg-open "$target" >/dev/null 2>&1
    else
        xdg-open "$(dirname "$target")" >/dev/null 2>&1
    fi
}

open() {
    local target="${1:-.}"
    echo -e "${NORD_CYAN}󰝰  Opening...${RST}"
    xdg-open "$target" >/dev/null 2>&1
}

sz() {
    local target="${1:-.}"
    if [[ ! -e "$target" ]]; then
        echo -e "${NORD_RED}󱞣  Not found: $target${RST}"
        return 1
    fi
    local size=$(du -sh "$target" 2>/dev/null | cut -f1)
    _print_header "󰋊" "Size"
    _print_status "󰉋" "$target  →  $size"
    echo ""
}

cd() { if [[ "$1" == "--silent" ]]; then builtin cd "$2"; else builtin cd "$@" && ls -a --color=auto; fi; }
z() { if command -v __zoxide_z &>/dev/null; then __zoxide_z "$@" && ls -a --color=auto; else builtin cd "$@"; fi; }

ff() {
    local search_path="${1:-/}"
    if [[ ! -d "$search_path" ]]; then
        echo -e "${NORD_RED}󱞣  Path not found: $search_path${RST}"
        return 1
    fi

    local selection=$(find "$search_path" 2>/dev/null | fzf \
        --height=40% \
        --no-border \
        --header="󰍉 Searching: $search_path")

    [[ -z "$selection" ]] && return 0

    local quoted="\"$selection\""
    echo -n "$quoted" | xclip -selection clipboard
    echo -e "${NORD_CYAN}󰅍  Copied:${RST} ${NORD_SNOW_1}$quoted${RST}"
}

wp() {
    local WALLPAPERS_DIR="$HOME/Pictures/config-wallpapers"
    if [[ ! -d "$WALLPAPERS_DIR" ]]; then
        _print_header "󰹧" "Wallpaper Sync"
        _print_status "󰅙" "Wallpapers directory not found"
        echo ""; return 1
    fi

    _print_header "󰹧" "Wallpaper Sync"

    local changes=$(git -C "$WALLPAPERS_DIR" status --porcelain 2>/dev/null)
    if [[ -n "$changes" ]]; then
        _print_status "󰊢" "Local changes detected"
        git -C "$WALLPAPERS_DIR" add -A
        git -C "$WALLPAPERS_DIR" commit -m "sync: local wallpaper changes"
        _print_status "$([ $? -eq 0 ] && echo 󰄬 || echo 󰅙)" "Committed"
    fi

    git -C "$WALLPAPERS_DIR" pull --rebase --autostash
    _print_status "$([ $? -eq 0 ] && echo 󰄬 || echo 󰅙)" "Pull up to date"

    git -C "$WALLPAPERS_DIR" push
    _print_status "$([ $? -eq 0 ] && echo 󰄬 || echo 󰅙)" "Remote updated"

    echo ""
}

# ------------------------------------------------------------------------------
# 8. MISCELLANEOUS & HELP
# ------------------------------------------------------------------------------
info() {
    _print_header "󱈄" "Shell Environment Toolkit"

    _info_group "󰣇" "System"
    _info_cmd "sys"         "Show system info (uptime, kernel, memory, packages)"
    _info_cmd "age"         "Show OS installation age in days"
    _info_cmd "reload"      "Re-source ~/.bashrc"
    _info_cmd "conf"        "Open arch-config in Zed"
    _info_cmd "rr"          "Re-run last command with sudo"

    _info_group "󰏖" "Packages"
    _info_cmd "inst"        "Install packages (fzf picker or direct name)"
    _info_cmd "uinst"       "Uninstall packages (fzf picker or direct name)"
    _info_cmd "upp"         "Upgrade packages (fzf: All / per repo)"
    _info_cmd "cup"         "Check available updates across all repos"
    _info_cmd "cleanup"     "Clear package caches and orphaned build files"
    _info_cmd "up-mirrors"  "Refresh mirrorlist with reflector and sync"

    _info_group "󰚰" "Updates"
    _info_cmd "upall"       "Full update: packages + Firefox + wallpapers + configs"
    _info_cmd "upc"         "Pull latest arch-config from GitHub and reload"
    _info_cmd "upf"         "Fetch Betterfox user.js and apply to Firefox profiles"
    _info_cmd "wp"          "Sync wallpapers repo (commit, pull, push)"

    if [[ -f "$IDEAPAD_CONSERVATION" ]]; then
        _info_group "󱊟" "Battery"
        _info_cmd "batt-on"     "Enable conservation mode (charge limit 80%)"
        _info_cmd "batt-off"    "Disable conservation mode (charge to 100%)"
    fi

    _info_group "󰛳" "Network"
    _info_cmd "cdns-on"     "Enable custom DNS (NextDNS via systemd-resolved)"
    _info_cmd "cdns-off"    "Disable custom DNS, restore ISP default"
    _info_cmd "wg-socks"    "Manage WireGuard SOCKS5 proxy"

    _info_group "󰓇" "Files"
    _info_cmd "exp [path]"  "Open path in file manager (defaults to .)"
    _info_cmd "open [path]" "Open file/URL with default app"
    _info_cmd "ff [path]"   "fzf file finder, copies selection to clipboard"
    _info_cmd "sz [path]"   "Show size of file or directory"

    _info_group "󰉋" "Navigation"
    _info_cmd "z [query]"   "Jump to frecent directory (zoxide) + auto-ls"
    _info_cmd "ll"          "Long list with human-readable sizes"
    _info_cmd "la"          "List all including hidden files"
    _info_cmd "lla"         "Long list all including hidden files"
    _info_cmd "bat"         "better cat with syntax highlighting"

    _info_group "󰌌" "Keybinds"
    _info_cmd "Ctrl+H"      "fzf history picker (Ctrl+D to delete entry)"

    echo ""
}

# Run system info on startup
sys
echo -e "${NORD_YELLOW}󰋼  Type 'info' to see custom utilities${RST}\n"