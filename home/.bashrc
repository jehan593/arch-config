# Core Setup & Environment
[[ $- != *i* ]] && return

if [[ "$(tty)" == /dev/tty* ]]; then
    export EDITOR='nvim'
    export PATH="$HOME/.local/bin:$PATH"
    PS1='\u@\h:\w\$ '
    return
fi

if [[ -z "$ARCH_CONFIG_PATH" && -f /etc/profile.d/arch-config.sh ]]; then
    source /etc/profile.d/arch-config.sh
fi

source "$ARCH_CONFIG_PATH/helpers/common-helpers.sh"

if ! _test_dependencies fzf yay git curl xclip checkupdates paccache reflector xdg-open; then
    PS1='[\u@\h \W]\$ '
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
HISTCONTROL=ignoredups:erasedups
shopt -s histappend

export FZF_DEFAULT_OPTS="
    --exact
    --cycle
    --layout=reverse
    --border=rounded
    --color=fg:#d8dee9,bg:#2e3440,hl:#81a1c1,fg+:#eceff4,bg+:#3b4252,hl+:#88c0d0,border:#88c0d0
    --bind=ctrl-p:toggle-preview
    --bind=ctrl-a:toggle-all
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
        --bind=ctrl-a:toggle-all \
        --header='Enter: insert | CTRL-A: toggle all' \
        --prompt="History > ")
    [[ -z "$output" ]] && return 0
    local cmd=""
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ -z "$cmd" ]] && cmd="$line" || cmd="$cmd & $line"
    done <<< "$output"
    READLINE_LINE="$cmd"
    READLINE_POINT=${#cmd}
}
bind -x '"\C-h": fzf_history'

IDEAPAD_CONSERVATION="/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"

