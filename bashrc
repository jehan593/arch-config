# ==============================================================================
# ARCH LINUX CUSTOM BASH CONFIGURATION
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. CORE SETUP & ENVIRONMENT
# ------------------------------------------------------------------------------
[[ $- != *i* ]] && return                # Interactive check

export EDITOR='vim'                      
export VISUAL='vim'                      

# Prompt & Shell Enhancements
if command -v starship &> /dev/null; then eval "$(starship init bash)"; else PS1='[\u@\h \W]\$ '; fi
if command -v zoxide   &> /dev/null; then eval "$(zoxide init bash)"; fi

# ------------------------------------------------------------------------------
# 2. DEFINITIONS (Colors & Paths)
# ------------------------------------------------------------------------------
# Nord Theme Colors
NORD_CYAN='\e[38;2;143;188;187m'
NORD_BLUE='\e[38;2;136;192;208m'
NORD_D_BLUE='\e[38;2;129;161;193m'
NORD_GREEN='\e[32m'
NORD_RED='\e[31m'
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
alias cat='bat'
alias clear='clear && sys'
alias rr='sudo $(fc -ln -1)'

# Config & Session
alias conf='vim ~/.bashrc'
alias confc='[[ -x $(command -v codium) ]] && codium ~/arch-config/ || echo "VSCodium not found."'
alias reload='source ~/.bashrc'

# Maintenance
alias upp='yay -Syu'
alias upall='yay -Syu && upf'
alias up-mirrors='sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist && sudo pacman -Syyu'
alias age='echo -e "${NORD_BLUE}OS Age:${RST} $(( ($(date +%s) - $(stat -c %Y /lost+found 2>/dev/null || stat -c %Y /)) / 86400 )) days"'

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
    
    # Only show Battery Status if the hardware path exists
    if [[ -f "$IDEAPAD_CONSERVATION" ]]; then
        local cons_status
        [[ $(cat "$IDEAPAD_CONSERVATION") -eq 1 ]] && cons_status="Conserving (80%)" || cons_status="Full Charge"
        printf "     ${NORD_BLUE}󱊟 ${NORD_D_BLUE} %-11s ${RST}${NORD_BLUE}%s${RST}\n" "Battery" "$cons_status"
    fi

    printf "     ${NORD_BLUE} ${NORD_D_BLUE} %-11s ${RST}${NORD_BLUE}Bash ${BASH_VERSION%%(*}${RST}\n" "Shell"
    echo -e "     ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}\n"
}

if [[ -f "$IDEAPAD_CONSERVATION" ]]; then
    batt-on() {
        echo 1 | sudo tee "$IDEAPAD_CONSERVATION" > /dev/null && echo -e "${NORD_CYAN}󱊟 Conservation ENABLED (80%)${RST}"
    }

    batt-off() {
        echo 0 | sudo tee "$IDEAPAD_CONSERVATION" > /dev/null && echo -e "${NORD_BLUE}󱊟 Conservation DISABLED (100%)${RST}"
    }
fi

