#!/bin/bash

# WireGuard VPN Manager

source "$HOME/arch-config/scripts/helpers.sh"

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

VPN_ROOT="$REAL_HOME/.config/vpn"
CONFIGS_DIR="$VPN_ROOT/configs"
STATUS_FILE="$VPN_ROOT/active_tunnel"
WARP_DIR="$REAL_HOME/.config/warp"
WARP_CONF="$WARP_DIR/warp.conf"
WG_DIR="/etc/wireguard"
BACKUP_ROOT="$REAL_HOME/Documents/vpn-configs-backup"

if [ "$EUID" -ne 0 ]; then
    echo -e "${NORD_CYAN}󰌆  Elevating...${RST}"
    exec sudo -E bash "$(realpath "$0")" "$@"
fi

_ensure_dirs() {
    mkdir -p "$VPN_ROOT" "$CONFIGS_DIR"
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

_get_active_tunnel() {
    if [[ -f "$STATUS_FILE" ]]; then
        local val
        val=$(<"$STATUS_FILE")
        val=$(sed 's/^[^[:space:]]*[[:space:]]*//' <<< "$val")
        [[ -n "$val" ]] && { echo "$val"; return; }
    fi
    wg show interfaces 2>/dev/null | awk '{print $1; exit}'
}

_set_active_tunnel() {
    _ensure_dirs
    echo "󰌆 $1" > "$STATUS_FILE"
}

_clear_active_tunnel() {
    [[ -f "$STATUS_FILE" ]] && : > "$STATUS_FILE"
}

_pick_config() {
    local prompt="${1:-Select VPN profile}"
    local list
    list=$(_get_all_configs)
    if [[ -z "$list" ]]; then
        _print_status "󰅙" "No VPN profiles found"
        return 1
    fi

    local selected
    selected=$(awk -F'|' '{print $1}' <<< "$list" | fzf --prompt="$prompt > " --reverse --height=40%)
    [[ -z "$selected" ]] && return 1

    awk -F'|' -v n="$selected" '$1==n { print; exit }' <<< "$list"
}
_warp_generate() {
    if ! command -v wgcf &>/dev/null; then
        _print_status "󰅙" "wgcf not found (yay -S wgcf)"
        return 1
    fi

    mkdir -p "$WARP_DIR"
    pushd "$WARP_DIR" &>/dev/null || { _print_status "󰅙" "Failed to open $WARP_DIR"; return 1; }

    if [[ -f "$WARP_DIR/wgcf-account.toml" ]]; then
        _print_status "󰚰" "Updating account..."
        if ! wgcf update; then
            _print_status "󰅙" "Update failed"
            popd &>/dev/null; return 1
        fi
    else
        _print_status "󰀄" "Registering account..."
        if ! wgcf register --accept-tos; then
            _print_status "󰅙" "Registration failed"
            popd &>/dev/null; return 1
        fi
    fi

    _print_status "󰒓" "Generating config..."
    if ! wgcf generate --profile "$WARP_DIR/wgcf-profile.conf" || [[ ! -f "$WARP_DIR/wgcf-profile.conf" ]]; then
        _print_status "󰅙" "Generation failed"
        popd &>/dev/null; return 1
    fi

    mv "$WARP_DIR/wgcf-profile.conf" "$WARP_CONF"
    chmod 600 "$WARP_CONF"

    sed -i '/^DNS/d' "$WARP_CONF"
    _print_status "󰄬" "DNS removed"

    local endpoint_ip
    endpoint_ip=$(getent ahostsv4 engage.cloudflareclient.com | awk '{print $1}' | head -n1)
    if [[ -n "$endpoint_ip" ]]; then
        sed -i "s/engage.cloudflareclient.com/$endpoint_ip/" "$WARP_CONF"
        _print_status "󰄬" "Endpoint resolved: $endpoint_ip"
    else
        _print_status "󰀦" "Could not resolve endpoint"
    fi

    _print_status "󰄬" "Config saved"
    popd &>/dev/null
    return 0
}

vpn_on() {
    _ensure_dirs

    local active
    active=$(_get_active_tunnel)
    if [[ -n "$active" ]]; then
        _print_status "󰅙" "$active is already connected"
        return 1
    fi

    local picked
    picked=$(_pick_config "Connect to")
    if [[ -z "$picked" ]]; then
        _print_status "󰀦" "Cancelled"
        return
    fi
    local name path builtin
    IFS='|' read -r name path builtin <<< "$picked"

    if [[ ! -f "$path" ]]; then
        if [[ "$builtin" == "1" && "$name" == "warp" ]]; then
            _print_status "󰖂" "Warp config not found. Generating..."
            _warp_generate || return 1
        else
            _print_status "󰅙" "Config not found: $path"
            return 1
        fi
    fi

    _print_header "󰖂" "Connecting to $name"

    mkdir -p "$WG_DIR"
    cp "$path" "$WG_DIR/$name.conf"
    chmod 600 "$WG_DIR/$name.conf"

    if systemctl enable --now "wg-quick@$name"; then
        _print_status "󰤨" "Connected"
        _set_active_tunnel "$name"
    else
        _print_status "󰅙" "Connection failed"
    fi
    echo ""
}

vpn_off() {
    local active
    active=$(_get_active_tunnel)

    if [[ -z "$active" ]]; then
        _print_status "󰅙" "No active connection"
        return
    fi

    _print_header "󰖂" "Disconnecting from $active"

    if systemctl disable --now "wg-quick@$active"; then
        _print_status "󰤭" "Disconnected"
        rm -f "$WG_DIR/$active.conf"
        _clear_active_tunnel
    else
        _print_status "󰅙" "Disconnect failed"
    fi
    echo ""
}

vpn_add() {
    local name="$1" conf_path="$2"
    if [[ -z "$name" || -z "$conf_path" ]]; then
        _print_status "󰀦" "Usage: vpn add <name> <path-to-conf>"
        return 1
    fi
    if [[ "$name" == "warp" ]]; then
        _print_status "󰅙" "warp cannot be overwritten"
        return 1
    fi

    _ensure_dirs
    local src
    src=$(realpath "$conf_path" 2>/dev/null)
    if [[ -z "$src" || ! -f "$src" ]]; then
        _print_status "󰅙" "File not found: $conf_path"
        return 1
    fi

    local dest="$CONFIGS_DIR/$name.conf"
    _print_header "󰖂" "Adding Profile"
    cp "$src" "$dest"
    chmod 600 "$dest"
    sed -i '/^DNS/d' "$dest"
    _print_status "󰄬" "Profile added"
    _print_status "󰋊" "Path: $dest"
    echo ""
}

vpn_remove() {
    local active
    active=$(_get_active_tunnel)
    if [[ -n "$active" ]]; then
        _print_status "󰅙" "$active is active. Disconnect first."
        return 1
    fi

    shopt -s nullglob
    local confs=("$CONFIGS_DIR"/*.conf)
    shopt -u nullglob
    if [[ ${#confs[@]} -eq 0 ]]; then
        _print_status "󰅙" "No profiles to remove"
        return
    fi

    local selected
    selected=$( (for f in "${confs[@]}"; do basename "$f" .conf; done) | sort | \
        fzf --prompt="Remove profile > " --reverse --height=40%)
    if [[ -z "$selected" ]]; then
        _print_status "󰀦" "Cancelled"
        return
    fi

    local target="$CONFIGS_DIR/$selected.conf"
    if [[ ! -f "$target" ]]; then
        _print_status "󰅙" "Config not found: $target"
        return 1
    fi

    mkdir -p "$BACKUP_ROOT"
    local timestamp backup_file
    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_file="$BACKUP_ROOT/${selected}_${timestamp}.conf"
    cp "$target" "$backup_file"

    _print_header "󰖂" "Removing Profile"
    rm -f "$target"
    _print_status "󰆑" "Profile removed"
    _print_status "󰋊" "Backup: $backup_file"
    echo ""
}

vpn_status() {
    local configs running
    configs=$(_get_all_configs)
    running=$(wg show interfaces 2>/dev/null)

    _print_header "󰖂" "VPN Status"

    if [[ -n "$running" ]]; then
        local svc
        for svc in $running; do
            _print_status "󰤨" "Connected: $svc"
        done
    else
        _print_status "󰤭" "Disconnected"
    fi

    echo ""
    echo -e "${NORD_POLAR_4}  Profiles:${RST}"

    local name path builtin avail icon color tag active_marker
    while IFS='|' read -r name path builtin; do
        [[ -z "$name" ]] && continue
        if [[ -f "$path" ]]; then
            icon="󰄬"; color="${NORD_CYAN}"
        else
            icon="󰅙"; color="${NORD_RED}"
        fi
        tag=""
        [[ "$builtin" == "1" ]] && tag=" [warp]"
        active_marker=""
        grep -qx "$name" <<< "$running" && active_marker="  ← active"
        echo -e "  ${color}${icon}  ${name}${tag}${active_marker}${RST}"
    done <<< "$configs"

    echo ""
}

case "$1" in
    on)     vpn_on ;;
    off)    vpn_off ;;
    add)    vpn_add "$2" "$3" ;;
    remove) vpn_remove ;;
    status) vpn_status ;;
    *)
        _print_header "󰖂" "VPN Manager"
        printf "  ${NORD_CYAN}%-8s${RST}${NORD_POLAR_4} 󰁔 ${RST}${NORD_SNOW_1}%s${RST}\n" "on"     "Connect to VPN"
        printf "  ${NORD_CYAN}%-8s${RST}${NORD_POLAR_4} 󰁔 ${RST}${NORD_SNOW_1}%s${RST}\n" "off"    "Disconnect from VPN"
        printf "  ${NORD_CYAN}%-8s${RST}${NORD_POLAR_4} 󰁔 ${RST}${NORD_SNOW_1}%s${RST}\n" "add"    "Add VPN profile"
        printf "  ${NORD_CYAN}%-8s${RST}${NORD_POLAR_4} 󰁔 ${RST}${NORD_SNOW_1}%s${RST}\n" "remove" "Remove VPN profile"
        printf "  ${NORD_CYAN}%-8s${RST}${NORD_POLAR_4} 󰁔 ${RST}${NORD_SNOW_1}%s${RST}\n" "status" "Show VPN status"
        echo ""
        echo -e "${NORD_DIM}  Usage: vpn add <name> <path-to-conf>${RST}"
        echo ""
        exit 1
        ;;
esac