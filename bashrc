# ==============================================================================
# ARCH LINUX CUSTOM BASH CONFIGURATION
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. CORE SETUP & ENVIRONMENT
# ------------------------------------------------------------------------------
[[ $- != *i* ]] && return                # Interactive check

export EDITOR='vim'
export VISUAL='vim'
export TERM=xterm-256color

# Prompt & Shell Enhancements
if command -v starship &>/dev/null; then
    eval "$(starship init bash)"
else
    PS1='[\u@\h \W]\$ '
fi

command -v zoxide &>/dev/null && eval "$(zoxide init bash)"

# Keybinds
fzf_history() {
    local command=$(history | sed 's/^[ ]*[0-9]*[ ]*//' | awk '!visited[$0]++' | fzf --exact --tac --height 40% --reverse)
    [[ -n "$command" ]] && READLINE_LINE="$command" && READLINE_POINT=${#command}
}
bind -x '"\C-h": fzf_history'

# ------------------------------------------------------------------------------
# 2. DEFINITIONS (Colors & Paths)
# ------------------------------------------------------------------------------
# Nord Theme Colors
NORD_CYAN='\e[38;2;143;188;187m'
NORD_BLUE='\e[38;2;136;192;208m'
NORD_D_BLUE='\e[38;2;129;161;193m'
NORD_GREEN='\e[38;2;163;190;140m'
NORD_RED='\e[38;2;191;97;106m'
RST='\e[0m'

# Hardware & Filesystem
IDEAPAD_CONSERVATION="/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"

# ------------------------------------------------------------------------------
# 3. ALIASES
# ------------------------------------------------------------------------------
# Navigation & Basics
alias ..='cd ..'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
command -v bat &>/dev/null && alias cat='bat'
alias clear='clear && sys'
alias reload='source ~/.bashrc'

# Sudo last command (must be a function, not alias, so it expands at call time)
rr() { sudo $(fc -ln -1); }

# Config & Session
alias conf='vim ~/.bashrc'
alias confc='[[ -x $(command -v codium) ]] && codium ~/arch-config/ || echo "VSCodium not found."'

# Maintenance
alias upp='yay -Syu'
alias upall='yay -Syu && upf'
alias up-mirrors='sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist && sudo pacman -Syyu'
alias age='echo -e "${NORD_BLUE}󰃭  OS Age:${RST} $(( ($(date +%s) - $(stat -c %Y /lost+found 2>/dev/null || stat -c %Y /)) / 86400 )) days"'

# ------------------------------------------------------------------------------
# 4. SYSTEM & HARDWARE FUNCTIONS
# ------------------------------------------------------------------------------
sys() {
    local total_pkgs=$(pacman -Qq | wc -l)
    local aur_pkgs=$(pacman -Qm | wc -l)
    local chaotic_pkgs=$(pacman -Sl chaotic-aur 2>/dev/null | grep '\[installed\]' | wc -l)
    local repo_pkgs=$((total_pkgs - aur_pkgs - chaotic_pkgs))
    local pkg_string="${repo_pkgs} (repo) + ${chaotic_pkgs} (chaos) + ${aur_pkgs} (aur)"

    local birth_date=$(stat -c %Y /lost+found 2>/dev/null || stat -c %Y /)
    local age=$(( ($(date +%s) - birth_date) / 86400 ))
    local ker=$(uname -r | cut -d '-' -f1)
    local mem=$(free -h | awk '/^Mem:/ {print $3 " / " $2}')
    local uptime=$(uptime -p | sed 's/up //')

    echo -e "\n  ${NORD_CYAN}󰣇  ${NORD_BLUE}Arch Linux${RST}"
    echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
    printf "     ${NORD_BLUE}󱑎 ${NORD_D_BLUE} %-11s ${RST}${NORD_BLUE}%s${RST}\n" "Uptime" "$uptime"
    printf "     ${NORD_BLUE}󰟾 ${NORD_D_BLUE} %-11s ${RST}${NORD_BLUE}%s${RST}\n" "Kernel" "$ker"
    printf "     ${NORD_BLUE}󰏖 ${NORD_D_BLUE} %-11s ${RST}${NORD_BLUE}%s${RST}\n" "Pkgs"    "$pkg_string"
    printf "     ${NORD_BLUE}󰍛 ${NORD_D_BLUE} %-11s ${RST}${NORD_BLUE}%s${RST}\n" "Memory" "$mem"
    printf "     ${NORD_BLUE}󰃭 ${NORD_D_BLUE} %-11s ${RST}${NORD_BLUE}%s days${RST}\n" "Age" "$age"

    if [[ -f "$IDEAPAD_CONSERVATION" ]]; then
        local cons_status
        [[ $(< "$IDEAPAD_CONSERVATION") -eq 1 ]] && cons_status="Conserving (80%)" || cons_status="Full Charge"
        printf "     ${NORD_BLUE}󱊟 ${NORD_D_BLUE} %-11s ${RST}${NORD_BLUE}%s${RST}\n" "Battery" "$cons_status"
    fi

    printf "     ${NORD_BLUE} ${NORD_D_BLUE} %-11s ${RST}${NORD_BLUE}Bash ${BASH_VERSION%%(*}${RST}\n" "Shell"
    echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}\n"
}

