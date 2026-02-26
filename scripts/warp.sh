#!/bin/bash

# ==============================================================================
# WIREGUARD WARP MANAGER (Nord Aesthetic)
# ==============================================================================

# Nord Colors
NORD_POLAR_4='\e[38;2;76;86;106m'
NORD_SNOW_1='\e[38;2;216;222;233m'
NORD_CYAN='\e[38;2;143;188;187m'
NORD_BLUE='\e[38;2;136;192;208m'
NORD_D_BLUE='\e[38;2;129;161;193m'
NORD_GREEN='\e[38;2;163;190;140m'
NORD_RED='\e[38;2;191;97;106m'
NORD_ORANGE='\e[38;2;208;135;112m'
RST='\e[0m'

HEADER_LINE="${NORD_POLAR_4}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"

# Store real user info before elevation
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

WARP_CONF="$REAL_HOME/.config/warp/warp.conf"
WARP_DIR="$REAL_HOME/.config/warp"
TUNNEL="warp"

# Elevation check
if [ "$EUID" -ne 0 ]; then
    echo -e "\n${NORD_ORANGE}󰒃${RST}  ${NORD_SNOW_1}Elevating privileges for warp...${RST}"
    exec sudo bash "$(realpath "$0")" "$@"
fi

# --- UI Helpers ---

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

_print_status() {
    local color=$NORD_BLUE
    [[ "$1" == "󰄬" ]] && color=$NORD_GREEN
    [[ "$1" == "󰅙" ]] && color=$NORD_RED
    printf "${NORD_POLAR_4}│${RST}  ${color}%s${RST}  %s\n" "$1" "$2"
}

_run() {
    local label="$1"; shift
    if "$@" &>/dev/null; then
        _print_row "󰄬" "$label" "Done"
    else
        _print_row "󰅙" "$label" "Failed"
    fi
}

# --- Actions ---

warp_on() {
    if [[ ! -f "$WARP_CONF" ]]; then
        _print_header "${NORD_RED}󰅙${RST}" "Error"
        _print_status "󰅙" "warp.conf not found. Run: warp rotate"
        _print_footer; exit 1
    fi

    _print_header "${NORD_CYAN}󰖂${RST}" "WireGuard WARP"
    if wg-quick up "$WARP_CONF" &>/dev/null; then
        _print_row "󰤨" "Status" "CONNECTED"
    else
        _print_row "󰅙" "Status" "Failed to connect"
    fi
    _print_footer
}

warp_off() {
    _print_header "${NORD_RED}󰖂${RST}" "WireGuard WARP"
    if wg-quick down "$WARP_CONF" &>/dev/null; then
        _print_row "󰤭" "Status" "DISCONNECTED"
    else
        _print_row "󰅙" "Status" "Failed to disconnect"
    fi
    _print_footer
}

warp_rotate() {
    if wg show "$TUNNEL" &>/dev/null; then
        _print_header "${NORD_RED}󰅙${RST}" "Error"
        _print_status "󰅙" "Tunnel is active. Run: warp off first."
        _print_footer; exit 1
    fi

    _print_header "${NORD_CYAN}󰖂${RST}" "Rotating WARP Credentials"

    if ! command -v wgcf &>/dev/null; then
        _print_status "󰅙" "wgcf not found. Install it first: yay -S wgcf"
        _print_footer; exit 1
    fi

    mkdir -p "$WARP_DIR"
    cd "$WARP_DIR" || exit 1

    if [[ -f "$WARP_DIR/wgcf-account.toml" ]]; then
        _print_status "󰒓" "Updating existing account..."
        if ! wgcf update &>/dev/null; then
            _print_status "󰅙" "Account update failed."
            _print_footer; exit 1
        fi
    else
        _print_status "󰒓" "Registering new account..."
        if ! wgcf register --accept-tos &>/dev/null; then
            _print_status "󰅙" "Account registration failed."
            _print_footer; exit 1
        fi
    fi
    _print_row "󰄬" "Account" "Done"

    _print_status "󰒓" "Generating new config..."
    if ! wgcf generate --profile "$WARP_DIR/wgcf-profile.conf" &>/dev/null; then
        _print_status "󰅙" "Config generation failed."
        _print_footer; exit 1
    fi

    if [[ -f "$WARP_DIR/wgcf-profile.conf" ]]; then
        mv "$WARP_DIR/wgcf-profile.conf" "$WARP_CONF"
        chmod 600 "$WARP_CONF"

        sed -i '/^DNS/d' "$WARP_CONF"
        _print_row "󰄬" "DNS" "Removed (preserving NextDNS)"

        ENDPOINT_IP=$(getent ahostsv4 engage.cloudflareclient.com | awk '{print $1}' | head -n1)
        if [[ -n "$ENDPOINT_IP" ]]; then
            sed -i "s/engage.cloudflareclient.com/$ENDPOINT_IP/" "$WARP_CONF"
            _print_row "󰄬" "Endpoint" "$ENDPOINT_IP"
        else
            _print_row "󰀦" "Endpoint" "Could not resolve, keeping hostname"
        fi

        _print_row "󰄬" "Config" "Saved to $WARP_CONF"
    else
        _print_status "󰅙" "Failed to generate config."
        _print_footer; exit 1
    fi

    _print_footer
}

warp_status() {
    _print_header "${NORD_CYAN}󰖂${RST}" "WireGuard WARP Status"

    if wg show "$TUNNEL" &>/dev/null; then
        _print_row "󰤨" "Status" "CONNECTED"
        local endpoint=$(wg show "$TUNNEL" endpoints 2>/dev/null | awk '{print $2}')
        local transfer=$(wg show "$TUNNEL" transfer 2>/dev/null | awk '{print $2 " rx / " $3 " tx"}')
        [[ -n "$endpoint" ]] && _print_row "󰩟" "Endpoint" "$endpoint"
        [[ -n "$transfer" ]] && _print_row "󰇚" "Transfer" "$transfer"
    else
        _print_row "󰤭" "Status" "DISCONNECTED"
    fi

    if [[ -f "$WARP_CONF" ]]; then
        _print_row "󰋊" "Config" "$WARP_CONF"
    else
        _print_row "󰅙" "Config" "Not found"
    fi

    _print_footer
}

# --- Router ---
case "$1" in
    on)     warp_on ;;
    off)    warp_off ;;
    rotate) warp_rotate ;;
    status) warp_status ;;
    *)
        _print_header "${NORD_CYAN}󰖂${RST}" "WireGuard WARP Manager"
        printf "${NORD_POLAR_4}│${RST}  ${NORD_BLUE}%-8s${RST} ${NORD_SNOW_1}%-40s${RST}\n" "on"     "Connect tunnel"
        printf "${NORD_POLAR_4}│${RST}  ${NORD_BLUE}%-8s${RST} ${NORD_SNOW_1}%-40s${RST}\n" "off"    "Disconnect tunnel"
        printf "${NORD_POLAR_4}│${RST}  ${NORD_BLUE}%-8s${RST} ${NORD_SNOW_1}%-40s${RST}\n" "rotate" "Rotate WARP credentials"
        printf "${NORD_POLAR_4}│${RST}  ${NORD_BLUE}%-8s${RST} ${NORD_SNOW_1}%-40s${RST}\n" "status" "Show tunnel status"
        _print_footer
        exit 1
        ;;
esac