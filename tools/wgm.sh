#!/bin/bash

# WireGuard Manager (wgm)

source "$ARCH_CONFIG_PATH/helpers/colors-nord.sh"
source "$ARCH_CONFIG_PATH/helpers/printer.sh"
source "$ARCH_CONFIG_PATH/helpers/dep-checker.sh"
source "$ARCH_CONFIG_PATH/helpers/wgm-helper.sh"

_test_dependencies wg wg-quick fzf || exit 1

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

_wgm_set_paths "$REAL_HOME"

if [ "$EUID" -ne 0 ]; then
    sudo -n true 2>/dev/null || printfc "$NORD_YELLOW" "Elevating permissions..."
    exec sudo -E bash "$(realpath "$0")" "$@"
fi

_ensure_dirs() {
    mkdir -p "$WGM_ROOT" "$CONFIGS_DIR"
}

_get_all_configs() {
    echo "warp|$WARP_CONF|1"
    [[ -d "$CONFIGS_DIR" ]] || return 0
    local f base
    while IFS= read -r f; do
        base=$(basename "$f" .conf)
        [[ "$base" == "warp" ]] && continue
        echo "${base}|${f}|0"
    done < <(find "$CONFIGS_DIR" -maxdepth 1 -name '*.conf' 2>/dev/null | sort)
}

_pick_config() {
    local prompt="${1:-Select profile}"
    local list
    list=$(_get_all_configs)
    if [[ -z "$list" ]]; then
        printfc "$NORD_RED" "No profiles found"
        return 1
    fi

    local selected
    selected=$(awk -F'|' '{print $1}' <<< "$list" | fzf --prompt="$prompt > " --reverse --height=40%)
    [[ -z "$selected" ]] && return 1

    awk -F'|' -v n="$selected" '$1==n { print; exit }' <<< "$list"
}

_warp_generate() {
    if ! command -v wgcf &>/dev/null; then
        printfc "$NORD_RED" "wgcf not found (yay -S wgcf)"
        return 1
    fi

    mkdir -p "$WARP_DIR"
    pushd "$WARP_DIR" &>/dev/null || { printfc "$NORD_RED" "Failed to open $WARP_DIR"; return 1; }

    if [[ -f "$WARP_DIR/wgcf-account.toml" ]]; then
        printfc "$NORD_YELLOW" "Updating account..."
        if ! wgcf update; then
            printfc "$NORD_RED" "Update failed"
            popd &>/dev/null; return 1
        fi
    else
        printfc "$NORD_YELLOW" "Registering account..."
        if ! wgcf register --accept-tos; then
            printfc "$NORD_RED" "Registration failed"
            popd &>/dev/null; return 1
        fi
    fi

    printfc "$NORD_YELLOW" "Generating config..."
    if ! wgcf generate --profile "$WARP_DIR/wgcf-profile.conf" || [[ ! -f "$WARP_DIR/wgcf-profile.conf" ]]; then
        printfc "$NORD_RED" "Generation failed"
        popd &>/dev/null; return 1
    fi

    mv "$WARP_DIR/wgcf-profile.conf" "$WARP_CONF"
    chmod 600 "$WARP_CONF"

    sed -i '/^DNS/d' "$WARP_CONF"
    printfc "$NORD_GREEN" "DNS removed"

    local endpoint_ip
    endpoint_ip=$(getent ahostsv4 engage.cloudflareclient.com | awk '{print $1}' | head -n1)
    if [[ -n "$endpoint_ip" ]]; then
        sed -i "s/engage.cloudflareclient.com/$endpoint_ip/" "$WARP_CONF"
        printfc "$NORD_GREEN" "Endpoint resolved: %s" "$endpoint_ip"
    else
        printfc "$NORD_YELLOW" "Could not resolve endpoint"
    fi

    printfc "$NORD_GREEN" "Config saved"
    popd &>/dev/null
    return 0
}

wgm_on() {
    _ensure_dirs

    local active
    active=$(_get_active_tunnel)
    if [[ -n "$active" ]]; then
        printfc "$NORD_RED" "%s is already connected" "$active"
        return 1
    fi

    local picked
    picked=$(_pick_config "Connect to")
    if [[ -z "$picked" ]]; then
        printfc "$NORD_YELLOW" "Cancelled"
        return
    fi
    local name path builtin
    IFS='|' read -r name path builtin <<< "$picked"

    if [[ ! -f "$path" ]]; then
        if [[ "$builtin" == "1" && "$name" == "warp" ]]; then
            printfc "$NORD_YELLOW" "Warp config not found. Generating..."
            _warp_generate || return 1
        else
            printfc "$NORD_RED" "Config not found: %s" "$path"
            return 1
        fi
    fi

    printfc "$NORD_BLUE" "\n>Connecting to %s" "$name"

    mkdir -p "$WG_DIR"
    cp "$path" "$WG_DIR/$name.conf"
    chmod 600 "$WG_DIR/$name.conf"

    if systemctl enable --now "wg-quick@$name"; then
        printfc "$NORD_GREEN" "Connected"
    else
        printfc "$NORD_RED" "Connection failed"
    fi
    echo ""
}

