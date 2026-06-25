# Core Setup & Environment
[[ $- != *i* ]] && return

if [[ "$(tty)" == /dev/tty* ]]; then
    export EDITOR='nvim'
    export PATH="$HOME/.local/bin:$PATH"
    PS1='\u@\h:\w\$ '
    return
fi

export EDITOR='nvim'
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

source "$HOME/arch-config/scripts/helpers.sh"

IDEAPAD_CONSERVATION="/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"

_info_group() {
    echo -e "\n ${NORD_YELLOW}${1}  ${2}${RST}"
}

_info_cmd() {
    printf "    ${NORD_CYAN}%-14s${RST}${NORD_POLAR_4} 󰁔 ${RST}${NORD_SNOW_1}%s${RST}\n" "$1" "$2"
}

# Aliases
alias ..='cd ..'
alias ls='ls --color=auto -F'
alias la='ls -aF --color=auto'
alias tree='tree -C'
alias ll='ls -lhF --color=auto'
alias lla='ls -alhF --color=auto'
alias grep='grep --color=auto'
alias clear='clear && sys'
alias reload='source ~/.bashrc && echo -e "${NORD_GREEN}󰑓  Profile reloaded${RST}"'
rr() {
    local cmd
    cmd=$(HISTTIMEFORMAT='' history 2 | head -1 | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//')
    echo -e "${NORD_CYAN}󰌆  Sudo: ${NORD_YELLOW}$cmd${RST}"
    sudo bash -c "$cmd"
}
alias conf='[[ -x $(command -v zeditor) ]] && (echo -e "${NORD_CYAN}󰘖  Opening configs...${RST}" && zeditor ~/arch-config/) || echo -e "${NORD_RED}󰅙  Zed not found${RST}"'
alias age='echo -e "${NORD_BLUE}󰃭  OS Age: $(( ($(date +%s) - $(stat -c %Y /lost+found 2>/dev/null || stat -c %Y /)) / 86400 )) days${RST}"'

# System Functions
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
        [[ $(< "$IDEAPAD_CONSERVATION") -eq 1 ]] && status="Eco Mode (80%)" || status="Full Charge (100%)"
        printf "$f" "󱊟" "Battery" "$status"
    fi
    printf "$f" "󰒍" "Shell" "Bash ${BASH_VERSION%%(*}"

    echo ""
}

if [[ -f "$IDEAPAD_CONSERVATION" ]]; then
    batt-on() {
        echo 1 | sudo tee "$IDEAPAD_CONSERVATION" > /dev/null
        _print_header "󱊟" "Battery"
        _print_status "󰄬" "Eco mode enabled (80% limit)"
        echo ""
    }
    batt-off() {
        echo 0 | sudo tee "$IDEAPAD_CONSERVATION" > /dev/null
        _print_header "󱊟" "Battery"
        _print_status "󰄬" "Full charge enabled"
        echo ""
    }
fi