# ------------------------------------------------------------------------------
# 5. PACKAGE MANAGEMENT (Pacman/Yay/AUR)
# ------------------------------------------------------------------------------
cleanup() {
    echo -e "${NORD_CYAN}🧹 Cleaning system cache...${RST}"
    sudo rm -rf /var/cache/pacman/pkg/download-*
    yay -Sc --noconfirm
    yay -Yc
    sudo paccache -rk2
    sudo paccache -ruk0
    rm -rf ~/.cache/yay/*
    rm -rf ~/.bash_history-*.tmp
    echo -e "${NORD_BLUE}Done. Current cache size: $(du -sh /var/cache/pacman/pkg/ | cut -f1)${RST}"
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
                printf "\033[1;32m%-25s\033[0m | %-25s | %10s\n" "$pkg" "$version" "$size_info"
            else
                printf "\033[1;32m%-25s\033[0m | %-25s\n" "$pkg" "$version"
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
    local chaotic_names=$(pacman -Sl chaotic-aur | awk '{print $2}')
    echo -e "\n${NORD_BLUE}󰏖  Official Repos${RST} ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━${RST}"
    local official_updates=$(echo "$all_sync" | grep -vFwf <(echo "$chaotic_names"))
    [[ -z "$official_updates" ]] && echo "No official updates" || process_updates "$official_updates" "pacman" "true"
  
    echo -e "\n${NORD_CYAN}󰏖  Chaotic-AUR${RST} ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━${RST}"
    local chaotic_updates=$(echo "$all_sync" | grep -Fwf <(echo "$chaotic_names"))
    [[ -z "$chaotic_updates" ]] && echo "No Chaotic updates" || process_updates "$chaotic_updates" "pacman" "true"
  
    echo -e "\n${NORD_D_BLUE}󰏖  AUR${RST} ${NORD_D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
    local aur_updates=$(yay -Qua 2>/dev/null)
    [[ -z "$aur_updates" ]] && echo "No AUR updates" || process_updates "$aur_updates" "yay" "false"
}

inst() {
    local list=$(yay -Sl 2>/dev/null | awk '{print $1"/"$2}')
    [[ -z "$list" ]] && return 1
    echo "$list" | fzf --exact --multi --preview-window=right:60%,hidden --header "CTRL-P: Preview | ENTER: Install" \
        --bind 'ctrl-p:preview(
            item={}; repo=${item%%/*}; pkg=${item#*/}
            if [ "$repo" = "aur" ]; then yay -Siai "$pkg" 2>/dev/null; else yay -Sii "$pkg"; fi | \
            awk "/^(Votes|Popularity)/ { stats = stats \"\033[1;33m\" \$0 \"\033[0m\n\" } !/^(Votes|Popularity)/ { body = body \$0 \"\n\" } END { printf \"%s%s\", stats, body }"
        )' | xargs -ro yay -S
}

uninst() {
    yay -Qq | fzf --exact --multi --preview-window=down:75% --preview '
        yay -Qi {1} | awk "/^(Install Date|Installed Size)/ { stats = stats \"\033[1;31m\" \$0 \"\033[0m\n\" } !/^(Install Date|Installed Size)/ { body = body \$0 \"\n\" } END { printf \"%s%s\", stats, body }"
    ' | xargs -ro sudo pacman -Rns
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
    sudo sed -i 's/^#//' /etc/systemd/resolved.conf
    sudo systemctl restart systemd-resolved
    echo -e "${NORD_CYAN}Custom DNS Enabled${RST}"
}

cdns-off() {
    sudo sed -i 's/^[^#]/#&/' /etc/systemd/resolved.conf
    sudo systemctl restart systemd-resolved
    echo -e "${NORD_CYAN}Custom DNS Disabled (using defaults)${RST}"
}

warp-on() { echo -e "${NORD_CYAN}🚀 Starting WireGuard...${RST}"; sudo wg-quick up warp; }
warp-off() { echo -e "${NORD_RED}🛑 Stopping WireGuard...${RST}"; sudo wg-quick down warp; }

termux() {
    local end_ip=$1
    local user="u0_a310"
    local port="8022"
    local base_ip="192.168.8."
    if [[ -z "$end_ip" ]]; then echo -e "${NORD_BLUE}Usage:${RST} termux <last_octet_or_full_ip>"; return 1; fi
    local target_ip
    [[ "$end_ip" != *"."* ]] && target_ip="${base_ip}${end_ip}" || target_ip="$end_ip"
    echo -e "${NORD_CYAN}󰄜 Connecting to Termux at $target_ip...${RST}"
    ssh -p "$port" "$user@$target_ip"
}

upf() {
    local URL="https://raw.githubusercontent.com/yokoffing/Betterfox/main/user.js"
    local FF_DIR="$HOME/.config/mozilla/firefox"
    local TEMP_FILE="/tmp/betterfox_user.js"
    if ! curl -fsSL "$URL" -o "$TEMP_FILE"; then echo -e "${NORD_RED}Error: Failed to download Betterfox user.js${RST}"; return 1; fi
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
        echo -e "${NORD_BLUE}Applied to: $(basename "$profile_path")${RST}"
        found_any=true
    done < <(find "$FF_DIR" -maxdepth 2 -mindepth 2 -name "times.json")
    rm "$TEMP_FILE"
    [[ "$found_any" = false ]] && echo "No profiles found." || echo -e "${NORD_GREEN}Firefox profiles hardened!${RST}"
}