wgm_off() {
    local active
    active=$(_get_active_tunnel)

    if [[ -z "$active" ]]; then
        printfc "$NORD_RED" "No active connection"
        return
    fi

    printfc "$NORD_BLUE" "\n>Disconnecting from %s" "$active"

    if systemctl disable --now "wg-quick@$active"; then
        printfc "$NORD_GREEN" "Disconnected"
        rm -f "$WG_DIR/$active.conf"
    else
        printfc "$NORD_RED" "Disconnect failed"
    fi
    echo ""
}

wgm_add() {
    local name="$1" conf_path="$2"
    if [[ -z "$name" || -z "$conf_path" ]]; then
        printfc "$NORD_YELLOW" "Usage: wgm add <name> <path-to-conf>"
        return 1
    fi
    if [[ "$name" == "warp" ]]; then
        printfc "$NORD_RED" "warp cannot be overwritten"
        return 1
    fi

    _ensure_dirs
    local dest="$CONFIGS_DIR/$name.conf"
    if [[ -f "$dest" ]]; then
        printfc "$NORD_RED" "Profile '%s' already exists" "$name"
        return 1
    fi

    local src
    src=$(realpath "$conf_path" 2>/dev/null)
    if [[ -z "$src" || ! -f "$src" ]]; then
        printfc "$NORD_RED" "File not found: %s" "$conf_path"
        return 1
    fi
    printfc "$NORD_BLUE" "\n>Adding Profile"
    cp "$src" "$dest"
    chmod 600 "$dest"
    sed -i '/^DNS/d' "$dest"
    printfc "$NORD_GREEN" "Profile added"
    printfc "$NORD_SNOW_1" "Path: %s" "$dest"
    echo ""
}

wgm_rm() {
    local active
    active=$(_get_active_tunnel)
    if [[ -n "$active" ]]; then
        printfc "$NORD_RED" "%s is active. Disconnect first." "$active"
        return 1
    fi

    shopt -s nullglob
    local confs=("$CONFIGS_DIR"/*.conf)
    shopt -u nullglob
    if [[ ${#confs[@]} -eq 0 ]]; then
        printfc "$NORD_RED" "No profiles to remove"
        return
    fi

    local selected
    selected=$( (for f in "${confs[@]}"; do basename "$f" .conf; done) | sort | \
        fzf --prompt="Remove profile > " --reverse --height=40%)
    if [[ -z "$selected" ]]; then
        printfc "$NORD_YELLOW" "Cancelled"
        return
    fi

    local target="$CONFIGS_DIR/$selected.conf"
    if [[ ! -f "$target" ]]; then
        printfc "$NORD_RED" "Config not found: %s" "$target"
        return 1
    fi

    mkdir -p "$BACKUP_ROOT"
    chown -R "$REAL_USER:$REAL_USER" "$BACKUP_ROOT"
    local backup_file="$BACKUP_ROOT/${selected}.conf"
    cp "$target" "$backup_file"

    printfc "$NORD_BLUE" "\n>Removing Profile"
    rm -f "$target"
    printfc "$NORD_GREEN" "Profile removed"
    printfc "$NORD_GREEN" "Backup: %s" "$backup_file"
    echo ""
}

wgm_status() {
    local configs running
    configs=$(_get_all_configs)
    running=$(wg show interfaces 2>/dev/null)

    printfc "$NORD_BLUE" "\n>wgm Status"

    if [[ -n "$running" ]]; then
        local svc
        for svc in $running; do
            printfc "$NORD_GREEN" "Connected: %s" "$svc"
        done
    else
        printfc "$NORD_YELLOW" "Disconnected"
    fi

    echo ""
    printfc "$NORD_POLAR_4" "Profiles:"

    local name path builtin marker color tag active_marker
    while IFS='|' read -r name path builtin; do
        [[ -z "$name" ]] && continue
        if [[ -f "$path" ]]; then
            color="${NORD_GREEN}"
            marker="available"
        else
            color="${NORD_RED}"
            marker="missing"
        fi
        tag=""
        [[ "$builtin" == "1" ]] && tag=" [warp]"
        active_marker=""
        grep -qx "$name" <<< "$running" && active_marker=" [Active]"
        printfc "$color" "%s%s%s (%s)" "$name" "$tag" "$active_marker" "$marker"
    done <<< "$configs"

    echo ""
}

case "$1" in
    on)     wgm_on ;;
    off)    wgm_off ;;
    add)    wgm_add "$2" "$3" ;;
    rm)     wgm_rm ;;
    status) wgm_status ;;
    *)
        printfc "$NORD_BLUE" "\n>wgm Manager\n"
        printfc "$NORD_SNOW_1" "on       Connect"
        printfc "$NORD_SNOW_1" "off      Disconnect"
        printfc "$NORD_SNOW_1" "add      Add profile"
        printfc "$NORD_SNOW_1" "rm       Remove profile"
        printfc "$NORD_SNOW_1" "status   Show status"
        echo ""
        printfc "$NORD_YELLOW" "Usage: wgm add <name> <path-to-conf>"
        echo ""
        exit 1
        ;;
esac
