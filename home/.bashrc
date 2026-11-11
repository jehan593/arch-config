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

missing_deps=$(_test_dependencies fzf yay git curl xclip checkupdates paccache reflector xdg-open)
if [[ -n "$missing_deps" ]]; then
    for dep in $missing_deps; do
        printfc "$NORD_RED" "Missing dependency: %s" "$dep"
    done
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
BETTERFOX_HASH_FILE="$HOME/.config/arch-config-files/firefox/betterfox_hash.txt"

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

# System Functions
sys() {
    local total_pkgs=$(pacman -Qq | wc -l)
    local ker=$(uname -r | cut -d '-' -f1)
    local mem=$(free -h | awk '/^Mem:/ {print $3 " / " $2}')
    local uptime=$(uptime -p | sed 's/up //')
    local age=$(aage)
    [[ "$age" -eq 1 ]] && age="$age day" || age="$age days"

    local f="  %s  %-12s %s"
    echo ""
    printfc "$NORD_SNOW_1" "$f" "󱑎" "Uptime"   "$uptime"
    printfc "$NORD_SNOW_1" "$f" "󰟾" "Kernel"   "$ker"
    printfc "$NORD_SNOW_1" "$f" "󰏖" "Packages" "$total_pkgs"
    printfc "$NORD_SNOW_1" "$f" "󰍛" "Memory"   "$mem"
    printfc "$NORD_SNOW_1" "$f" "󰃭" "OS Age"   "$age"

    if [[ -f "$IDEAPAD_CONSERVATION" ]]; then
        local status
        [[ $(< "$IDEAPAD_CONSERVATION") -eq 1 ]] && status="80% (Conservation Mode)" || status="100% (Full Charge)"
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
                    printfc "$NORD_GREEN" "Conservation mode on (80%% limit)"
                else
                    printfc "$NORD_RED" "Failed to turn on conservation mode"
                fi
                ;;
            off)
                if echo 0 | sudo tee "$IDEAPAD_CONSERVATION" > /dev/null; then
                    printfc "$NORD_GREEN" "Conservation mode off"
                else
                    printfc "$NORD_RED" "Failed to turn off conservation mode"
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
}

_build_betterfox_userjs() {
    local out="$1" key
    local url="https://raw.githubusercontent.com/yokoffing/Betterfox/main/user.js"
    local cache="$HOME/.cache/arch-config/betterfox-user.js"
    local part="$cache.part"
    mkdir -p "$(dirname "$cache")"
    if ! curl -fsSL -z "$cache" "$url" -o "$part" &>/dev/null; then
        rm -f "$part"
        return 1
    fi
    [[ -s "$part" ]] && mv -f "$part" "$cache"
    rm -f "$part"
    [[ -f "$cache" ]] || return 1
    cp "$cache" "$out" || return 1
    if [[ -f "$ARCH_CONFIG_PATH/data/firefox/user-removals.txt" ]]; then
        while IFS= read -r key; do
            [[ -z "$key" ]] && continue
            sed -i "/user_pref(\"${key}\"/d" "$out"
        done < "$ARCH_CONFIG_PATH/data/firefox/user-removals.txt"
    fi
    if [[ -f "$ARCH_CONFIG_PATH/data/firefox/user-overrides.js" ]]; then
        printf '\n' >> "$out"
        cat "$ARCH_CONFIG_PATH/data/firefox/user-overrides.js" >> "$out"
    fi
}

_betterfox_profile_dirs() {
    find "$HOME/.config/mozilla/firefox" -maxdepth 2 -mindepth 2 -name "times.json" 2>/dev/null -printf '%h\n'
}

_betterfox_profile_current() {
    local expected="$1" profile_dir="$2"
    [[ -f "$profile_dir/user.js" ]] || return 1
    [[ "$(sha256sum "$profile_dir/user.js" | awk '{print $1}')" == "$expected" ]]
}

_git_behind_status() {
    local repo_path="$1" label="$2" behind
    if [[ ! -d "$repo_path/.git" ]]; then
        printf '%s|missing\n' "$label"
        return 0
    fi
    if ! git -C "$repo_path" fetch --quiet &>/dev/null; then
        printf '%s|fetchfail\n' "$label"
        return 0
    fi
    if ! behind=$(git -C "$repo_path" rev-list --count 'HEAD..@{u}' 2>/dev/null); then
        printf '%s|noupstream\n' "$label"
        return 0
    fi
    printf '%s|%s\n' "$label" "$behind"
}