# ------------------------------------------------------------------------------
# 7. PRODUCTIVITY TOOLS
# ------------------------------------------------------------------------------
fh() {
    local copy_cmd
    if command -v wl-copy &> /dev/null; then copy_cmd="wl-copy"; elif command -v xclip &> /dev/null; then copy_cmd="xclip -selection clipboard"; fi
    local selection=$(history | sed 's/^[ ]*[0-9]*[ ]*//' | awk '!visited[$0]++' | fzf --exact --tac --height 40% --reverse --header="ENTER: Run | ALT-C: Copy" --expect="alt-c")
    local key=$(echo "$selection" | head -n 1)
    local command=$(echo "$selection" | sed -n '2p')
    if [[ -n "$command" ]]; then
        if [[ "$key" == "alt-c" ]]; then
            [[ -n "$copy_cmd" ]] && echo -n "$command" | eval "$copy_cmd" && echo -e "${NORD_CYAN}󰅍 Copied:${RST} $command" || echo -e "${NORD_RED}No clipboard tool found.${RST}"
        else
            history -s "$command"
            echo -e "${NORD_CYAN}󰄜 Running:${RST} $command"
            eval "$command"
        fi
    fi
}

ff() {
    local copy_cmd
    if command -v wl-copy &> /dev/null; then 
        copy_cmd="wl-copy"
    elif command -v xclip &> /dev/null; then 
        copy_cmd="xclip -selection clipboard"
    fi

    echo "FileSync: Updating database..."
    sudo updatedb && clear

    local selection=$(plocate / | fzf --exact --tiebreak=length,end,index \
        --prompt="🔍 Search: " --height=40% --layout=reverse \
        --header="ENTER: Open | ALT-C: Copy Path" --expect="alt-c")

    local key=$(echo "$selection" | head -n 1)
    local file=$(echo "$selection" | sed -n '2p')

    if [[ -n "$file" ]]; then
        if [[ "$key" == "alt-c" ]]; then
            if [[ -n "$copy_cmd" ]]; then
                echo -n "$file" | eval "$copy_cmd"
                echo -e "${NORD_CYAN}󰅍 Path Copied:${RST} $file"
            else
                echo -e "${NORD_RED}No clipboard tool found.${RST}"
            fi
        else
            xdg-open "$file" >/dev/null 2>&1
        fi
    fi
}

# ------------------------------------------------------------------------------
# 8. TIME & PROGRESS
# ------------------------------------------------------------------------------
day() {
    local current_hour=$(date +%H | sed 's/^0*//'); local total_hours=24; local columns=12
    echo -e "${NORD_CYAN}Day Progress:${RST} Hour $current_hour / 24"
    for (( i=0; i<total_hours; i++ )); do
        if [ "$i" -lt "$current_hour" ]; then printf "\e[1m●\e[0m "; elif [ "$i" -eq "$current_hour" ]; then printf "\e[1;32m●\e[0m "; else printf "○ "; fi
        if (( (i + 1) % columns == 0 )); then echo ""; fi
    done
} 

week() {
    local current_day=$(date +%u); local total_days=7
    echo -e "${NORD_CYAN}Week Progress:${RST} Day $current_day of 7"
    for (( i=1; i<=total_days; i++ )); do
        if [ "$i" -lt "$current_day" ]; then printf "\e[1m●\e[0m "; elif [ "$i" -eq "$current_day" ]; then printf "\e[1;32m●\e[0m "; else printf "○ "; fi
    done; echo ""
}