if [[ -f "$IDEAPAD_CONSERVATION" ]]; then
    batt-on() {
        echo 1 | sudo tee "$IDEAPAD_CONSERVATION" > /dev/null \
            && echo -e "\n  ${NORD_CYAN}󱊟  Battery Conservation${RST}" \
            && echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}" \
            && printf "     ${NORD_BLUE}󰏔 ${NORD_D_BLUE} %-11s ${RST}${NORD_GREEN}%s${RST}\n" "Status" "ENABLED (80%)" \
            && echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}\n"
    }

    batt-off() {
        echo 0 | sudo tee "$IDEAPAD_CONSERVATION" > /dev/null \
            && echo -e "\n  ${NORD_CYAN}󱊟  Battery Conservation${RST}" \
            && echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}" \
            && printf "     ${NORD_BLUE}󰏔 ${NORD_D_BLUE} %-11s ${RST}${NORD_BLUE}%s${RST}\n" "Status" "DISABLED (100%)" \
            && echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}\n"
    }
fi

# ------------------------------------------------------------------------------
# 5. PACKAGE MANAGEMENT (Pacman/Yay/AUR)
# ------------------------------------------------------------------------------
cleanup() {
    echo -e "\n  ${NORD_CYAN}󰃨  Cleaning System Cache${RST}"
    echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
    printf "     ${NORD_BLUE}󰆑 ${NORD_D_BLUE} %-30s${RST}\n" "Removing partial downloads..."
    sudo rm -rf /var/cache/pacman/pkg/download-*
    sudo rm -f /var/cache/pacman/pkg/*.part
    printf "     ${NORD_BLUE}󰆑 ${NORD_D_BLUE} %-30s${RST}\n" "Cleaning yay cache..."
    yay -Sc --noconfirm
    yay -Yc
    printf "     ${NORD_BLUE}󰆑 ${NORD_D_BLUE} %-30s${RST}\n" "Running paccache..."
    sudo paccache -rk2
    sudo paccache -ruk0
    printf "     ${NORD_BLUE}󰆑 ${NORD_D_BLUE} %-30s${RST}\n" "Clearing yay build cache..."
    rm -rf ~/.cache/yay/*
    echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
    printf "     ${NORD_BLUE}󰋊 ${NORD_D_BLUE} %-11s ${RST}${NORD_GREEN}%s${RST}\n" "Cache Size" "$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1)"
    echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}\n"
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
                printf "${NORD_GREEN}%-25s${RST} | %-25s | %10s\n" "$pkg" "$version" "$size_info"
            else
                printf "${NORD_GREEN}%-25s${RST} | %-25s\n" "$pkg" "$version"
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
            } END { if (sum > 0) printf "\033[1;37mTotal Download: %.2f MiB\033[0m\n", sum }'
        fi
    }

    local all_sync=$(checkupdates 2>/dev/null)
    local chaotic_names=$(pacman -Sl chaotic-aur 2>/dev/null | awk '{print $2}')

    echo -e "\n${NORD_BLUE}󰏖  Official Repos${RST} ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━${RST}"
    local official_updates
    if [[ -z "$chaotic_names" ]]; then
        official_updates="$all_sync"
    else
        official_updates=$(echo "$all_sync" | grep -vFwf <(echo "$chaotic_names"))
    fi
    [[ -z "$official_updates" ]] && echo -e "     ${NORD_D_BLUE} No official updates${RST}" || process_updates "$official_updates" "pacman" "true"

    echo -e "\n${NORD_CYAN}󰏖  Chaotic-AUR${RST} ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━${RST}"
    local chaotic_updates
    if [[ -z "$chaotic_names" ]]; then
        chaotic_updates=""
    else
        chaotic_updates=$(echo "$all_sync" | grep -Fwf <(echo "$chaotic_names"))
    fi
    [[ -z "$chaotic_updates" ]] && echo -e "     ${NORD_D_BLUE} No Chaotic updates${RST}" || process_updates "$chaotic_updates" "pacman" "true"

    echo -e "\n${NORD_D_BLUE}󰏖  AUR${RST} ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
    local aur_updates=$(yay -Qua 2>/dev/null)
    [[ -z "$aur_updates" ]] && echo -e "     ${NORD_D_BLUE} No AUR updates${RST}" || process_updates "$aur_updates" "yay" "false"
    echo ""
}

inst() {
    if [[ $# -gt 0 ]]; then
        echo -e "\n  ${NORD_CYAN}󰏖  Installing Packages${RST}"
        echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}\n"
        yay -S "$@"
    else
        local list=$(yay -Sl 2>/dev/null | awk '{print $1"/"$2}')
        [[ -z "$list" ]] && return 1
        echo "$list" | fzf --exact --multi --preview-window=right:60%,hidden --header "CTRL-P: Preview | ENTER: Install" \
            --bind 'ctrl-p:preview(
                item={}; repo=${item%%/*}; pkg=${item#*/}
                if [ "$repo" = "aur" ]; then yay -Siai "$pkg" 2>/dev/null; else yay -Sii "$pkg"; fi | \
                awk "/^(Votes|Popularity)/ { stats = stats \"\033[1;33m\" \$0 \"\033[0m\n\" } !/^(Votes|Popularity)/ { body = body \$0 \"\n\" } END { printf \"%s%s\", stats, body }"
            )' | xargs -ro yay -S
    fi
}

