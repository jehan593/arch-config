# ==============================================================================
# ARCH LINUX CUSTOM BASH CONFIGURATION (Nord Aesthetic)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. CORE SETUP & ENVIRONMENT
# ------------------------------------------------------------------------------
[[ $- != *i* ]] && return                

export EDITOR='vim'
export VISUAL='codium'
export MANROFFOPT="-c"
export PAGER='most'
export TERM=xterm-256color

command -v starship &>/dev/null && eval "$(starship init bash)" || PS1='[\u@\h \W]\$ '
command -v zoxide &>/dev/null && eval "$(zoxide init bash)"

fzf_history() {
    local command=$(history | tac | sed 's/^[ ]*[0-9]*[ ]*//' | awk '!visited[$0]++' | fzf --exact --height 40% --reverse --color="fg:#d8dee9,bg:#2e3440,hl:#81a1c1,fg+:#eceff4,bg+:#3b4252,hl+:#88c0d0")
    [[ -n "$command" ]] && READLINE_LINE="$command" && READLINE_POINT=${#command}
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
RST='\e[0m'

HEADER_LINE="${NORD_POLAR_4}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"

_print_header() {
    echo -e "\n${1}  ${NORD_SNOW_1}${2}${RST}"
    echo -e "${HEADER_LINE}"
}

_print_footer() {
    echo -e "${HEADER_LINE}\n"
}

_print_row() {
    printf "${NORD_POLAR_4}│${RST}  ${NORD_BLUE}%s${RST} %-12s ${NORD_SNOW_1}%s${RST}\n" "$1" "$2" "$3"
}

_run() {
    local label="$1"; shift
    if "$@" &>/dev/null; then
        _print_row "󰄬" "$label" "Done"
    else
        _print_row "󰅙" "$label" "Failed"
    fi
}

IDEAPAD_CONSERVATION="/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"

# ------------------------------------------------------------------------------
# 3. ALIASES
# ------------------------------------------------------------------------------
alias ..='cd ..'
alias ls='ls --color=auto'
alias la='ls -a --color=auto'
alias tree='tree -C'
alias ll='ls -l --color=auto'
alias lla='ls -al --color=auto'
alias grep='grep --color=auto'
command -v bat &>/dev/null && alias cat='bat'
alias clear='clear && sys'
alias reload='source ~/.bashrc && echo -e "${NORD_GREEN}󰬷  Profile Reloaded!${RST}"'
rr() { echo -e "${NORD_CYAN}󰮯  Elevating Last Command...${RST}"; sudo $(fc -ln -1); }
alias conf='vim ~/.bashrc'
alias confc='[[ -x $(command -v codium) ]] && (echo -e "${NORD_CYAN}󰨞  Opening Configs...${RST}" && codium ~/arch-config/) || echo -e "${NORD_RED}󰅙  VSCodium not found.${RST}"'
alias upall='_print_header "󰚰" "Full System Update" && yay -Syu --noconfirm && upf && wp'
alias up-mirrors='_print_header "󰈀" "Updating Mirrors" && sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist && sudo pacman -Syyu'
alias age='echo -e "${NORD_BLUE}󰃭  OS Age:${RST} $(( ($(date +%s) - $(stat -c %Y /lost+found 2>/dev/null || stat -c %Y /)) / 86400 )) days"'

# ------------------------------------------------------------------------------
# 4. SYSTEM & HARDWARE FUNCTIONS
# ------------------------------------------------------------------------------
sys() {
    local total_pkgs=$(pacman -Qq | wc -l)
    local aur_pkgs=$(pacman -Qm | wc -l)
    local chaotic_pkgs=$(pacman -Sl chaotic-aur 2>/dev/null | grep '\[installed\]' | wc -l)
    local repo_pkgs=$((total_pkgs - aur_pkgs - chaotic_pkgs))
    local pkg_string="${repo_pkgs} (core/extra) + ${chaotic_pkgs} (chaotic-aur) + ${aur_pkgs} (AUR)"
    local ker=$(uname -r | cut -d '-' -f1)
    local mem=$(free -h | awk '/^Mem:/ {print $3 " / " $2}')
    local uptime=$(uptime -p | sed 's/up //')
    local age=$(( ($(date +%s) - $(stat -c %Y /lost+found 2>/dev/null || stat -c %Y /)) / 86400 ))

    _print_header "${NORD_CYAN}󰣇${RST}" "Arch Linux"
    _print_row "󱑎" "Uptime" "$uptime"
    _print_row "󰟾" "Kernel" "$ker"
    _print_row "󰏖" "Packages" "$pkg_string"
    _print_row "󰍛" "Memory" "$mem"
    _print_row "󰃭" "OS Age" "$age days"

    if [[ -f "$IDEAPAD_CONSERVATION" ]]; then
        local status
        [[ $(< "$IDEAPAD_CONSERVATION") -eq 1 ]] && status="Conservation - ON" || status="Conservation - OFF"
        _print_row "󱊟" "Battery" "$status"
    fi
    _print_row "󰒍" "Shell" "Bash ${BASH_VERSION%%(*}"
    _print_footer
}

if [[ -f "$IDEAPAD_CONSERVATION" ]]; then
    batt-on() {
        echo 1 | sudo tee "$IDEAPAD_CONSERVATION" > /dev/null
        _print_header "${NORD_GREEN}󱊟${RST}" "Battery Conservation"
        _print_row "󰏔" "Status" "ENABLED (80%)"
        _print_footer
    }
    batt-off() {
        echo 0 | sudo tee "$IDEAPAD_CONSERVATION" > /dev/null
        _print_header "${NORD_RED}󱊟${RST}" "Battery Conservation"
        _print_row "󰏔" "Status" "DISABLED (100%)"
        _print_footer
    }
fi

# ------------------------------------------------------------------------------
# 5. PACKAGE MANAGEMENT
# ------------------------------------------------------------------------------
cleanup() {
    _print_header "${NORD_ORANGE}󰃨${RST}" "Cleaning System Cache"
    _run "Partial downloads" sudo rm -rf /var/cache/pacman/pkg/download-*
    _run "Partial files" sudo rm -f /var/cache/pacman/pkg/*.part
    _run "Yay cache" yay -Sc --noconfirm
    _run "Yay orphans" yay -Yc --noconfirm
    _run "Paccache keep 2" sudo paccache -rk2
    _run "Paccache uninstalled" sudo paccache -ruk0
    _run "Yay build cache" rm -rf ~/.cache/yay/*
    _print_row "󰋊" "Cache Size" "$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1)"
    _print_footer
}

cup() {
    process_updates() {
        local update_list="$1"; local cmd="$2"; local show_size="$3"
        formatted_list=$(echo "$update_list" | while read -r line; do
            pkg=$(echo "$line" | awk '{print $1}')
            version=$(echo "$line" | awk '{$1=""; print $0}' | xargs)
            if [ "$show_size" = "true" ]; then
                size_info=$($cmd -Si "$pkg" 2>/dev/null | grep "Download Size" | cut -d: -f2 | xargs)
                [[ -z "$size_info" ]] && size_info="0.00 B"
                printf "${NORD_GREEN}%-25s${RST} ${NORD_POLAR_4}│${RST} %-25s ${NORD_POLAR_4}│${RST} %10s\n" "$pkg" "$version" "$size_info"
            else
                printf "${NORD_GREEN}%-25s${RST} ${NORD_POLAR_4}│${RST} %-25s\n" "$pkg" "$version"
            fi
        done)
        echo "$formatted_list" | column -t -s "|"
        if [ "$show_size" = "true" ] && [ -n "$formatted_list" ]; then
            echo ""
            echo "$formatted_list" | awk -F'|' '{
                split($3, a, " "); val = a[1]; unit = a[2]
                if (unit == "KiB") { sum += (val / 1024) }
                else if (unit == "B") { sum += (val / 1048576) }
                else if (unit == "GiB") { sum += (val * 1024) }
                else { sum += val }
            } END { if (sum > 0) printf "\033[1;37m󰇚 Total Download: %.2f MiB\033[0m\n", sum }'
        fi
    }

    local all_sync=$(checkupdates 2>/dev/null)
    local chaotic_names=$(pacman -Sl chaotic-aur 2>/dev/null | awk '{print $2}')

    _print_header "${NORD_BLUE}󰏖${RST}" "core/extra"
    local official_updates
    [[ -z "$chaotic_names" ]] && official_updates="$all_sync" || official_updates=$(echo "$all_sync" | grep -vFwf <(echo "$chaotic_names"))
    [[ -z "$official_updates" ]] && echo -e "󰄬  up to date" || process_updates "$official_updates" "pacman" "true"

    _print_header "${NORD_CYAN}󰏖${RST}" "chaotic-aur"
    local chaotic_updates
    [[ -z "$chaotic_names" ]] && chaotic_updates="" || chaotic_updates=$(echo "$all_sync" | grep -Fwf <(echo "$chaotic_names"))
    [[ -z "$chaotic_updates" ]] && echo -e "󰄬  up to date" || process_updates "$chaotic_updates" "pacman" "true"

    _print_header "${NORD_MAGENTA}󰏖${RST}" "AUR"
    local aur_updates=$(yay -Qua 2>/dev/null)
    [[ -z "$aur_updates" ]] && echo -e "󰄬  up to date" || process_updates "$aur_updates" "yay" "false"
    echo ""
}

inst() {
    if [[ "$1" == "-refresh" ]]; then
        echo -e "${NORD_D_BLUE}󰒓  Refreshing package cache...${RST}"
        yay -Sl 2>/dev/null | awk '{print $1"/"$2}' > "$HOME/.cache/yay-pkg-list.cache"
        echo -e "${NORD_GREEN}󰄬  Cache updated.${RST}"
        inst
        return 0
    fi

    if [[ $# -gt 0 ]]; then
        _print_header "${NORD_GREEN}󰏖${RST}" "Installing Packages"
        yay -S "$@"
    else
        local cache="$HOME/.cache/yay-pkg-list.cache"
        if [[ ! -f "$cache" ]] || [[ -n $(find "$cache" -mmin +1440 2>/dev/null) ]]; then
            echo -e "${NORD_D_BLUE}󰒓  Refreshing package cache...${RST}"
            yay -Sl 2>/dev/null | awk '{print $1"/"$2}' > "$cache"
        fi
        [[ ! -s "$cache" ]] && return 1
        cat "$cache" | fzf --exact --multi \
            --preview-window=right:60%:hidden \
            --header "󰏖 CTRL-P: Toggle Preview | ENTER: Install | inst -refresh: Refresh Cache" \
            --bind 'ctrl-p:toggle-preview' \
            --preview '
                item={}; repo=${item%%/*}; pkg=${item#*/}
                if [ "$repo" = "aur" ]; then yay -Siai "$pkg" 2>/dev/null; else yay -Sii "$pkg"; fi | \
                awk "/^(Votes|Popularity)/ { stats = stats \"\033[1;33m\" \$0 \"\033[0m\n\" } !/^(Votes|Popularity)/ { body = body \$0 \"\n\" } END { printf \"%s%s\", stats, body }"
            ' | xargs -ro yay -S
    fi
}

uninst() {
    if [[ $# -gt 0 ]]; then
        _print_header "${NORD_RED}󰆑${RST}" "Uninstalling Packages"
        sudo pacman -Rns "$@"
    else
        {
            pacman -Qqn | grep -vFwf <(pacman -Sl chaotic-aur 2>/dev/null | awk '{print $2}') | awk '{print "core/" $1}'
            pacman -Sl chaotic-aur 2>/dev/null | grep '\[installed\]' | awk '{print "chaotic-aur/" $2}'
            pacman -Qm | awk '{print "aur/" $1}'
        } | fzf --exact --multi --preview-window=right:60% --header "󰆑 Select apps to UNINSTALL" \
            --preview 'echo {} | awk -F/ "{print \$2}" | xargs yay -Qi 2>/dev/null | awk "/^(Install Date|Installed Size)/ { stats = stats \"\033[1;31m\" \$0 \"\033[0m\n\" } !/^(Install Date|Installed Size)/ { body = body \$0 \"\n\" } END { printf \"%s%s\", stats, body }"' \
            | awk -F/ '{print $2}' | xargs -ro sudo pacman -Rns
    fi
}

lpa() {
    local selection=$({
        pacman -Qqn | grep -vFwf <(pacman -Sl chaotic-aur 2>/dev/null | awk '{print $2}') | awk '{print "core/" $1}'
        pacman -Sl chaotic-aur 2>/dev/null | grep '\[installed\]' | awk '{print "chaotic-aur/" $2}'
        pacman -Qm | awk '{print "aur/" $1}'
    } | fzf --exact --header "ENTER: Info | CTRL-C: Quit" --preview-window=right:60% \
        --preview 'echo {} | awk -F/ "{print \$2}" | xargs yay -Qi 2>/dev/null | awk "/^(Required By|Depends On)/ { print \"\033[1;35m\" \$0 \"\033[0m\" } !/^(Required By|Depends On)/ { print }"')

    [[ -z "$selection" ]] && return 0
    local pkg="${selection#*/}"
    yay -Qi "$pkg"
}


# ------------------------------------------------------------------------------
# 6. NETWORK & CONNECTIVITY
# ------------------------------------------------------------------------------
cdns-on() {
    _print_header "${NORD_CYAN}󰛳${RST}" "DNS Status"
    _run "Restore config" sudo cp /etc/systemd/resolved.conf.bak /etc/systemd/resolved.conf
    _run "Restart resolved" sudo systemctl restart systemd-resolved
    _print_row "󰈀" "Custom DNS" "ENABLED"
    _print_row "󰒄" "Provider" "NextDNS"
    _print_footer
}

cdns-off() {
    _print_header "${NORD_RED}󰛳${RST}" "DNS Status"
    _run "Backup config" sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak
    _run "Clear config" sudo truncate -s 0 /etc/systemd/resolved.conf
    _run "Restart resolved" sudo systemctl restart systemd-resolved
    _print_row "󰈀" "Custom DNS" "DISABLED"
    _print_row "󰒄" "Provider" "ISP Default"
    _print_footer
}

termux() {
    local end_ip=$1; local user="u0_a310"; local port="8022"; local base_ip="192.168.8."
    if [[ -z "$end_ip" ]]; then
        _print_header "${NORD_RED}󰄜${RST}" "Termux SSH"
        _print_row "󰋖" "Usage" "termux <last_octet_or_full_ip>"
        _print_footer
        return 1
    fi
    local target_ip
    [[ "$end_ip" != *"."* ]] && target_ip="${base_ip}${end_ip}" || target_ip="$end_ip"
    _print_header "${NORD_CYAN}󰄜${RST}" "Termux SSH Connection"
    _print_row "󰩟" "Target" "$target_ip:$port"
    _print_row "󰀄" "User" "$user"
    _print_footer
    ssh -p "$port" "$user@$target_ip"
}

upf() {
    local URL="https://raw.githubusercontent.com/yokoffing/Betterfox/main/user.js"
    local FF_DIR="$HOME/.config/mozilla/firefox"
    local TEMP_FILE="/tmp/betterfox_user.js"
    local OVERRIDES="$HOME/arch-config/.config/firefox/overrides.js"
    _print_header "${NORD_ORANGE}󰈹${RST}" "Firefox Tweaks"
    if ! curl -fsSL "$URL" -o "$TEMP_FILE" &>/dev/null; then
        _print_row "󰅙" "Error" "Download Failed"
        _print_footer; return 1
    fi
    _print_row "󰄬" "Download" "Betterfox fetched"
    if [[ -f "$OVERRIDES" ]]; then
        cat "$OVERRIDES" >> "$TEMP_FILE"
        _print_row "󰄬" "Overrides" "Applied from overrides.js"
    else
        _print_row "󰀦" "Overrides" "No overrides file found, skipping"
    fi
    local found=false
    while IFS= read -r times_file; do
        local profile_path=$(dirname "$times_file")
        cp "$TEMP_FILE" "$profile_path/user.js"
        _print_row "󰄬" "Applied" "$(basename "$profile_path")"
        found=true
    done < <(find "$FF_DIR" -maxdepth 2 -mindepth 2 -name "times.json")
    rm "$TEMP_FILE"
    [[ "$found" = false ]] && _print_row "󰅙" "Error" "No Profiles Found"
    _print_footer
}

upc() {
    _print_header "${NORD_CYAN}󰚰${RST}" "Config Update"
    if git -C "$HOME/arch-config" pull --rebase --autostash &>/dev/null; then
        _print_row "󰊢" "Status" "Configs up to date!"
        _print_footer
        echo -e "${NORD_GREEN}󰬷  Sourcing updated profile...${RST}"
        source ~/.bashrc
    else
        _print_row "󰅙" "Status" "Update Failed"
        _print_footer
        return 1
    fi
}

upp() {
    local choice=$(printf "  All\n  core/extra\n  chaotic-aur\n  AUR" | \
        fzf --exact --header "Upgrade Packages :" --height=7 --layout=reverse --border=rounded \
            --color="bg:#2E3440,bg+:#3B4252,border:#88C0D0,fg:#D8DEE9,fg+:#ECEFF4,hl:#88C0D0,hl+:#88C0D0" \
            --no-info --no-sort --no-input)

    [[ -z "$choice" ]] && return 0
    echo ""

    case "$choice" in
        *"All"*)
            _print_header "${NORD_CYAN}󰑮${RST}" "Upgrading Packages | All"
            yay -Syu --noconfirm
            ;;
        *"core/extra"*)
            _print_header "${NORD_BLUE}󰊠${RST}" "Upgrading Packages | core/extra "
            local chaotic=$(pacman -Sl chaotic-aur 2>/dev/null | awk '{print $2}' | paste -sd,)
            sudo pacman -Syu $( [[ -n "$chaotic" ]] && echo "--ignore $chaotic" ) --noconfirm
            ;;
        *"chaotic-aur"*)
            _print_header "${NORD_ORANGE}󱓞${RST}" "Upgrading Packages | chaotic-aur"
            local updates=$(yay -Qu 2>/dev/null | grep -Fwf <(pacman -Sl chaotic-aur 2>/dev/null | awk '{print $2}'))
            if [[ -z "$updates" ]]; then
                _print_row "󰄬" "Status" "up to date"
            else
                _print_row "󰚰" "Updates" "Found $(echo "$updates" | wc -l) package(s)"
                echo "$updates" | awk '{printf "│  %s\n", $0}'
                echo ""
                sudo pacman -S $(echo "$updates" | awk '{print $1}') --noconfirm
            fi
            ;;
        *"AUR"*)
            _print_header "${NORD_MAGENTA}󰀵${RST}" "Upgrading Packages | AUR"
            yay -Sua --noconfirm
            ;;
    esac
    _print_footer
}

