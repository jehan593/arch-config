#!/bin/bash

# WireGuard Manager (wgm)

source "$ARCH_CONFIG_PATH/helpers/common-helpers.sh"
source "$ARCH_CONFIG_PATH/scripts/wgm/wgm-helper.sh"

_test_dependencies wg wg-quick fzf || exit 1

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

_wgm_set_paths "$REAL_HOME"

if [ "$EUID" -ne 0 ]; then
    _print_status "info" "Elevating permissions..."
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
        _print_status "error" "No profiles found"
        return 1
    fi

    local selected
    selected=$(awk -F'|' '{print $1}' <<< "$list" | fzf --prompt="$prompt > " --reverse --height=40%)
    [[ -z "$selected" ]] && return 1

    awk -F'|' -v n="$selected" '$1==n { print; exit }' <<< "$list"
}

_warp_generate() {
    if ! command -v wgcf &>/dev/null; then
        _print_status "error" "wgcf not found (yay -S wgcf)"
        return 1
    fi

    mkdir -p "$WARP_DIR"
    pushd "$WARP_DIR" &>/dev/null || { _print_status "error" "Failed to open $WARP_DIR"; return 1; }

    if [[ -f "$WARP_DIR/wgcf-account.toml" ]]; then
        _print_status "info" "Updating account..."
        if ! wgcf update; then
            _print_status "error" "Update failed"
            popd &>/dev/null; return 1
        fi
    else
        _print_status "info" "Registering account..."
        if ! wgcf register --accept-tos; then
            _print_status "error" "Registration failed"
            popd &>/dev/null; return 1
        fi
    fi

    _print_status "info" "Generating config..."
    if ! wgcf generate --profile "$WARP_DIR/wgcf-profile.conf" || [[ ! -f "$WARP_DIR/wgcf-profile.conf" ]]; then
        _print_status "error" "Generation failed"
        popd &>/dev/null; return 1
    fi

    mv "$WARP_DIR/wgcf-profile.conf" "$WARP_CONF"
    chmod 600 "$WARP_CONF"

    sed -i '/^DNS/d' "$WARP_CONF"
    _print_status "success" "DNS removed"

    local endpoint_ip
    endpoint_ip=$(getent ahostsv4 engage.cloudflareclient.com | awk '{print $1}' | head -n1)
    if [[ -n "$endpoint_ip" ]]; then
        sed -i "s/engage.cloudflareclient.com/$endpoint_ip/" "$WARP_CONF"
        _print_status "success" "Endpoint resolved: $endpoint_ip"
    else
        _print_status "warning" "Could not resolve endpoint"
    fi

    _print_status "success" "Config saved"
    popd &>/dev/null
    return 0
}

wgm_on() {
    _ensure_dirs

    local active
    active=$(_get_active_tunnel)
    if [[ -n "$active" ]]; then
        _print_status "error" "$active is already connected"
        return 1
    fi

    local picked
    picked=$(_pick_config "Connect to")
    if [[ -z "$picked" ]]; then
        _print_status "info" "Cancelled"
        return
    fi
    local name path builtin
    IFS='|' read -r name path builtin <<< "$picked"

    if [[ ! -f "$path" ]]; then
        if [[ "$builtin" == "1" && "$name" == "warp" ]]; then
            _print_status "info" "Warp config not found. Generating..."
            _warp_generate || return 1
        else
            _print_status "error" "Config not found: $path"
            return 1
        fi
    fi

    _print_header "Connecting to $name" ""

    mkdir -p "$WG_DIR"
    cp "$path" "$WG_DIR/$name.conf"
    chmod 600 "$WG_DIR/$name.conf"

    if systemctl enable --now "wg-quick@$name"; then
        _print_status "success" "Connected"
    else
        _print_status "error" "Connection failed"
    fi
    echo ""
}

wgm_off() {
    local active
    active=$(_get_active_tunnel)

    if [[ -z "$active" ]]; then
        _print_status "error" "No active connection"
        return
    fi

    _print_header "Disconnecting from $active" ""

    if systemctl disable --now "wg-quick@$active"; then
        _print_status "success" "Disconnected"
        rm -f "$WG_DIR/$active.conf"
    else
        _print_status "error" "Disconnect failed"
    fi
    echo ""
}