# Aliases
alias ls='ls --color=auto -F'
alias lsl='ls -lh'
alias lsa='ls -a'
alias lsla='ls -lah'
alias rmr='rm -r'
alias rmrf='rm -rf'
alias cpr='cp -r'
alias cpa='cp -a'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias clear='clear && sys'
alias reload='source ~/.bashrc && echo -e "${NORD_GREEN}Profile reloaded${RST}"'
rr() {
    local cmd
    cmd=$(HISTTIMEFORMAT='' history 2 | head -1 | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//')
    echo -e "${NORD_CYAN}Sudo: ${NORD_YELLOW}$cmd${RST}"
    sudo -E bash -c "
        source \"$ARCH_CONFIG_PATH/helpers/common-helpers.sh\"
        shopt -s expand_aliases
        $(alias)
        $(declare -f)
        $cmd
    "
}
alias conf='[[ -x $(command -v zeditor) ]] && (echo -e "${NORD_CYAN}Opening configs...${RST}" && zeditor "$ARCH_CONFIG_PATH/") || echo -e "${NORD_RED}Zed not found${RST}"'
alias age='echo -e "${NORD_BLUE}OS Age: $(( ($(date +%s) - $(stat -c %Y /lost+found 2>/dev/null || stat -c %Y /)) / 86400 )) days${RST}"'

# System Functions (Icons explicitly kept here)
sys() {
    local total_pkgs=$(pacman -Qq | wc -l)
    local ker=$(uname -r | cut -d '-' -f1)
    local mem=$(free -h | awk '/^Mem:/ {print $3 " / " $2}')
    local uptime=$(uptime -p | sed 's/up //')
    local age=$(( ($(date +%s) - $(stat -c %Y /lost+found 2>/dev/null || stat -c %Y /)) / 86400 ))

    local f="  ${NORD_BLUE}%s${RST}  %-12s ${NORD_SNOW_1}%s${RST}\n"

    _print_header "󰣇" " Arch Linux"
    printf "$f" "󱑎" "Uptime"   "$uptime"
    printf "$f" "󰟾" "Kernel"   "$ker"
    printf "$f" "󰏖" "Packages" "$total_pkgs"
    printf "$f" "󰍛" "Memory"   "$mem"
    printf "$f" "󰃭" "OS Age"   "$age days"

    if [[ -f "$IDEAPAD_CONSERVATION" ]]; then
        local status
        [[ $(< "$IDEAPAD_CONSERVATION") -eq 1 ]] && status="Conservation Mode (80%)" || status="Full Charge (100%)"
        printf "$f" "󱊟" "Battery" "$status"
    fi
    printf "$f" "󰒍" "Shell" "Bash ${BASH_VERSION%%(*}"

    echo ""
}

if [[ -f "$IDEAPAD_CONSERVATION" ]]; then
    batt-on() {
        echo 1 | sudo tee "$IDEAPAD_CONSERVATION" > /dev/null
        _print_header "Battery" ""
        _print_status "success" "Conservation mode enabled (80% limit)"
        echo ""
    }
    batt-off() {
        echo 0 | sudo tee "$IDEAPAD_CONSERVATION" > /dev/null
        _print_header "Battery" ""
        _print_status "success" "Full charge enabled"
        echo ""
    }
fi

# Package Management
cleanup() {
    _print_header "System Cleanup" ""

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

    rm -rf ~/.local/share/Trash/files ~/.local/share/Trash/info
    mkdir -p ~/.local/share/Trash/files ~/.local/share/Trash/info
    _print_result $? "Emptied trash"

    _print_status "info" "Remaining cache: $(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1)"
    echo ""
}

cup() {
    sudo pacman -Sy --noconfirm &>/dev/null
    [[ $? -eq 0 ]] || _print_status "error" "Failed to sync package database"
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
            _print_header "$repo" ""
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                _print_pkg_line "$line"
            done <<< "${repo_updates[$repo]}"
            echo ""
        done
    fi

    if [[ -n "$aur_updates" ]]; then
        any=true
        _print_header "AUR" ""
        echo "$aur_updates" | while read -r line; do
            _print_pkg_line "$line"
        done
        echo ""
    fi

    [[ "$any" == false ]] && _print_status "success" "System is up to date"
    echo ""
}

_print_pkg_line() {
    local pkg=$(awk '{print $1}' <<< "$1")
    local ver=$(awk '{$1=""; print $0}' <<< "$1" | xargs)
    printf "${NORD_GREEN}%-35s${RST} ${NORD_SNOW_1}%s${RST}\n" "$pkg" "$ver"
}

_record_history() {
    history -s "$1"
    history -a
}

inst() {
    if [[ "$1" == "-refresh" ]]; then
        echo -e "${NORD_D_BLUE}Refreshing package list...${RST}"
        mkdir -p "$HOME/.config/arch-config-files/inst"
        yay -Sl 2>/dev/null | awk '{print $1"/"$2}' > "$HOME/.config/arch-config-files/inst/pkg-list.cache"
        _print_status "success" "Package list updated"
        inst
        return 0
    fi
    if [[ $# -gt 0 ]]; then
        _print_header "Installing" ""
        yay -S "$@"
        _record_history "yay -S $*"
    else
        local cache="$HOME/.config/arch-config-files/inst/pkg-list.cache"
        if [[ ! -f "$cache" ]] || [[ -n $(find "$cache" -mmin +10080 2>/dev/null) ]]; then
            echo -e "${NORD_D_BLUE}Refreshing package list...${RST}"
            mkdir -p "$HOME/.config/arch-config-files/inst"
            yay -Sl 2>/dev/null | awk '{print $1"/"$2}' > "$cache"
        fi
        [[ ! -s "$cache" ]] && return 1
        local selected
        selected=$(cat "$cache" | fzf --multi \
            --preview-window=right:60%:hidden \
            --bind=ctrl-a:toggle-all \
            --header "CTRL-P: Preview | CTRL-A: toggle all" \
            --preview '
                item={}; repo=${item%%/*}; pkg=${item#*/}
                if [ "$repo" = "aur" ]; then yay -Siai "$pkg" 2>/dev/null; else yay -Sii "$pkg"; fi | \
                awk "/^(Votes|Popularity)/ { stats = stats \"\033[1;33m\" \$0 \"\033[0m\n\" } !/^(Votes|Popularity)/ { body = body \$0 \"\n\" } END { printf \"%s%s\", stats, body }"
            ')
        [[ -z "$selected" ]] && return 0
        local pkgs
        pkgs=$(echo "$selected" | awk -F/ '{print $2}' | paste -sd' ')
        _record_history "yay -S ${pkgs}"
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
            echo "* $line"
        fi
    done
}

uinst() {
    if [[ $# -gt 0 ]]; then
        _print_header "Uninstalling" ""
        sudo pacman -Rns "$@"
        _record_history "sudo pacman -Rns $*"
    else
        local selected
        selected=$(_pkg_list | fzf --multi \
            --preview-window=right:50%:hidden \
            --bind=ctrl-a:toggle-all \
            --header "Initially Installed (*: Explicit) | CTRL-P: Preview | CTRL-A: toggle all" \
            --preview 'echo {} | awk -F/ "{print \$2}" | xargs yay -Qi 2>/dev/null | awk "/^(Install Date|Installed Size)/ { stats = stats \"\033[1;31m\" \$0 \"\033[0m\n\" } !/^(Install Date|Installed Size)/ { body = body \$0 \"\n\" } END { printf \"%s%s\", stats, body }"')
        [[ -z "$selected" ]] && return 0
        local pkgs
        pkgs=$(echo "$selected" | awk '{print $NF}' | awk -F/ '{print $2}' | paste -sd' ')
        _record_history "sudo pacman -Rns ${pkgs}"
        sudo pacman -Rns $pkgs
    fi
}

# Network & Connectivity
cdns-on() {
    _print_header "DNS Config" ""

    sudo cp /etc/systemd/resolved.conf.bak /etc/systemd/resolved.conf
    _print_result $? "Restored DNS config"

    sudo systemctl restart systemd-resolved
    _print_result $? "Restarted DNS service"

    _print_status "success" "NextDNS enabled"
    echo ""
}

cdns-off() {
    _print_header "DNS Config" ""

    sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak
    _print_result $? "Backed up DNS config"

    sudo truncate -s 0 /etc/systemd/resolved.conf
    _print_result $? "Cleared DNS config"

    sudo systemctl restart systemd-resolved
    _print_result $? "Restarted DNS service"

    _print_status "success" "Default DNS enabled"
    echo ""
}

upf() {
    local URL="https://raw.githubusercontent.com/yokoffing/Betterfox/main/user.js"
    local FF_DIR="$HOME/.config/mozilla/firefox"
    local REMOVALS="$ARCH_CONFIG_PATH/data/firefox/user-removals.txt"
    local TEMP_FILE="/tmp/betterfox_user.js"

    _print_header "Firefox Config" ""

    if ! curl -fsSL "$URL" -o "$TEMP_FILE" &>/dev/null; then
        _print_status "error" "Failed to download Betterfox"
        echo ""; return 1
    fi

    if [[ -f "$REMOVALS" ]]; then
        while IFS= read -r key; do
            [[ -z "$key" ]] && continue
            sed -i "/user_pref(\"${key}\"/d" "$TEMP_FILE"
        done < "$REMOVALS"
        _print_status "success" "Applied custom settings"
    else
        _print_status "warning" "No custom settings file found"
    fi

    local found=false
    while IFS= read -r times_file; do
        local profile_path
        profile_path=$(dirname "$times_file")
        if cp "$TEMP_FILE" "$profile_path/user.js"; then
            _print_status "success" "Updated profile: $(basename "$profile_path")"
        else
            _print_status "error" "Failed profile: $(basename "$profile_path")"
        fi
        found=true
    done < <(find "$FF_DIR" -maxdepth 2 -mindepth 2 -name "times.json")

    rm "$TEMP_FILE"
    [[ "$found" = false ]] && _print_status "error" "No Firefox profiles found"
    echo ""
}

upc() {
    _print_header "Config Sync" ""
    git -C "$ARCH_CONFIG_PATH" pull --rebase --autostash
    if [[ $? -eq 0 ]]; then
        _print_status "success" "Config synced"
        echo ""
        echo -e "${NORD_YELLOW}run 'reload' to apply changes"
        echo ""
    else
        _print_status "error" "Sync failed"
        echo ""
        return 1
    fi
}

upall() {
    upp && upf && upwp && upc
}

upp() {
    local repos=$(pacman -Sl 2>/dev/null | awk '{print $1}' | sort -u)
    local choices
    choices=$(printf "%s\nAUR" "$repos" | \
        fzf --multi --bind=ctrl-a:toggle-all \
            --header "Upgrade Packages (TAB: select | CTRL-A: toggle all):" --height=12 --no-info --no-sort --no-input)
    [[ -z "$choices" ]] && return 0

    if [[ -n "$(grep -v '^AUR$' <<< "$choices")" ]]; then
        sudo pacman -Sy --noconfirm &>/dev/null
        [[ $? -eq 0 ]] || _print_status "error" "Failed to sync package database"
    fi

    local label
    while IFS= read -r label; do
        label=$(xargs <<< "$label")
        [[ -z "$label" ]] && continue
        echo ""
        _print_header "Upgrading Packages: $label" ""
        case "$label" in
            AUR) yay -Sua --noconfirm ;;
            *)
                local repo_pkgs=$(pacman -Sl "$label" 2>/dev/null | awk '{print $2}')
                local to_upgrade=$(checkupdates 2>/dev/null | awk '{print $1}' | grep -Fwf <(echo "$repo_pkgs"))
                if [[ -z "$to_upgrade" ]]; then
                    _print_status "success" "Packages up to date"
                else
                    sudo pacman -S --noconfirm $to_upgrade
                fi
                ;;
        esac
    done <<< "$choices"
    echo ""
}

up-mirrors() {
    _print_header "Mirror Update" ""
    sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
    sudo pacman -Syyu
    _print_result $? "Mirrors updated"
    echo ""
}

open() {
    local target="${1:-.}"
    echo -e "${NORD_CYAN}Opening...${RST}"
    xdg-open "$target" >/dev/null 2>&1
}

sz() {
    local target="${1:-.}"
    if [[ ! -e "$target" ]]; then
        echo -e "${NORD_RED}Not found: $target${RST}"
        return 1
    fi
    local size=$(du -sh "$target" 2>/dev/null | cut -f1)
    _print_header "Disk Usage" ""
    _print_status "info" "$target: $size"
    echo ""
}

trash() {
    if [[ $# -eq 0 ]]; then
        _print_status "warning" "Usage: trash <file/folder>..."
        return 1
    fi

    local trash_files="$HOME/.local/share/Trash/files"
    local trash_info="$HOME/.local/share/Trash/info"
    mkdir -p "$trash_files" "$trash_info"

    local item
    for item in "$@"; do
        if [[ ! -e "$item" && ! -L "$item" ]]; then
            _print_status "error" "Not found: $item"
            continue
        fi

        local abs_path base name n=0
        abs_path=$(realpath -m "$item")
        base=$(basename "$item")
        name="$base"
        while [[ -e "$trash_files/$name" || -e "$trash_info/$name.trashinfo" ]]; do
            (( n++ ))
            name="${base}_$n"
        done

        printf '[Trash Info]\nPath=%s\nDeletionDate=%s\n' "$abs_path" "$(date +%Y-%m-%dT%H:%M:%S)" > "$trash_info/$name.trashinfo"

        if mv -- "$item" "$trash_files/$name"; then
            _print_status "success" "Trashed: $item"
        else
            _print_status "error" "Failed to trash: $item"
            rm -f "$trash_info/$name.trashinfo"
        fi
    done
}

ff() {
    local search_path="${1:-/}"
    if [[ ! -d "$search_path" ]]; then
        echo -e "${NORD_RED}Directory not found: $search_path${RST}"
        return 1
    fi

    local selection=$(find "$search_path" 2>/dev/null | fzf \
        --height=40% \
        --no-border \
        --header="Searching: $search_path")

    [[ -z "$selection" ]] && return 0

    local quoted="\"$selection\""
    echo -n "$quoted" | xclip -selection clipboard
    echo -e "${NORD_CYAN}Copied: ${NORD_SNOW_1}$selection${RST}"
}

upwp() {
    local WALLPAPERS_DIR="$HOME/Pictures/config-wallpapers"
    if [[ ! -d "$WALLPAPERS_DIR" ]]; then
        _print_header "Wallpapers" ""
        _print_status "error" "Directory not found"
        echo ""; return 1
    fi

    _print_header "Wallpapers" ""
    git -C "$WALLPAPERS_DIR" pull --rebase --autostash
    _print_result $? "Pulled updates"
    echo ""
}

sys