_print_pkg_updates() {
    local repo pkg line count=0 afd
    exec {afd}< <(yay -Qua 2>/dev/null </dev/null)
    local all_updates=$(pacman -Qu 2>/dev/null | grep -v '\[.*\]')
    local aur_updates=$(cat <&"$afd")
    exec {afd}<&-
    PKG_UPDATE_COUNT=0

    if [[ -z "$all_updates" && -z "$aur_updates" ]]; then
        return 0
    fi
    printfc "$NORD_BLUE" "\n>Packages"
    if [[ -n "$all_updates" ]]; then
        local pkgs=($(echo "$all_updates" | awk '{print $1}'))
        declare -A pkg_repo
        while read -r repo pkg; do
            pkg_repo["$pkg"]="$repo"
        done < <(pacman -Sp --print-format '%r %n' "${pkgs[@]}" 2>/dev/null)

        declare -A repo_updates
        while IFS= read -r line; do
            read -r pkg _ <<< "$line"
            repo="${pkg_repo[$pkg]}"
            [[ -z "$repo" ]] && continue
            repo_updates["$repo"]+="$line"$'\n'
        done <<< "$all_updates"

        local sorted_repos=($(echo "${!repo_updates[@]}" | tr ' ' '\n' | sort))
        local ri ver
        for ri in "${!sorted_repos[@]}"; do
            repo="${sorted_repos[$ri]}"
            [[ "$ri" -gt 0 ]] && echo ""
            printfc "$NORD_SNOW_1" " >%s" "$repo"
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                read -r pkg ver <<< "$line"
                printfc "$NORD_YELLOW" " %s $NORD_SNOW_1[%s]" "$pkg" "$ver"
                ((count++))
            done <<< "${repo_updates[$repo]}"
        done
    fi
    if [[ -n "$aur_updates" ]]; then
        printfc "$NORD_SNOW_1" "\n >AUR"
        while read -r line; do
            [[ -z "$line" ]] && continue
            read -r pkg ver <<< "$line"
            printfc "$NORD_YELLOW" " %s $NORD_SNOW_1[%s]" "$pkg" "$ver"
            ((count++))
        done <<< "$aur_updates"
    fi
    PKG_UPDATE_COUNT="$count"
}