uninst() {
    if [[ $# -gt 0 ]]; then
        echo -e "\n  ${NORD_RED}󰆑  Uninstalling Packages${RST}"
        echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}\n"
        sudo pacman -Rns "$@"
    else
        yay -Qq | fzf --exact --multi --preview-window=down:75% --preview '
            yay -Qi {1} | awk "/^(Install Date|Installed Size)/ { stats = stats \"\033[1;31m\" \$0 \"\033[0m\n\" } !/^(Install Date|Installed Size)/ { body = body \$0 \"\n\" } END { printf \"%s%s\", stats, body }"
        ' | xargs -ro sudo pacman -Rns
    fi
}

lpa() {
    local list=$(yay -Qq)
    [[ -z "$list" ]] && return 1
    echo "$list" | fzf --exact \
        --header "ENTER: View Full Info | CTRL-C: Quit" \
        --preview-window=right:65% \
        --preview '
            yay -Qi {1} | awk "
                /^(Required By|Depends On)/ {
                    print \"\033[1;35m\" \$0 \"\033[0m\"
                }
                !/^(Required By|Depends On)/ { print }
            "
        ' \
        --bind 'enter:execute(yay -Qi {1} | less)'
}

# ------------------------------------------------------------------------------
# 6. NETWORK & CONNECTIVITY
# ------------------------------------------------------------------------------
cdns-on() {
    sudo cp /etc/systemd/resolved.conf.bak /etc/systemd/resolved.conf
    sudo systemctl restart systemd-resolved
    echo -e "\n  ${NORD_CYAN}󰛳  DNS Status${RST}"
    echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
    printf "     ${NORD_BLUE}󰈀 ${NORD_D_BLUE} %-11s ${RST}${NORD_GREEN}%s${RST}\n" "Custom DNS" "ENABLED"
    printf "     ${NORD_BLUE}󰒄 ${NORD_D_BLUE} %-11s ${RST}${NORD_BLUE}%s${RST}\n" "Provider" "NextDNS"
    echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}\n"
}

cdns-off() {
    sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak
    sudo truncate -s 0 /etc/systemd/resolved.conf
    sudo systemctl restart systemd-resolved
    echo -e "\n  ${NORD_CYAN}󰛳  DNS Status${RST}"
    echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
    printf "     ${NORD_BLUE}󰈀 ${NORD_D_BLUE} %-11s ${RST}${NORD_BLUE}%s${RST}\n" "Custom DNS" "DISABLED"
    printf "     ${NORD_BLUE}󰒄 ${NORD_D_BLUE} %-11s ${RST}${NORD_D_BLUE}%s${RST}\n" "Provider" "ISP Default"
    echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}\n"
}