# Package Management
cleanup() {
    _print_header "󰃨" "System Cleanup"

    sudo rm -rf /var/cache/pacman/pkg/download-*
    _print_result $? "Cleared partial downloads"

    rm -f ~/.bash_history-*.tmp
    _print_result $? "Cleared history temp files"

    yay -Sc --noconfirm
    _print_result $? "Cleared AUR cache"

    yay -Yc --noconfirm
    _print_result $? "Cleared AUR orphans"

    sudo paccache -rk2
    _print_result $? "Cleared old Pacman cache (kept 2)"

    sudo paccache -ruk0
    _print_result $? "Cleared uninstalled pkg cache"

    rm -rf ~/.cache/yay/*
    _print_result $? "Cleared AUR build cache"

    _print_status "󰋊" "Remaining cache: $(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1)"
    echo ""
}

cup() {
    sudo pacman -Sy --noconfirm &>/dev/null
    local any=false
    local all_updates=$(checkupdates 2>/dev/null)
    local aur_updates=$(yay -Qua 2>/dev/null)

    if [[ -n "$all_updates" ]]; then
        local pkgs=($(echo "$all_updates" | awk '{print $1}'))
        declare -A pkg_repo
        while read -r repo pkg; do
            pkg_repo["$pkg"]="$repo"
        done < <(pacman -Sp --print-format '%r %n' "${pkgs[@]}" 2>/dev/null)

        declare -A repo_updates
        while IFS= read -r line; do
            local pkg=$(echo "$line" | awk '{print $1}')
            local repo="${pkg_repo[$pkg]}"
            [[ -z "$repo" ]] && continue
            repo_updates["$repo"]+="$line"$'\n'
        done <<< "$all_updates"

        for repo in $(echo "${!repo_updates[@]}" | tr ' ' '\n' | sort); do
            any=true
            _print_header "󰏖" "$repo"
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                _print_pkg_line "$line"
            done <<< "${repo_updates[$repo]}"
            echo ""
        done
    fi

    if [[ -n "$aur_updates" ]]; then
        any=true
        _print_header "󰏖" "AUR"
        echo "$aur_updates" | while read -r line; do
            _print_pkg_line "$line"
        done
        echo ""
    fi

    [[ "$any" == false ]] && _print_status "󰄬" "System is up to date"
    echo ""
}

inst() {
    if [[ "$1" == "-refresh" ]]; then
        echo -e "${NORD_D_BLUE}󰒓  Refreshing package list...${RST}"
        mkdir -p "$HOME/.local/share/yay"
        yay -Sl 2>/dev/null | awk '{print $1"/"$2}' > "$HOME/.local/share/yay/pkg-list.cache"
        _print_status "󰄬" "Package list updated"
        inst
        return 0
    fi
    if [[ $# -gt 0 ]]; then
        _print_header "󰏖" "Installing"
        yay -S "$@"
        history -s "yay -S $*"
        history -a
    else
        local cache="$HOME/.local/share/yay/pkg-list.cache"
        if [[ ! -f "$cache" ]] || [[ -n $(find "$cache" -mmin +10080 2>/dev/null) ]]; then
            echo -e "${NORD_D_BLUE}󰒓  Refreshing package list...${RST}"
            mkdir -p "$HOME/.local/share/yay"
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
        _print_header "󰆑" "Uninstalling"
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

# Network & Connectivity
cdns-on() {
    _print_header "󰛳" "DNS Config"

    sudo cp /etc/systemd/resolved.conf.bak /etc/systemd/resolved.conf
    _print_result $? "Restored DNS config"

    sudo systemctl restart systemd-resolved
    _print_result $? "Restarted DNS service"

    _print_status "󰄬" "NextDNS enabled"
    echo ""
}

cdns-off() {
    _print_header "󰛳" "DNS Config"

    sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak
    _print_result $? "Backed up DNS config"

    sudo truncate -s 0 /etc/systemd/resolved.conf
    _print_result $? "Cleared DNS config"

    sudo systemctl restart systemd-resolved
    _print_result $? "Restarted DNS service"

    _print_status "󰄬" "Default DNS enabled"
    echo ""
}

upf() {
    local URL="https://raw.githubusercontent.com/yokoffing/Betterfox/main/user.js"
    local FF_DIR="$HOME/.config/mozilla/firefox"
    local REMOVALS="$HOME/arch-config/.config/firefox/user-removals.txt"
    local TEMP_FILE="/tmp/betterfox_user.js"

    _print_header "󰈹" "Firefox Config"

    if ! curl -fsSL "$URL" -o "$TEMP_FILE" &>/dev/null; then
        _print_status "󰅙" "Failed to download Betterfox"
        echo ""; return 1
    fi

    if [[ -f "$REMOVALS" ]]; then
        while IFS= read -r key; do
            [[ -z "$key" ]] && continue
            sed -i "/user_pref(\"${key}\"/d" "$TEMP_FILE"
        done < "$REMOVALS"
        _print_status "󰄬" "Applied custom settings"
    else
        _print_status "󰀦" "No custom settings file found"
    fi

    local found=false
    while IFS= read -r times_file; do
        local profile_path
        profile_path=$(dirname "$times_file")
        if cp "$TEMP_FILE" "$profile_path/user.js"; then
            _print_status "󰄬" "Updated profile: $(basename "$profile_path")"
        else
            _print_status "󰅙" "Failed profile: $(basename "$profile_path")"
        fi
        found=true
    done < <(find "$FF_DIR" -maxdepth 2 -mindepth 2 -name "times.json")

    rm "$TEMP_FILE"
    [[ "$found" = false ]] && _print_status "󰅙" "No Firefox profiles found"
    echo ""
}

upc() {
    _print_header "󰚰" "Config Sync"
    git -C "$HOME/arch-config" pull --rebase --autostash
    if [[ $? -eq 0 ]]; then
        _print_status "󰄬" "Config synced"
        echo ""
        echo -e "${NORD_YELLOW}󰌵  run 'reload' to apply changes"
        echo ""
    else
        _print_status "󰅙" "Sync failed"
        echo ""
        return 1
    fi
}

upall() {
    upp && upf && upwp && upc 
    echo ""

    read -rp " Run topgrade as well? [y/N]: " run_topgrade
    run_topgrade="${run_topgrade,,}"
    if [[ "$run_topgrade" == "y" || "$run_topgrade" == "yes" ]]; then
        if command -v topgrade &>/dev/null; then
            _print_header "" "topgrade"
            topgrade
        else
            echo -e "${NORD_RED}󰅙  topgrade is not installed.${RST}"
        fi
    fi
}

upp() {
    local repos=$(pacman -Sl 2>/dev/null | awk '{print $1}' | sort -u | sed 's/^/  /')
    local choice=$(printf "  All\n%s\n  AUR" "$repos" | \
        fzf --header "Upgrade Packages:" --height=12 --no-info --no-sort --no-input)
    [[ -z "$choice" ]] && return 0
    local label=$(echo "$choice" | xargs)
    echo ""

    _print_header "󰑮" "Upgrading Packages: $label"
    case "$label" in
        All) yay -Syu --noconfirm ;;
        AUR) yay -Sua --noconfirm ;;
        *)
            sudo pacman -Sy --noconfirm &>/dev/null
            local repo_pkgs=$(pacman -Sl "$label" 2>/dev/null | awk '{print $2}')
            local to_upgrade=$(checkupdates 2>/dev/null | awk '{print $1}' | grep -Fwf <(echo "$repo_pkgs"))
            if [[ -z "$to_upgrade" ]]; then
                _print_status "󰄬" "Packages up to date"
            else
                sudo pacman -S --noconfirm $to_upgrade
            fi
            ;;
    esac
    echo ""
}

up-mirrors() {
    _print_header "󰈀" "Mirror Update"
    sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
    sudo pacman -Syyu
    _print_result $? "Mirrors updated"
    echo ""
}

# Productivity Tools
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
        echo -e "${NORD_RED}󰅙  Not found: $target${RST}"
        return 1
    fi
    local size=$(du -sh "$target" 2>/dev/null | cut -f1)
    _print_header "󰋊" "Disk Usage"
    _print_status "󰉋" "$target: $size"
    echo ""
}

cd() { if [[ "$1" == "--silent" ]]; then builtin cd "$2"; else builtin cd "$@" && ls -a --color=auto; fi; }
z() { if command -v __zoxide_z &>/dev/null; then __zoxide_z "$@" && ls -a --color=auto; else builtin cd "$@"; fi; }

ff() {
    local search_path="${1:-/}"
    if [[ ! -d "$search_path" ]]; then
        echo -e "${NORD_RED}󰅙  Directory not found: $search_path${RST}"
        return 1
    fi

    local selection=$(find "$search_path" 2>/dev/null | fzf \
        --height=40% \
        --no-border \
        --header="󰍉 Searching: $search_path")

    [[ -z "$selection" ]] && return 0

    local quoted="\"$selection\""
    echo -n "$quoted" | xclip -selection clipboard
    echo -e "${NORD_CYAN}󰅍  Copied: ${NORD_SNOW_1}$selection${RST}"
}

upwp() {
    local WALLPAPERS_DIR="$HOME/Pictures/config-wallpapers"
    if [[ ! -d "$WALLPAPERS_DIR" ]]; then
        _print_header "󰹧" "Wallpapers"
        _print_status "󰅙" "Directory not found"
        echo ""; return 1
    fi

    _print_header "󰹧" "Wallpapers"
    git -C "$WALLPAPERS_DIR" pull --rebase --autostash
    _print_result $? "Pulled updates"
    echo ""
}

# Miscellaneous & Help
info() {
    _print_header "󱈄" "Shell Toolkit"

    _info_group "󰣇" "System"
    _info_cmd "sys"         "System details & uptime"
    _info_cmd "age"         "OS age"
    _info_cmd "reload"      "Reload shell profile"
    _info_cmd "conf"        "Edit system configs"
    _info_cmd "rr"          "Re-run last command as admin"

    _info_group "󰏖" "Packages"
    _info_cmd "inst"        "Install packages"
    _info_cmd "uinst"       "Uninstall packages"
    _info_cmd "upp"         "Upgrade packages"
    _info_cmd "cup"         "Check for updates"
    _info_cmd "cleanup"     "Clean package cache & temporary files"
    _info_cmd "up-mirrors"  "Update download mirrors"

    _info_group "󰚰" "Updates"
    _info_cmd "upall"       "Update everything (packages, config, wallpapers)"
    _info_cmd "upc"         "Update system configuration files"
    _info_cmd "upf"         "Apply Firefox performance tweaks"
    _info_cmd "upwp"         "Sync wallpapers"

    if [[ -f "$IDEAPAD_CONSERVATION" ]]; then
        _info_group "󱊟" "Battery"
        _info_cmd "batt-on"     "Enable Eco Mode (80% charge limit)"
        _info_cmd "batt-off"    "Disable charge limit (charge to 100%)"
    fi

    _info_group "󰛳" "Network"
    _info_cmd "cdns-on"     "Enable NextDNS custom DNS"
    _info_cmd "cdns-off"    "Restore default ISP DNS"
    _info_cmd "wg-socks"    "Manage WireGuard proxy"

    _info_group "󰓇" "Files"
    _info_cmd "exp [path]"  "Open path in file manager"
    _info_cmd "open [path]" "Open file or link"
    _info_cmd "ff [path]"   "Find file & copy its path"
    _info_cmd "sz [path]"   "Show file or directory size"

    _info_group "󰉋" "Navigation"
    _info_cmd "z [query]"   "Quick jump to a directory"
    _info_cmd "ll"          "List files with details"
    _info_cmd "la"          "List all files (including hidden)"
    _info_cmd "lla"         "List all files with details"

    _info_group "󰌌" "Keybinds"
    _info_cmd "Ctrl+H"      "Search command history"

    _info_group "" "Utilities"
    _info_cmd "timer [timer]" "Start a timer"

    echo ""
}

sys
echo -e "${NORD_YELLOW}󰌵  Type 'info' for help${RST}\n"