wgm_add() {
    local name="$1" conf_path="$2"
    if [[ -z "$name" || -z "$conf_path" ]]; then
        _print_status "warning" "Usage: wgm add <name> <path-to-conf>"
        return 1
    fi
    if [[ "$name" == "warp" ]]; then
        _print_status "error" "warp cannot be overwritten"
        return 1
    fi

    _ensure_dirs
    local dest="$CONFIGS_DIR/$name.conf"
    if [[ -f "$dest" ]]; then
        _print_status "error" "Profile '$name' already exists"
        return 1
    fi

    local src
    src=$(realpath "$conf_path" 2>/dev/null)
    if [[ -z "$src" || ! -f "$src" ]]; then
        _print_status "error" "File not found: $conf_path"
        return 1
    fi
    _print_header "Adding Profile" ""
    cp "$src" "$dest"
    chmod 600 "$dest"
    sed -i '/^DNS/d' "$dest"
    _print_status "success" "Profile added"
    _print_status "info" "Path: $dest"
    echo ""
}

wgm_rm() {
    local active
    active=$(_get_active_tunnel)
    if [[ -n "$active" ]]; then
        _print_status "error" "$active is active. Disconnect first."
        return 1
    fi

    shopt -s nullglob
    local confs=("$CONFIGS_DIR"/*.conf)
    shopt -u nullglob
    if [[ ${#confs[@]} -eq 0 ]]; then
        _print_status "error" "No profiles to remove"
        return
    fi

    local selected
    selected=$( (for f in "${confs[@]}"; do basename "$f" .conf; done) | sort | \
        fzf --prompt="Remove profile > " --reverse --height=40%)
    if [[ -z "$selected" ]]; then
        _print_status "info" "Cancelled"
        return
    fi

    local target="$CONFIGS_DIR/$selected.conf"
    if [[ ! -f "$target" ]]; then
        _print_status "error" "Config not found: $target"
        return 1
    fi

    mkdir -p "$BACKUP_ROOT"
    chown -R "$REAL_USER:$REAL_USER" "$BACKUP_ROOT"
    local backup_file="$BACKUP_ROOT/${selected}.conf"
    cp "$target" "$backup_file"

    _print_header "Removing Profile" ""
    rm -f "$target"
    _print_status "success" "Profile removed"
    _print_status "info" "Backup: $backup_file"
    echo ""
}

wgm_status() {
    local configs running
    configs=$(_get_all_configs)
    running=$(wg show interfaces 2>/dev/null)

    _print_header "wgm Status" ""

    if [[ -n "$running" ]]; then
        local svc
        for svc in $running; do
            _print_status "success" "Connected: $svc"
        done
    else
        _print_status "info" "Disconnected"
    fi

    echo ""
    echo -e "${NORD_POLAR_4}Profiles:${RST}"

    local name path builtin avail marker color tag active_marker
    while IFS='|' read -r name path builtin; do
        [[ -z "$name" ]] && continue
        if [[ -f "$path" ]]; then
            color="${NORD_CYAN}"
            marker="available"
        else
            color="${NORD_RED}"
            marker="missing"
        fi
        tag=""
        [[ "$builtin" == "1" ]] && tag=" [warp]"
        active_marker=""
        grep -qx "$name" <<< "$running" && active_marker=" [Active]"
        echo -e "${color}${name}${tag}${active_marker} (${marker})${RST}"
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
        _print_header "wgm Manager" ""
        printf "${NORD_CYAN}%-8s${RST}${NORD_POLAR_4} -> ${RST}${NORD_SNOW_1}%s${RST}\n" "on"     "Connect"
        printf "${NORD_CYAN}%-8s${RST}${NORD_POLAR_4} -> ${RST}${NORD_SNOW_1}%s${RST}\n" "off"    "Disconnect"
        printf "${NORD_CYAN}%-8s${RST}${NORD_POLAR_4} -> ${RST}${NORD_SNOW_1}%s${RST}\n" "add"    "Add profile"
        printf "${NORD_CYAN}%-8s${RST}${NORD_POLAR_4} -> ${RST}${NORD_SNOW_1}%s${RST}\n" "rm"     "Remove profile"
        printf "${NORD_CYAN}%-8s${RST}${NORD_POLAR_4} -> ${RST}${NORD_SNOW_1}%s${RST}\n" "status" "Show status"
        echo ""
        echo -e "${NORD_DIM}Usage: wgm add <name> <path-to-conf>${RST}"
        echo ""
        exit 1
        ;;
esac