warp-on() {
    echo -e "\n  ${NORD_CYAN}󰖂  WireGuard${RST}"
    echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
    sudo wg-quick up warp
    printf "     ${NORD_BLUE}󰤨 ${NORD_D_BLUE} %-11s ${RST}${NORD_GREEN}%s${RST}\n" "Status" "CONNECTED"
    echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}\n"
}

warp-off() {
    echo -e "\n  ${NORD_CYAN}󰖂  WireGuard${RST}"
    echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
    sudo wg-quick down warp
    printf "     ${NORD_BLUE}󰤭 ${NORD_D_BLUE} %-11s ${RST}${NORD_RED}%s${RST}\n" "Status" "DISCONNECTED"
    echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}\n"
}

termux() {
    local end_ip=$1
    local user="u0_a310"
    local port="8022"
    local base_ip="192.168.8."
    if [[ -z "$end_ip" ]]; then
        echo -e "\n  ${NORD_RED}󰄜  Termux SSH${RST}"
        echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
        printf "     ${NORD_BLUE}󰋼 ${NORD_D_BLUE} %-11s ${RST}${NORD_BLUE}%s${RST}\n" "Usage" "termux <last_octet_or_full_ip>"
        echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}\n"
        return 1
    fi
    local target_ip
    [[ "$end_ip" != *"."* ]] && target_ip="${base_ip}${end_ip}" || target_ip="$end_ip"
    echo -e "\n  ${NORD_CYAN}󰄜  Termux SSH${RST}"
    echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
    printf "     ${NORD_BLUE}󰩟 ${NORD_D_BLUE} %-11s ${RST}${NORD_BLUE}%s${RST}\n" "Target" "$target_ip:$port"
    printf "     ${NORD_BLUE}󰀄 ${NORD_D_BLUE} %-11s ${RST}${NORD_BLUE}%s${RST}\n" "User" "$user"
    echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}\n"
    ssh -p "$port" "$user@$target_ip"
}

upf() {
    local URL="https://raw.githubusercontent.com/yokoffing/Betterfox/main/user.js"
    local FF_DIR="$HOME/.config/mozilla/firefox"
    local TEMP_FILE="/tmp/betterfox_user.js"
    echo -e "\n  ${NORD_CYAN}󰈹  Firefox Hardening${RST}"
    echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
    printf "     ${NORD_BLUE}󰇚 ${NORD_D_BLUE} %-30s${RST}\n" "Downloading Betterfox..."
    if ! curl -fsSL "$URL" -o "$TEMP_FILE"; then
        printf "     ${NORD_RED}󰅙 ${NORD_D_BLUE} %-30s${RST}\n" "Download failed!"
        echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}\n"
        return 1
    fi
    {
        echo 'user_pref("browser.search.suggest.enabled", true);'
        echo 'user_pref("browser.contentblocking.category", "");'
        echo 'user_pref("privacy.globalprivacycontrol.enabled", false);'
        echo 'user_pref("gfx.webrender.software",true);'
    } >> "$TEMP_FILE"
    local found_any=false
    while IFS= read -r times_file; do
        local profile_path=$(dirname "$times_file")
        cp "$TEMP_FILE" "$profile_path/user.js"
        printf "     ${NORD_BLUE}󰄬 ${NORD_D_BLUE} Applied to: ${RST}${NORD_BLUE}%s${RST}\n" "$(basename "$profile_path")"
        found_any=true
    done < <(find "$FF_DIR" -maxdepth 2 -mindepth 2 -name "times.json")
    rm "$TEMP_FILE"
    echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
    if [[ "$found_any" = false ]]; then
        printf "     ${NORD_RED}󰅙 ${NORD_D_BLUE} %s${RST}\n" "No Firefox profiles found."
    else
        printf "     ${NORD_GREEN}󰄬 ${NORD_D_BLUE} %s${RST}\n" "All profiles hardened!"
    fi
    echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}\n"
}

upc() {
    echo -e "\n  ${NORD_CYAN}󰚰  Config Update${RST}"
    echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
    printf "     ${NORD_BLUE}󰊢 ${NORD_D_BLUE} %-30s${RST}\n" "Pulling arch-config..."
    if git -C "$HOME/arch-config" pull --rebase --autostash; then
        printf "     ${NORD_GREEN}󰄬 ${NORD_D_BLUE} %-30s${RST}\n" "Configs up to date!"
        echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}\n"
        source ~/.bashrc
    else
        printf "     ${NORD_RED}󰅙 ${NORD_D_BLUE} %-30s${RST}\n" "Update failed! Check conflicts."
        echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}\n"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# 7. PRODUCTIVITY TOOLS
