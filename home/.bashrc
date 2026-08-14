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

source "$ARCH_CONFIG_PATH/helpers/colors-nord.sh"
source "$ARCH_CONFIG_PATH/helpers/printer.sh"
source "$ARCH_CONFIG_PATH/helpers/dep-checker.sh"
source "$ARCH_CONFIG_PATH/helpers/repo-list.sh"

if ! _test_dependencies fzf yay git curl xclip checkupdates paccache reflector xdg-open; then
    PS1='[\u@\h \W]\$ '
    return
fi

export EDITOR='nvim'
export MANROFFOPT="-c"
export TERM=xterm-256color
export HISTSIZE=-1
export HISTFILESIZE=-1
export PATH="$HOME/.local/bin:$PATH"
export HISTCONTROL=ignoredups:erasedups
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
    local cmd="" line
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
alias rmf='rm -f'
alias cpr='cp -r'
alias cpa='cp -a'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias clear='clear && sys'
alias reload='source ~/.bashrc && printfc "$NORD_GREEN" "Profile reloaded"'
aage() {
    echo $(( ($(date +%s) - $(stat -c %Y /lost+found 2>/dev/null || stat -c %Y /)) / 86400 ))
}
rr() {
    local cmd
    cmd=$(HISTTIMEFORMAT='' history 2 | head -1 | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//')
    printfc "$NORD_SNOW_1" "Sudo: %s" "$cmd"
    sudo -E bash -c "
        shopt -s expand_aliases
        $(alias)
        $(declare -f)
        $cmd
    "
}
alias conf='[[ -x $(command -v zeditor) ]] && (printfc "$NORD_YELLOW" "Opening configs..." && zeditor "$ARCH_CONFIG_PATH/") || printfc "$NORD_RED" "Zed not found"'

# System Functions (Icons explicitly kept here)
sys() {
    local total_pkgs=$(pacman -Qq | wc -l)
    local ker=$(uname -r | cut -d '-' -f1)
    local mem=$(free -h | awk '/^Mem:/ {print $3 " / " $2}')
    local uptime=$(uptime -p | sed 's/up //')
    local age=$(aage)

    local f="  %s  %-12s %s"
    echo ""
    printfc "$NORD_SNOW_1" "$f" "󱑎" "Uptime"   "$uptime"
    printfc "$NORD_SNOW_1" "$f" "󰟾" "Kernel"   "$ker"
    printfc "$NORD_SNOW_1" "$f" "󰏖" "Packages" "$total_pkgs"
    printfc "$NORD_SNOW_1" "$f" "󰍛" "Memory"   "$mem"
    printfc "$NORD_SNOW_1" "$f" "󰃭" "OS Age"   "$age days"

    if [[ -f "$IDEAPAD_CONSERVATION" ]]; then
        local status
        [[ $(< "$IDEAPAD_CONSERVATION") -eq 1 ]] && status="Conservation Mode (80%)" || status="Full Charge (100%)"
        printfc "$NORD_SNOW_1" "$f" "󱊟" "Battery" "$status"
    fi
    printfc "$NORD_SNOW_1" "$f" "󰒍" "Shell" "Bash ${BASH_VERSION%%(*}"

    echo ""
}

if [[ -f "$IDEAPAD_CONSERVATION" ]]; then
    cons-mode() {
        local action="$1"
        case "$action" in
            on)
                if echo 1 | sudo tee "$IDEAPAD_CONSERVATION" > /dev/null; then
                    printfc "$NORD_GREEN" "Conservation mode enabled (80%% limit)"
                else
                    printfc "$NORD_RED" "Failed to enable conservation mode"
                fi
                ;;
            off)
                if echo 0 | sudo tee "$IDEAPAD_CONSERVATION" > /dev/null; then
                    printfc "$NORD_GREEN" "Full charge enabled"
                else
                    printfc "$NORD_RED" "Failed to enable full charge"
                fi
                ;;
            *)
                printfc "$NORD_RED" "Usage: cons-mode {on|off}"
                return 1
                ;;
        esac
        echo ""
    }