# ------------------------------------------------------------------------------
# 7. PRODUCTIVITY TOOLS
# ------------------------------------------------------------------------------


open() { echo -e "${NORD_CYAN}󰝰  Opening...${RST}"; xdg-open "${1:-.}" >/dev/null 2>&1; }
cd() { if [[ "$1" == "--silent" ]]; then builtin cd "$2"; else builtin cd "$@" && ls -a --color=auto; fi; }
z() { if command -v __zoxide_z &>/dev/null; then __zoxide_z "$@" && ls -a --color=auto; else builtin cd "$@"; fi; }

ff() {
    local search_path="${1:-/}"
    if [[ ! -d "$search_path" ]]; then
        echo -e "${NORD_RED}󱞣  Path not found: $search_path${RST}"
        return 1
    fi

    local selection=$(find "$search_path" 2>/dev/null | fzf --exact \
        --layout=reverse \
        --height=40% \
        --header="󰍉 Searching: $search_path")

    [[ -z "$selection" ]] && return 0

    local quoted="\"$selection\""
    echo -n "$quoted" | xclip -selection clipboard
    echo -e "${NORD_CYAN}󰅍  Copied:${RST} ${NORD_SNOW_1}$quoted${RST}"
}

wp() {
    local WALLPAPERS_DIR="$HOME/Pictures/config-wallpapers"
    if [[ ! -d "$WALLPAPERS_DIR" ]]; then
        _print_header "${NORD_RED}󰋊${RST}" "Wallpapers"
        _print_row "󰅙" "Error" "Wallpapers directory not found"
        _print_footer; return 1
    fi
    _print_header "${NORD_CYAN}󰋊${RST}" "Wallpapers"

    local changes=$(git -C "$WALLPAPERS_DIR" status --porcelain 2>/dev/null)
    if [[ -n "$changes" ]]; then
        _print_row "󰊢" "Local" "Uncommitted changes found"
        git -C "$WALLPAPERS_DIR" add -A &>/dev/null
        git -C "$WALLPAPERS_DIR" commit -m "sync: local wallpaper changes" &>/dev/null \
            && _print_row "󰄬" "Commit" "Changes committed" \
            || _print_row "󰅙" "Commit" "Failed to commit"
    fi

    if git -C "$WALLPAPERS_DIR" pull --rebase --autostash &>/dev/null; then
        _print_row "󰄬" "Pull" "Up to date"
    else
        _print_row "󰅙" "Pull" "Pull failed"
    fi

    if git -C "$WALLPAPERS_DIR" push &>/dev/null; then
        _print_row "󰄬" "Push" "Synced to GitHub"
    else
        _print_row "󰅙" "Push" "Nothing to push or push failed"
    fi

    _print_footer
}