# ------------------------------------------------------------------------------
ff() {
    local copy_cmd
    if command -v wl-copy &>/dev/null; then
        copy_cmd="wl-copy"
    elif command -v xclip &>/dev/null; then
        copy_cmd="xclip -selection clipboard"
    fi

    local search_path="${1:-$HOME}"

    if [[ -n $(find /var/lib/plocate/plocate.db -mmin +60 2>/dev/null) ]]; then
        echo -e "     ${NORD_BLUE}󰒓 ${NORD_D_BLUE} Updating file database...${RST}"
        sudo updatedb
    fi
    clear

    local selection=$(plocate "$search_path" | fzf --exact --tiebreak=length,end,index \
        --prompt="󰍉 Search: " --height=40% --layout=reverse \
        --header="ENTER: Open | ALT-C: Copy Path" --expect="alt-c")

    local key=$(echo "$selection" | head -n 1)
    local file=$(echo "$selection" | sed -n '2p')

    if [[ -n "$file" ]]; then
        if [[ "$key" == "alt-c" ]]; then
            if [[ -n "$copy_cmd" ]]; then
                echo -n "$file" | $copy_cmd
                echo -e "\n     ${NORD_CYAN}󰅍  Path Copied:${RST} ${NORD_BLUE}$file${RST}\n"
            else
                echo -e "\n     ${NORD_RED}󰅙  No clipboard tool found.${RST}\n"
            fi
        else
            if [[ -d "$file" ]]; then
                cd --silent "$file"
            else
                xdg-open "$file" >/dev/null 2>&1
            fi
        fi
    fi
}

open() {
    xdg-open "${1:-.}" >/dev/null 2>&1
}

cd() {
    if [[ "$1" == "--silent" ]]; then
        builtin cd "$2"
    else
        builtin cd "$@" && ls --color=auto
    fi
}

z() {
    if command -v __zoxide_z &>/dev/null; then
        __zoxide_z "$@" && ls --color=auto
    else
        builtin cd "$@"
    fi
}

# ------------------------------------------------------------------------------
# 8. MISCELLANEOUS & HELP
# ------------------------------------------------------------------------------
pirith() {
    local DIR="$HOME/Music/pirith"
    command -v mpv &>/dev/null || { echo -e "\n     ${NORD_RED}󰅙  mpv not found${RST}\n"; return 1; }
    [[ -d "$DIR" ]] || { echo -e "\n     ${NORD_RED}󰅙  Directory not found: $DIR${RST}\n"; return 1; }
    echo -e "\n  ${NORD_CYAN}󰎆  Pirith Player${RST}"
    echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}\n"
    local file=$(ls "$DIR"/*.mp3 2>/dev/null | fzf --prompt="󰎆 Select: ")
    if [[ -n "$file" ]]; then
        printf "     ${NORD_BLUE}󰝚 ${NORD_D_BLUE} Now Playing: ${RST}${NORD_BLUE}%s${RST}\n" "$(basename "$file")"
        echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}\n"
        mpv "$file"
    else
        echo -e "\n     ${NORD_RED}󰅙  No selection.${RST}\n"
    fi
}

info() {
    echo -e "\n  ${NORD_CYAN}󱈄  ${NORD_BLUE}Custom Shell Commands${RST}"
    echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
    printf "     ${NORD_BLUE}%-10s${RST}  %-42s\n" "System"   "sys, age, reload, conf, confc"
    printf "     ${NORD_BLUE}%-10s${RST}  %-42s\n" "Packages" "upp, upall, cup, inst, uninst, lpa, cleanup"

    if [[ -f "$IDEAPAD_CONSERVATION" ]]; then
        printf "     ${NORD_BLUE}%-10s${RST}  %-42s\n" "Hardware" "batt-on (80%), batt-off (100%)"
    fi

    printf "     ${NORD_BLUE}%-10s${RST}  %-42s\n" "Network"  "cdns-(on/off), warp-(on/off), termux"
    printf "     ${NORD_BLUE}%-10s${RST}  %-42s\n" "Utils"    "rr, ff, upf, upc, pirith, open"
    printf "     ${NORD_BLUE}%-10s${RST}  %-42s\n" "Keybinds" "CTRL+H: history search"

    echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}\n"
}

# Run system info on startup
sys