fi

# Package Management
cleanup() {
    printfc "$NORD_BLUE" "\n>System Cleanup"

    if sudo rm -rf /var/cache/pacman/pkg/download-*; then
        printfc "$NORD_GREEN" "Cleared partial downloads"
    else
        printfc "$NORD_RED" "Failed to clear partial downloads"
    fi

    if rm -f ~/.bash_history-*.tmp; then
        printfc "$NORD_GREEN" "Cleared history temp files"
    else
        printfc "$NORD_RED" "Failed to clear history temp files"
    fi

    if yay -Sc --noconfirm; then
        printfc "$NORD_GREEN" "Cleared AUR cache"
    else
        printfc "$NORD_RED" "Failed to clear AUR cache"
    fi

    if yay -Yc --noconfirm; then
        printfc "$NORD_GREEN" "Cleared AUR orphans"
    else
        printfc "$NORD_RED" "Failed to clear AUR orphans"
    fi

    if sudo paccache -rk2; then
        printfc "$NORD_GREEN" "Cleared old Pacman cache (kept 2)"
    else
        printfc "$NORD_RED" "Failed to clear old Pacman cache"
    fi

    if sudo paccache -ruk0; then
        printfc "$NORD_GREEN" "Cleared uninstalled pkg cache"
    else
        printfc "$NORD_RED" "Failed to clear uninstalled pkg cache"
    fi

    if rm -rf ~/.cache/yay/*; then
        printfc "$NORD_GREEN" "Cleared AUR build cache"
    else
        printfc "$NORD_RED" "Failed to clear AUR build cache"
    fi

    if rm -rf ~/.local/share/Trash/files ~/.local/share/Trash/info && mkdir -p ~/.local/share/Trash/files ~/.local/share/Trash/info; then
        printfc "$NORD_GREEN" "Emptied trash"
    else
        printfc "$NORD_RED" "Failed to empty trash"
    fi

    printfc "$NORD_SNOW_1" "Remaining cache: %s" "$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1)"
    echo ""
}

cup() {
    if ! sudo pacman -Sy --noconfirm &>/dev/null; then
        printfc "$NORD_RED" "Failed to sync package database"
        echo ""
        return 1
    fi
    local any=false repo pkg line
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
            pkg=$(echo "$line" | awk '{print $1}')
            repo="${pkg_repo[$pkg]}"
            [[ -z "$repo" ]] && continue
            repo_updates["$repo"]+="$line"$'\n'
        done <<< "$all_updates"

        for repo in $(echo "${!repo_updates[@]}" | tr ' ' '\n' | sort); do
            any=true
            printfc "$NORD_BLUE" "\n>%s" "$repo"
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                local pkg=$(awk '{print $1}' <<< "$line")
                local ver=$(awk '{$1=""; print $0}' <<< "$line" | xargs)
                printfc "$NORD_GREEN" "%-35s %s" "$pkg" "$ver"
            done <<< "${repo_updates[$repo]}"
            echo ""
        done
    fi

    if [[ -n "$aur_updates" ]]; then
        any=true
        printfc "$NORD_BLUE" "\n>AUR"
        echo "$aur_updates" | while read -r line; do
            local pkg=$(awk '{print $1}' <<< "$line")
            local ver=$(awk '{$1=""; print $0}' <<< "$line" | xargs)
            printfc "$NORD_GREEN" "%-35s %s" "$pkg" "$ver"
        done
        echo ""
    fi

    [[ "$any" == false ]] && printfc "$NORD_GREEN" "System is up to date"
    echo ""
}

_record_history() {
    history -s "$1"
    history -a
}

inst() {
    if [[ "$1" == "-refresh" ]]; then
        printfc "$NORD_YELLOW" "Refreshing package list..."
        mkdir -p "$HOME/.config/arch-config-files/inst"
        yay -Sl 2>/dev/null | awk '{print $1"/"$2}' > "$HOME/.config/arch-config-files/inst/pkg-list.cache"
        printfc "$NORD_GREEN" "Package list updated"
        inst
        return 0
    fi
    if [[ $# -gt 0 ]]; then
        printfc "$NORD_BLUE" "\n>Installing"
        yay -S "$@"
        _record_history "yay -S $*"
        echo ""
    else
        local cache="$HOME/.config/arch-config-files/inst/pkg-list.cache"
        if [[ ! -f "$cache" ]] || [[ -n $(find "$cache" -mmin +10080 2>/dev/null) ]]; then
            printfc "$NORD_YELLOW" "Refreshing package list..."
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
                awk "/^(Votes|Popularity)/ { stats = stats \"$NORD_YELLOW\" \$0 \"$RST\n\" } !/^(Votes|Popularity)/ { body = body \$0 \"\n\" } END { printf \"%s%s\", stats, body }"
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
        printfc "$NORD_BLUE" "\n>Uninstalling"
        sudo pacman -Rns "$@"
        _record_history "sudo pacman -Rns $*"
        echo ""
    else
        local selected
        selected=$(_pkg_list | fzf --multi \
            --preview-window=right:50%:hidden \
            --bind=ctrl-a:toggle-all \
            --header "Initially Installed (*: Explicit) | CTRL-P: Preview | CTRL-A: toggle all" \
            --preview 'echo {} | awk -F/ "{print \$2}" | xargs yay -Qi 2>/dev/null | awk "/^(Install Date|Installed Size)/ { stats = stats \"$NORD_RED\" \$0 \"$RST\n\" } !/^(Install Date|Installed Size)/ { body = body \$0 \"\n\" } END { printf \"%s%s\", stats, body }"')
        [[ -z "$selected" ]] && return 0
        local pkgs
        pkgs=$(echo "$selected" | awk '{print $NF}' | awk -F/ '{print $2}' | paste -sd' ')
        _record_history "sudo pacman -Rns ${pkgs}"
        sudo pacman -Rns $pkgs
    fi
}

upf() {
    local URL="https://raw.githubusercontent.com/yokoffing/Betterfox/main/user.js"
    local FF_DIR="$HOME/.config/mozilla/firefox"
    local REMOVALS="$ARCH_CONFIG_PATH/data/firefox/user-removals.txt"
    local OVERRIDES="$ARCH_CONFIG_PATH/data/firefox/user-overrides.js"
    local TEMP_FILE="/tmp/betterfox_user.js"
    local key times_file profile_path

    printfc "$NORD_BLUE" "\n>Firefox Config"

    if ! curl -fsSL "$URL" -o "$TEMP_FILE" &>/dev/null; then
        printfc "$NORD_RED" "Failed to download Betterfox"
        echo ""; return 1
    fi

    if [[ -f "$REMOVALS" ]]; then
        while IFS= read -r key; do
            [[ -z "$key" ]] && continue
            sed -i "/user_pref(\"${key}\"/d" "$TEMP_FILE"
        done < "$REMOVALS"
        printfc "$NORD_GREEN" "Applied custom settings"
    else
        printfc "$NORD_YELLOW" "No custom settings file found"
    fi

    if [[ -f "$OVERRIDES" ]]; then
        printf '\n' >> "$TEMP_FILE"
        cat "$OVERRIDES" >> "$TEMP_FILE"
        printfc "$NORD_GREEN" "Applied overrides"
    else
        printfc "$NORD_YELLOW" "No overrides file found"
    fi

    local found=false
    while IFS= read -r times_file; do
        profile_path=$(dirname "$times_file")
        if cp "$TEMP_FILE" "$profile_path/user.js"; then
            printfc "$NORD_GREEN" "Updated profile: %s" "$(basename "$profile_path")"
        else
            printfc "$NORD_RED" "Failed profile: %s" "$(basename "$profile_path")"
        fi
        found=true
    done < <(find "$FF_DIR" -maxdepth 2 -mindepth 2 -name "times.json")

    rm "$TEMP_FILE"
    [[ "$found" = false ]] && printfc "$NORD_RED" "No Firefox profiles found"
    echo ""
}

upc() {
    printfc "$NORD_BLUE" "\n>Config Sync"
    if git -C "$ARCH_CONFIG_PATH" pull --rebase --autostash; then
        printfc "$NORD_GREEN" "Config synced"
        echo ""
        printfc "$NORD_YELLOW" "run 'reload' to apply changes"
        echo ""
    else
        printfc "$NORD_RED" "Sync failed"
        echo ""
        return 1
    fi
}

uprep() {
    printfc "$NORD_BLUE" "\n>Repo Sync"
    local found=false
    for entry in "${CLONE_REPOS[@]}"; do
        IFS='|' read -r repo_url repo_dest <<< "$entry"
        local repo_path="${repo_dest/#\~/$HOME}"
        local repo_name="${repo_url##*/}"
        repo_name="${repo_name%.git}"
        repo_path="$repo_path/$repo_name"

        if [[ -d "$repo_path/.git" ]]; then
            found=true
            printfc "$NORD_YELLOW" "Pulling %s..." "$repo_name"
            if git -C "$repo_path" pull --rebase --autostash; then
                printfc "$NORD_GREEN" "Updated %s" "$repo_name"
            else
                printfc "$NORD_RED" "Failed to update %s." "$repo_name"
            fi
        fi
    done
    [[ "$found" = false ]] && printfc "$NORD_YELLOW" "No cloned repos found — run setup.sh to clone them."
    echo ""
}