# ------------------------------------------------------------------------------
# 8. MISCELLANEOUS & HELP
# ------------------------------------------------------------------------------
pirith() {
    local DIR="$HOME/Music/pirith"
    [[ -d "$DIR" ]] || { echo -e "${NORD_RED}󰅙  Directory not found: $DIR${RST}"; return 1; }
    _print_header "${NORD_CYAN}󰎆${RST}" "Pirith Player"
    local file=$(ls "$DIR"/*.mp3 2>/dev/null | fzf --prompt="󰎆 Select: " --header "󰪐  Select to Play")
    if [[ -n "$file" ]]; then
        _print_row "󰝚" "Playing" "$(basename "$file")"
        _print_footer; mpv "$file"
    fi
}

info() {
    _print_header "${NORD_CYAN}󱈄${RST}" "Custom Shell Commands"
    printf "${NORD_BLUE}%-10s${RST}  ${NORD_SNOW_1}%s${RST}\n" "󰒍 System"   "sys, age, reload, conf, confc"
    printf "${NORD_BLUE}%-10s${RST}  ${NORD_SNOW_1}%s${RST}\n" "󰏖 Packages" "upp, upall, cup, inst, uninst, lpa, cleanup"
    [[ -f "$IDEAPAD_CONSERVATION" ]] && printf "${NORD_BLUE}%-10s${RST}  ${NORD_SNOW_1}%s${RST}\n" "󱊟 Hardware" "batt-on, batt-off"
    printf "${NORD_BLUE}%-10s${RST}  ${NORD_SNOW_1}%s${RST}\n" "󰛳 Network"  "cdns-(on/off), warp, wg-socks, termux"
    printf "${NORD_BLUE}%-10s${RST}  ${NORD_SNOW_1}%s${RST}\n" " Utils"    "rr, upf, upc, pirith, open, ff, wp"
    printf "${NORD_BLUE}%-10s${RST}  ${NORD_SNOW_1}%s${RST}\n" " Keybinds" "CTRL+H: history"
    _print_footer
}

# Run system info on startup
sys
