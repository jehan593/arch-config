# ==============================================================================
# ARCH LINUX CUSTOM BASH CONFIGURATION (Nord Aesthetic)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. CORE SETUP & ENVIRONMENT
# ------------------------------------------------------------------------------
[[ $- != *i* ]] && return

export EDITOR='vim'
export VISUAL='zed'
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

_pass_thru() {
    while IFS= read -r line; do
        printf '\e[38;2;118;138;161m│  %s\e[0m\n' "$line"
    done
}

_run() {
    local label="$1"; shift
    local output
    output=$("$@" 2>&1)
    if [[ $? -eq 0 ]]; then
        [[ -n "$output" ]] && echo "$output" | _pass_thru
        _print_row "󰄬" "$label" "Done"
    else
        [[ -n "$output" ]] && echo "$output" | _pass_thru
        _print_row "󰅙" "$label" "Failed"
    fi
}

_info_msg() { printf "${NORD_POLAR_4}│${RST}  ${NORD_BLUE}[INFO]${RST}  %s\n" "$1"; }

IDEAPAD_CONSERVATION="/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"

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
command -v bat &>/dev/null && alias cat='bat'
alias clear='clear && sys'
alias reload='source ~/.bashrc && echo -e "${NORD_GREEN}󰑓  Profile Reloaded!${RST}"'
rr() { echo -e "${NORD_CYAN}󰮯  Elevating Last Command...${RST}"; sudo $(fc -ln -1); }
alias conf='[[ -x $(command -v zeditor) ]] && (echo -e "${NORD_CYAN}󱃖  Opening Configs...${RST}" && zeditor ~/arch-config/) || echo -e "${NORD_RED}󰅙  zed not found.${RST}"'
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

    _print_header "${NORD_CYAN}󰣇${RST}" "Arch Linux"
    _print_row "󱑎" "Uptime" "$uptime"
    _print_row "󰟾" "Kernel" "$ker"
    _print_row "󰏖" "Packages" "$total_pkgs"
    _print_row "󰍛" "Memory" "$mem"
    _print_row "󰃭" "OS Age" "$age days"

    if [[ -f "$IDEAPAD_CONSERVATION" ]]; then
        local status
        [[ $(< "$IDEAPAD_CONSERVATION") -eq 1 ]] && status="Conservation - ON" || status="Conservation - OFF"
        _print_row "󱊟" "Battery" "$status"
    fi
    _print_row "󰒍" "Shell" "Bash ${BASH_VERSION%%(*}"
    _print_footer

    echo -e "  ${NORD_YELLOW}󰋼 Run 'info' for custom commands${RST}\n"
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
    _run "Bash history temp" rm -f ~/.bash_history-*.tmp
    _run "Pkg list cache" rm -f ~/.cache/yay-pkg-list.cache
    _run "Yay cache" yay -Sc --noconfirm
    _run "Yay orphans" yay -Yc --noconfirm
    _run "Paccache keep 2" sudo paccache -rk2
    _run "Paccache uninstalled" sudo paccache -ruk0
    _run "Yay build cache" rm -rf ~/.cache/yay/*
    _print_row "󰋊" "Cache Size" "$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1)"
    _print_footer
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
        _print_header "${NORD_BLUE}󰏖${RST}" "$repo"
        echo "$updates" | while read -r line; do
            local pkg=$(echo "$line" | awk '{print $1}')
            local ver=$(echo "$line" | awk '{$1=""; print $0}' | xargs)
            printf "${NORD_POLAR_4}│${RST}  ${NORD_BLUE}󰚰${RST}  ${NORD_GREEN}%-40s${RST} ${NORD_SNOW_1}%s${RST}\n" "$pkg" "$ver"
        done
    done <<< "$repos"

    if [[ -n "$aur_updates" ]]; then
        any=true
        _print_header "${NORD_MAGENTA}󰏖${RST}" "AUR"
        echo "$aur_updates" | while read -r line; do
            local pkg=$(echo "$line" | awk '{print $1}')
            local ver=$(echo "$line" | awk '{$1=""; print $0}' | xargs)
            printf "${NORD_POLAR_4}│${RST}  ${NORD_BLUE}󰚰${RST}  ${NORD_GREEN}%-40s${RST} ${NORD_SNOW_1}%s${RST}\n" "$pkg" "$ver"
        done
    fi

    [[ "$any" == false ]] && echo -e "  ${NORD_GREEN}󰄬  All packages up to date${RST}"
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
        _print_header "${NORD_RED}󰆑${RST}" "Uninstalling Packages"
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
    git -C "$HOME/arch-config" pull --rebase --autostash 2>&1 | _pass_thru
    local exit_code=${PIPESTATUS[0]}
    if [[ $exit_code -eq 0 ]]; then
        _print_row "󰊢" "Status" "Configs up to date!"
        _print_footer
        echo -e "${NORD_GREEN}󰑓  Sourcing updated profile...${RST}"
        source ~/.bashrc
    else
        _print_row "󰅙" "Status" "Update Failed"
        _print_footer
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

    _print_header "${NORD_CYAN}󰑮${RST}" "Upgrading | $label"
    case "$label" in
        All) yay -Syu --noconfirm ;;
        AUR) yay -Sua --noconfirm ;;
        *)
            sudo pacman -Sy --noconfirm &>/dev/null
            local repo_pkgs=$(pacman -Sl "$label" 2>/dev/null | awk '{print $2}')
            local to_upgrade=$(checkupdates 2>/dev/null | awk '{print $1}' | grep -Fwf <(echo "$repo_pkgs"))
            if [[ -z "$to_upgrade" ]]; then
                _print_row "󰄬" "Status" "up to date"
            else
                sudo pacman -S --noconfirm $to_upgrade
            fi
            ;;
    esac
    _print_footer
}

up-mirrors() {
    _print_header "${NORD_BLUE}󰈀${RST}" "Updating Mirrors"
    sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
    sudo pacman -Syyu
    _print_footer
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
    local size=$(du -sh --apparent-size "$target" 2>/dev/null | cut -f1)
    _print_header "${NORD_CYAN}󰋊${RST}" "Size"
    _print_row "󰉋" "Path" "$target"
    _print_row "󰋊" "Size" "$size"
    _print_footer
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
        _print_header "${NORD_RED}󰋊${RST}" "Wallpapers"
        _print_row "󰅙" "Error" "Wallpapers directory not found"
        _print_footer; return 1
    fi
    _print_header "${NORD_CYAN}󰋊${RST}" "Wallpapers"

    local changes=$(git -C "$WALLPAPERS_DIR" status --porcelain 2>/dev/null)
    if [[ -n "$changes" ]]; then
        _print_row "󰊢" "Local" "Uncommitted changes found"
        git -C "$WALLPAPERS_DIR" add -A 2>&1 | _pass_thru
        git -C "$WALLPAPERS_DIR" commit -m "sync: local wallpaper changes" 2>&1 | _pass_thru
        if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
            _print_row "󰄬" "Commit" "Changes committed"
        else
            _print_row "󰅙" "Commit" "Failed to commit"
        fi
    fi

    git -C "$WALLPAPERS_DIR" pull --rebase --autostash 2>&1 | _pass_thru
    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
        _print_row "󰄬" "Pull" "Up to date"
    else
        _print_row "󰅙" "Pull" "Pull failed"
    fi

    git -C "$WALLPAPERS_DIR" push 2>&1 | _pass_thru
    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
        _print_row "󰄬" "Push" "Synced to GitHub"
    else
        _print_row "󰅙" "Push" "Nothing to push or push failed"
    fi

    _print_footer
}

# ------------------------------------------------------------------------------
# 8. MISCELLANEOUS & HELP
# ------------------------------------------------------------------------------
info() {
    _print_header "${NORD_CYAN}󱈄${RST}" "Custom Shell Commands"

    printf "${NORD_POLAR_4}󰣇  System${RST}\n"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "sys"         "Show system info (uptime, kernel, memory, packages)"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "age"         "Show OS installation age in days"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "reload"      "Re-source ~/.bashrc"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "conf"        "Open arch-config in Zed"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "rr"          "Re-run last command with sudo"
    echo ""

    printf "${NORD_POLAR_4}󰏖  Packages${RST}\n"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "inst"        "Install packages (fzf picker or direct name)"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "uinst"       "Uninstall packages (fzf picker or direct name)"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "upp"         "Upgrade packages (fzf: All / per repo)"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "cup"         "Check available updates across all repos"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "cleanup"     "Clear package caches and orphaned build files"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "up-mirrors"  "Refresh mirrorlist with reflector and sync"
    echo ""

    printf "${NORD_POLAR_4}󰚰  Updates${RST}\n"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "upall"       "Full update: packages + Firefox + wallpapers + configs"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "upc"         "Pull latest arch-config from GitHub and reload"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "upf"         "Fetch Betterfox user.js and apply to Firefox profiles"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "wp"          "Sync wallpapers repo (commit, pull, push)"
    echo ""

    if [[ -f "$IDEAPAD_CONSERVATION" ]]; then
        printf "${NORD_POLAR_4}󱊟  Battery${RST}\n"
        printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "batt-on"     "Enable conservation mode (charge limit 80%)"
        printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "batt-off"    "Disable conservation mode (charge to 100%)"
        echo ""
    fi

    printf "${NORD_POLAR_4}󰛳  Network${RST}\n"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "cdns-on"     "Enable custom DNS (NextDNS via systemd-resolved)"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "cdns-off"    "Disable custom DNS, restore ISP default"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "wg-socks"    "Manage WireGuard SOCKS5 proxy"
    echo ""

    printf "${NORD_POLAR_4}󰓇  Files${RST}\n"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "exp [path]"  "Open path in file manager (defaults to .)"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "open [path]" "Open file/URL with default app"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "ff [path]"   "fzf file finder, copies selection to clipboard"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "sz [path]"   "Show size of file or directory"
    echo ""

    printf "${NORD_POLAR_4}󰉋  Navigation${RST}\n"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "z [query]"   "Jump to frecent directory (zoxide) + auto-ls"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "ll"          "Long list with human-readable sizes"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "la"          "List all including hidden files"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "lla"         "Long list all including hidden files"
    echo ""

    printf "${NORD_POLAR_4}󰌌  Keybinds${RST}\n"
    printf "  ${NORD_BLUE}%-14s${RST} ${NORD_SNOW_1}%s${RST}\n" "Ctrl+H"      "fzf history picker (Ctrl+D to delete entry)"
    echo ""

    _print_footer
}

# Run system info on startup
sys