upall() {
    upp && upf && uprep && upc
}

upp() {
    echo ""
    printfc "$NORD_BLUE" ">Upgrading Packages: All repos"
    if sudo pacman -Syu --noconfirm; then
        echo ""
        printfc "$NORD_BLUE" ">Upgrading Packages: AUR"
        yay -Sua --noconfirm
        echo ""
        return 0
    else
        printfc "$NORD_RED" "Failed to upgrade repo packages"
        echo ""
        return 1
    fi
}

up-mirrors() {
    printfc "$NORD_BLUE" "\n>Mirror Update"
    if sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist && sudo pacman -Syyu; then
        printfc "$NORD_GREEN" "Mirrors updated"
    else
        printfc "$NORD_RED" "Failed to update mirrors"
    fi
    echo ""
}

open() {
    local target="${1:-.}"
    printfc "$NORD_YELLOW" "Opening..."
    xdg-open "$target" >/dev/null 2>&1
}

sz() {
    local target="${1:-.}"
    if [[ ! -e "$target" ]]; then
        printfc "$NORD_RED" "Not found: %s" "$target"
        return 1
    fi
    local size=$(du -sh "$target" 2>/dev/null | cut -f1)
    printfc "$NORD_BLUE" "\n>Disk Usage"
    printfc "$NORD_SNOW_1" "%s: %s" "$target" "$size"
    echo ""
}