month() {
    local year=$(date +%Y); local month=$(date +%m); local current_day=$(date +%d | sed 's/^0*//'); local total_days=$(date -d "$year-$month-01 +1 month -1 day" +%d)
    echo -e "${NORD_CYAN}Month Progress:${RST} $current_day / $total_days days"
    for (( i=1; i<=total_days; i++ )); do
        if [ "$i" -lt "$current_day" ]; then printf "\e[1m●\e[0m "; elif [ "$i" -eq "$current_day" ]; then printf "\e[1;32m●\e[0m "; else printf "○ "; fi
    done; echo ""
}

year() {
    local current_day=$(date +%j | sed 's/^0*//'); local year=$(date +%Y); local total_days=$(date -d "$year-12-31" +%j | sed 's/^0*//'); local columns=31 
    echo -e "${NORD_CYAN}Year $year Progress:${RST} $current_day / $total_days days"
    echo -e "${NORD_D_BLUE}------------------------------------------------------${RST}"
    for (( i=1; i<=total_days; i++ )); do
        if [ "$i" -lt "$current_day" ]; then printf "\e[1m●\e[0m "; elif [ "$i" -eq "$current_day" ]; then printf "\e[1;32m●\e[0m "; else printf "○ "; fi
        if (( i % columns == 0 )); then echo ""; fi
    done
    echo -e "\n${NORD_D_BLUE}------------------------------------------------------${RST}"
}

progress() { day && echo ""; week && echo ""; month && echo ""; year; }

# ------------------------------------------------------------------------------
# 9. MISCELLANEOUS & HELP
# ------------------------------------------------------------------------------
pirith() {
    local DIR="$HOME/Music/pirith"
    echo -e "${NORD_CYAN}󰎆 Select to Play${RST}\n1) pirith_udasana.mp3\n2) pirith_sawasa.mp3"
    read -rp "Selection: " choice
    case $choice in
        1) mpv "$DIR/pirith_udasana.mp3" ;;
        2) mpv "$DIR/pirith_sawasa.mp3" ;;
        *) echo -e "${NORD_RED}Invalid Choice !${RST}" ;;
    esac
}

info() {
    echo -e "\n  ${NORD_CYAN}󱈄  ${NORD_BLUE}Custom Shell Commands${RST}"
    echo -e "     ${NORD_D_BLUE}┏━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${RST}"
  
    printf "     ${NORD_D_BLUE}┃${RST} ${NORD_BLUE}%-10s${RST} ${NORD_D_BLUE}┃${RST} %-42s ${NORD_D_BLUE}┃${RST}\n" "System"   "sys, age, reload, conf, confc, progress"
    printf "     ${NORD_D_BLUE}┃${RST} ${NORD_BLUE}%-10s${RST} ${NORD_D_BLUE}┃${RST} %-42s ${NORD_D_BLUE}┃${RST}\n" "Packages" "upp, upall, cup, inst, uninst, lpa, cleanup"
    
    # Only show Hardware section in info if functions are defined
    if [[ -f "$IDEAPAD_CONSERVATION" ]]; then
        printf "     ${NORD_D_BLUE}┃${RST} ${NORD_BLUE}%-10s${RST} ${NORD_D_BLUE}┃${RST} %-42s ${NORD_D_BLUE}┃${RST}\n" "Hardware" "batt-on (80%), batt-off (100%)"
    fi

    printf "     ${NORD_D_BLUE}┃${RST} ${NORD_BLUE}%-10s${RST} ${NORD_D_BLUE}┃${RST} %-42s ${NORD_D_BLUE}┃${RST}\n" "Network"  "cdns-(on/off), warp-(on/off), termux"
    printf "     ${NORD_D_BLUE}┃${RST} ${NORD_BLUE}%-10s${RST} ${NORD_D_BLUE}┃${RST} %-42s ${NORD_D_BLUE}┃${RST}\n" "Utils"    "rr (sudo), fh (hist), ff, upf, pirith"
    printf "     ${NORD_D_BLUE}┃${RST} ${NORD_BLUE}%-10s${RST} ${NORD_D_BLUE}┃${RST} %-42s ${NORD_D_BLUE}┃${RST}\n" "Time"      "day, week, month, year"
  
    echo -e "     ${NORD_D_BLUE}┗━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RST}\n"
}

# Run system info on startup
sys