cup() {
    local sync_ok=true
    if ! sudo pacman -Sy --noconfirm &>/dev/null; then
        printfc "$NORD_RED" "Failed to sync package database"
        echo ""
        sync_ok=false
    fi
    local count=0 entry repo_url repo_dest repo_path repo_name i=0
    local sl s_label s_val s_total=0 s_err_total=0
    local -a st_behind=() st_err=()
    local bf_new bf_dir bf_p bf_global_new=false bf_behind=()
    local tmpd bgfd
    tmpd=$(mktemp -d) || return 1
    exec {bgfd}< <(
        set +m
        ( _build_betterfox_userjs "$tmpd/betterfox.js" && touch "$tmpd/betterfox.ok" ) </dev/null &
        for (( i = 0; i < ${#CLONE_REPOS[@]}; i++ )); do
            IFS='|' read -r repo_url repo_dest <<< "${CLONE_REPOS[$i]}"
            repo_path="${repo_dest/#\~/$HOME}"
            repo_name="${repo_url##*/}"
            repo_name="${repo_name%.git}"
            ( _git_behind_status "$repo_path/$repo_name" "$repo_name" > "$tmpd/repo.$i" ) </dev/null &
        done
        ( _git_behind_status "$ARCH_CONFIG_PATH" "arch-config" > "$tmpd/arch" ) </dev/null &
        wait
    )

    if [[ "$sync_ok" == true ]]; then
        _print_pkg_updates
        count="$PKG_UPDATE_COUNT"
    fi

    if [[ "$count" -gt 0 ]]; then
        printfc "$NORD_YELLOW" "\n%d update(s) available" "$count"
    elif [[ "$sync_ok" == true ]]; then
        printfc "$NORD_BLUE" "\n>Packages"
        printfc "$NORD_GREEN" "Up to date"
    fi

    cat <&"$bgfd" >/dev/null
    exec {bgfd}<&-

    printfc "$NORD_BLUE" "\n>Betterfox"
    if [[ -f "$tmpd/betterfox.ok" ]]; then
        bf_new=$(sha256sum "$tmpd/betterfox.js" | awk '{print $1}')
        if [[ ! -f "$BETTERFOX_HASH_FILE" ]] || [[ "$(cat "$BETTERFOX_HASH_FILE")" != "$bf_new" ]]; then
            bf_global_new=true
        fi
        while IFS= read -r bf_dir; do
            _betterfox_profile_current "$bf_new" "$bf_dir" || bf_behind+=("$(basename "$bf_dir")")
        done < <(_betterfox_profile_dirs)
        if [[ "${#bf_behind[@]}" -eq 0 ]]; then
            printfc "$NORD_GREEN" "Up to date"
        elif [[ "$bf_global_new" == true ]]; then
            printfc "$NORD_YELLOW" "Update available, run 'upf'"
        else
            printfc "$NORD_YELLOW" "New or outdated profile(s), run 'upf'"
            for bf_p in "${bf_behind[@]}"; do
                printfc "$NORD_YELLOW" " %s" "$bf_p"
            done
        fi
    else
        printfc "$NORD_RED" "Check failed: could not download Betterfox"
    fi

    printfc "$NORD_BLUE" "\n>Cloned Repos"
    for (( i = 0; i < ${#CLONE_REPOS[@]}; i++ )); do
        sl=$(< "$tmpd/repo.$i")
        IFS='|' read -r s_label s_val <<< "$sl"
        if [[ "$s_val" =~ ^[0-9]+$ ]]; then
            if (( s_val > 0 )); then
                st_behind+=("$s_label|$s_val")
                ((s_total += s_val))
            fi
        else
            st_err+=("$s_label|$s_val")
            ((s_err_total++))
        fi
    done

    if (( ${#st_behind[@]} > 0 )); then
        local sb bv bsl
        for sl in "${st_behind[@]}"; do
            IFS='|' read -r sb bv <<< "$sl"
            printfc "$NORD_YELLOW" "%s %d commit(s) behind, run 'uprep'" "$sb" "$bv"
        done
        printfc "$NORD_YELLOW" "%d update(s) available" "$s_total"
    elif (( s_err_total > 0 )); then
        local se ev esl
        for sl in "${st_err[@]}"; do
            IFS='|' read -r se ev <<< "$sl"
            case "$ev" in
                missing)     printfc "$NORD_YELLOW" "%s not found" "$se" ;;
                noupstream)  printfc "$NORD_YELLOW" "%s has no upstream branch" "$se" ;;
                fetchfail)   printfc "$NORD_RED" "%s fetch failed" "$se" ;;
            esac
        done
    else
        printfc "$NORD_GREEN" "Up to date"
    fi

    printfc "$NORD_BLUE" "\n>Arch Config"
    sl=$(< "$tmpd/arch")
    IFS='|' read -r s_label s_val <<< "$sl"
    if [[ "$s_val" =~ ^[0-9]+$ ]]; then
        if (( s_val > 0 )); then
            printfc "$NORD_YELLOW" "%s %d commit(s) behind, run 'upc'" "$s_label" "$s_val"
        else
            printfc "$NORD_GREEN" "Up to date"
        fi
    else
        case "$s_val" in
            missing)     printfc "$NORD_YELLOW" "%s not found" "$s_label" ;;
            noupstream)  printfc "$NORD_YELLOW" "%s has no upstream branch" "$s_label" ;;
            fetchfail)   printfc "$NORD_RED" "%s fetch failed" "$s_label" ;;
        esac
    fi
    rm -rf "$tmpd"
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
                cache="$HOME/.cache/arch-config/inst-preview/$repo-$pkg"
                if [ ! -s "$cache" ] || [ -n "$(find "$cache" -mmin +1440 2>/dev/null)" ]; then
                    mkdir -p "$(dirname "$cache")"
                    if [ "$repo" = "aur" ]; then yay -Siai "$pkg" 2>/dev/null; else yay -Sii "$pkg"; fi > "$cache.tmp"
                    [ -s "$cache.tmp" ] && mv -f "$cache.tmp" "$cache"
                    rm -f "$cache.tmp"
                fi
                awk "/^(Votes|Popularity)/ { stats = stats \"$NORD_YELLOW\" \$0 \"$RST\n\" } !/^(Votes|Popularity)/ { body = body \$0 \"\n\" } END { printf \"%s%s\", stats, body }" "$cache" 2>/dev/null
            ')
        [[ -z "$selected" ]] && return 0
        local pkgs
        pkgs=$(echo "$selected" | awk -F/ '{print $2}' | paste -sd' ')
        _record_history "yay -S ${pkgs}"
        yay -S --noconfirm $pkgs
    fi
}

_pkg_list() {
    local listing
    listing=$({
        pacman -Sl 2>/dev/null | awk '/\[installed\]/ { print $1 "/" $2 }' | sort -s -t/ -k1,1
        pacman -Qm | awk '{print "aur/"$1}'
    })
    awk 'NR == FNR { explicit[$0] = 1; next }
        { pkg = $0; sub(/^[^\/]*\//, "", pkg); print (pkg in explicit ? "  " : "* ") $0 }' \
        <(pacman -Qeq) - <<< "$listing"
}

uinst() {
    if [[ $# -gt 0 ]]; then
        printfc "$NORD_BLUE" "\n>Uninstalling"
        sudo pacman -Rns "$@"
        _record_history "sudo pacman -Rns $*"
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
    local temp_file new_hash profile_dir updated=0 current=0 failed=0

    printfc "$NORD_BLUE" "\n>Firefox Config"

    temp_file=$(mktemp)
    if [[ -z "$temp_file" ]] || ! _build_betterfox_userjs "$temp_file"; then
        rm -f "$temp_file"
        printfc "$NORD_RED" "Failed to download Betterfox"
        return 1
    fi

    new_hash=$(sha256sum "$temp_file" | awk '{print $1}')

    while IFS= read -r profile_dir; do
        if _betterfox_profile_current "$new_hash" "$profile_dir"; then
            ((current++))
            continue
        fi
        if cp "$temp_file" "$profile_dir/user.js"; then
            printfc "$NORD_GREEN" "Updated profile: %s" "$(basename "$profile_dir")"
            ((updated++))
        else
            printfc "$NORD_RED" "Failed profile: %s" "$(basename "$profile_dir")"
            ((failed++))
        fi
    done < <(_betterfox_profile_dirs)

    rm -f "$temp_file"

    local total=$((updated + current + failed))
    if [[ "$total" -eq 0 ]]; then
        printfc "$NORD_RED" "No Firefox profiles found"
        return 1
    fi

    if [[ "$current" -gt 0 ]]; then
        printfc "$NORD_GREEN" "%d profile(s) already up to date" "$current"
    fi
    if [[ "$updated" -gt 0 ]]; then
        mkdir -p "$(dirname "$BETTERFOX_HASH_FILE")"
        printf '%s' "$new_hash" > "$BETTERFOX_HASH_FILE"
    fi
    if [[ "$updated" -eq 0 && "$failed" -gt 0 ]]; then
        printfc "$NORD_RED" "Failed to update profile(s)"
        return 1
    fi
}

upc() {
    printfc "$NORD_BLUE" "\n>Config Sync"
    if git -C "$ARCH_CONFIG_PATH" pull --rebase --autostash; then
        printfc "$NORD_GREEN" "Config synced"
        echo ""
        printfc "$NORD_YELLOW" "Run 'reload' to apply changes"
    else
        printfc "$NORD_RED" "Sync failed"
        return 1
    fi
}

uprep() {
    printfc "$NORD_BLUE" "\n>Repo Sync"
    local found=false updated=0 i=0
    local entry repo_url repo_dest repo_path repo_name
    local sl s_label s_val
    local tmpd bgfd
    tmpd=$(mktemp -d) || return 1
    exec {bgfd}< <(
        set +m
        for (( i = 0; i < ${#CLONE_REPOS[@]}; i++ )); do
            IFS='|' read -r repo_url repo_dest <<< "${CLONE_REPOS[$i]}"
            repo_path="${repo_dest/#\~/$HOME}"
            repo_name="${repo_url##*/}"
            repo_name="${repo_name%.git}"
            repo_path="$repo_path/$repo_name"
            if [[ -d "$repo_path/.git" ]]; then
                ( _git_behind_status "$repo_path" "$repo_name" > "$tmpd/repo.$i" ) </dev/null &
            fi
        done
        wait
    )
    cat <&"$bgfd" >/dev/null
    exec {bgfd}<&-

    for (( i = 0; i < ${#CLONE_REPOS[@]}; i++ )); do
        IFS='|' read -r repo_url repo_dest <<< "${CLONE_REPOS[$i]}"
        repo_path="${repo_dest/#\~/$HOME}"
        repo_name="${repo_url##*/}"
        repo_name="${repo_name%.git}"
        repo_path="$repo_path/$repo_name"

        if [[ -d "$repo_path/.git" ]]; then
            found=true
            sl=$(< "$tmpd/repo.$i")
            IFS='|' read -r s_label s_val <<< "$sl"
            if [[ "$s_val" =~ ^[0-9]+$ ]] && (( s_val == 0 )); then
                continue
            fi
            printfc "$NORD_YELLOW" "Pulling %s..." "$repo_name"
            if git -C "$repo_path" pull --rebase --autostash; then
                printfc "$NORD_GREEN" "Updated %s" "$repo_name"
                ((updated++))
            else
                printfc "$NORD_RED" "Failed to update %s." "$repo_name"
            fi
        fi
    done
    rm -rf "$tmpd"
    if [[ "$found" == false ]]; then
        printfc "$NORD_YELLOW" "No cloned repos found — run setup.sh to clone them."
    elif (( updated == 0 )); then
        printfc "$NORD_GREEN" "All repos up to date"
    else
        printfc "$NORD_YELLOW" "%d repo(s) updated" "$updated"
    fi
}

upall() {
    upp && upf && uprep && upc
}

upp() {
    sudo pacman -Sy --noconfirm &>/dev/null
    _print_pkg_updates
    echo ""
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
    if sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist; then
        printfc "$NORD_GREEN" "Mirrors updated"
        sudo pacman -Syyu || printfc "$NORD_RED" "Failed to sync or upgrade packages"
    else
        printfc "$NORD_RED" "Failed to update mirrors"
        return 1
    fi
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

cleanimg() {
    if [[ $# -eq 0 ]]; then
        printfc "$NORD_YELLOW" "Usage: cleanimg <image>..."
        return 1
    fi
    if ! command -v exiftool &>/dev/null; then
        printfc "$NORD_RED" "exiftool not found"
        return 1
    fi

    local img dir ext rand new
    for img in "$@"; do
        if [[ ! -f "$img" ]]; then
            printfc "$NORD_RED" "Not found: %s" "$img"
            continue
        fi
        if ! exiftool -q -all= -overwrite_original -- "$img"; then
            printfc "$NORD_RED" "Failed to clean: %s" "$img"
            continue
        fi

        dir=$(dirname -- "$img")
        ext="${img##*.}"
        [[ "$ext" == "$img" ]] && ext="" || ext=".$ext"
        rand=$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 12)
        new="$dir/$rand$ext"
        while [[ -e "$new" ]]; do
            rand=$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 12)
            new="$dir/$rand$ext"
        done

        if mv -- "$img" "$new"; then
            printfc "$NORD_GREEN" "Cleaned and renamed: %s -> %s" "$img" "$new"
        else
            printfc "$NORD_RED" "Cleaned but failed to rename: %s" "$img"
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

bpm() {
    if ! command -v curl &>/dev/null; then
        printfc "$NORD_RED" "curl not found"
        return 1
    fi

    (
        local tmp
        tmp=$(mktemp) || exit 1
        trap 'rm -f "$tmp"' EXIT
        if ! curl -fsSL -o "$tmp" https://raw.githubusercontent.com/jehan593/brave-profile-manager/main/brave-profile-manager.sh; then
            printfc "$NORD_RED" "Failed to download brave-profile-manager"
            exit 1
        fi
        bash "$tmp" "$@"
    )
}

sys