trash() {
    if [[ $# -eq 0 ]]; then
        printfc "$NORD_YELLOW" "Usage: trash <file/folder>..."
        return 1
    fi

    local trash_files="$HOME/.local/share/Trash/files"
    local trash_info="$HOME/.local/share/Trash/info"
    mkdir -p "$trash_files" "$trash_info"

    local item
    for item in "$@"; do
        if [[ ! -e "$item" && ! -L "$item" ]]; then
            printfc "$NORD_RED" "Not found: %s" "$item"
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
            printfc "$NORD_GREEN" "Trashed: %s" "$item"
        else
            printfc "$NORD_RED" "Failed to trash: %s" "$item"
            rm -f "$trash_info/$name.trashinfo"
        fi
    done
}

ff() {
    local search_path="${1:-/}"
    if [[ ! -d "$search_path" ]]; then
        printfc "$NORD_RED" "Directory not found: %s" "$search_path"
        return 1
    fi

    local selection=$(find "$search_path" 2>/dev/null | fzf \
        --height=40% \
        --no-border \
        --header="Searching: $search_path")

    [[ -z "$selection" ]] && return 0

    local quoted="\"$selection\""
    echo -n "$quoted" | xclip -selection clipboard
    printfc "$NORD_GREEN" "Copied: %s" "$selection"
}

sys
