#!/bin/bash

# ==============================================================================
# WIREGUARD WARP MANAGER (Nord Aesthetic)
# ==============================================================================

# Nord Colors
NORD_POLAR_4='\e[38;2;76;86;106m'
NORD_SNOW_1='\e[38;2;216;222;233m'
NORD_CYAN='\e[38;2;143;188;187m'
NORD_BLUE='\e[38;2;136;192;208m'
NORD_GREEN='\e[38;2;163;190;140m'
NORD_RED='\e[38;2;191;97;106m'
NORD_ORANGE='\e[38;2;208;135;112m'
RST='\e[0m'

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

WARP_CONF="$REAL_HOME/.config/warp/warp.conf"
WARP_DIR="$REAL_HOME/.config/warp"
TUNNEL="warp"
WARP_STATUS="$REAL_HOME/.config/warp/warp_status"

# Elevation check
if [ "$EUID" -ne 0 ]; then
    echo -e "\n${NORD_CYAN}󰌋  Elevating with sudo...${RST}"
    exec sudo bash "$(realpath "$0")" "$@"
fi

# --- UI Helpers ---

_print_header() {
    echo -e "\n${NORD_CYAN}${1}  ${NORD_SNOW_1}${2}${RST}"
    echo -e "${NORD_POLAR_4}─────────────────────────────────────────────────────${RST}"
}

_print_status() {
    local color=$NORD_BLUE
    [[ "$1" == "󰄬" ]] && color=$NORD_GREEN
    [[ "$1" == "󰅙" ]] && color=$NORD_RED
    [[ "$1" == "󰀦" ]] && color=$NORD_ORANGE
    echo -e "${color}${1}  ${2}${RST}"
}

_fmt_bytes() {
    awk -v b="$1" 'BEGIN {
        if (b >= 1073741824)      printf "%.2f GiB", b/1073741824
        else if (b >= 1048576)    printf "%.2f MiB", b/1048576
        else if (b >= 1024)       printf "%.2f KiB", b/1024
        else                      printf "%d B", b
    }'
}

_ensure_service() {
    if [[ ! -f /etc/systemd/system/warp.service ]]; then
        local script_path
        script_path="$(realpath "$0")"
        cat > /etc/systemd/system/warp.service <<EOF
[Unit]
Description=WireGuard WARP tunnel
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c 'test -f $WARP_STATUS && $script_path on || true'
ExecStop=$script_path off

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable warp &>/dev/null
        _print_status "󰄬" "Boot service created and enabled"
    fi
}

# --- Actions ---

warp_on() {
    if [[ ! -f "$WARP_CONF" ]]; then
        warp_rotate
    fi

    _print_header "󰖂" "WireGuard WARP"
    wg-quick up "$WARP_CONF"
    if [[ $? -eq 0 ]]; then
        _print_status "󰤨" "Connected"
        echo "󰅟" > "$WARP_STATUS"
        _ensure_service
    else
        _print_status "󰅙" "Failed to connect"
    fi
    echo ""
}

warp_off() {
    _print_header "󰖂" "WireGuard WARP"
    wg-quick down "$WARP_CONF"
    if [[ $? -eq 0 ]]; then
        _print_status "󰤭" "Disconnected"
        rm -f "$WARP_STATUS"
    else
        _print_status "󰅙" "Failed to disconnect"
    fi
    echo ""
}

warp_rotate() {
    if wg show "$TUNNEL" &>/dev/null; then
        _print_status "󰅙" "Tunnel is active. Run: warp off first."
        return 1
    fi

    _print_header "󰖂" "Rotating WARP Credentials"

    if ! command -v wgcf &>/dev/null; then
        _print_status "󰅙" "wgcf not found. Install it: yay -S wgcf"
        echo ""; exit 1
    fi

    mkdir -p "$WARP_DIR"
    cd "$WARP_DIR" || { _print_status "󰅙" "Failed to enter $WARP_DIR"; echo ""; exit 1; }

    if [[ -f "$WARP_DIR/wgcf-account.toml" ]]; then
        _print_status "󰚰" "Updating existing account..."
        wgcf update
        if [[ $? -ne 0 ]]; then
            _print_status "󰅙" "Account update failed."
            echo ""; exit 1
        fi
    else
        _print_status "󰀄" "Registering new account..."
        wgcf register --accept-tos
        if [[ $? -ne 0 ]]; then
            _print_status "󰅙" "Account registration failed."
            echo ""; exit 1
        fi
    fi
    _print_status "󰄬" "Account ready"

    _print_status "󰒓" "Generating new config..."
    wgcf generate --profile "$WARP_DIR/wgcf-profile.conf"
    if [[ $? -ne 0 ]]; then
        _print_status "󰅙" "Config generation failed."
        echo ""; exit 1
    fi

    if [[ -f "$WARP_DIR/wgcf-profile.conf" ]]; then
        mv "$WARP_DIR/wgcf-profile.conf" "$WARP_CONF"
        chmod 600 "$WARP_CONF"

        sed -i '/^DNS/d' "$WARP_CONF"
        _print_status "󰄬" "DNS removed (preserving NextDNS)"

        ENDPOINT_IP=$(getent ahostsv4 engage.cloudflareclient.com | awk '{print $1}' | head -n1)
        if [[ -n "$ENDPOINT_IP" ]]; then
            sed -i "s/engage.cloudflareclient.com/$ENDPOINT_IP/" "$WARP_CONF"
            _print_status "󰄬" "Endpoint resolved: $ENDPOINT_IP"
        else
            _print_status "󰀦" "Could not resolve endpoint, keeping hostname"
        fi

        _print_status "󰄬" "Config saved to $WARP_CONF"
    else
        _print_status "󰅙" "Failed to generate config."
        echo ""; exit 1
    fi

    echo ""
}

warp_status() {
    local f="  ${NORD_BLUE}%s${RST}  %-12s ${NORD_SNOW_1}%s${RST}\n"

    _print_header "󰖂" "WireGuard WARP Status"

    if wg show "$TUNNEL" &>/dev/null; then
        printf "$f" "󰤨" "Status" "Connected"

        local endpoint=$(wg show "$TUNNEL" endpoints 2>/dev/null | awk '{print $2}')
        [[ -n "$endpoint" ]] && printf "$f" "󰩟" "Endpoint" "$endpoint"

        local raw=$(wg show "$TUNNEL" transfer 2>/dev/null | awk '{print $2, $3}')
        if [[ -n "$raw" ]]; then
            local rx=$(echo "$raw" | awk '{print $1}')
            local tx=$(echo "$raw" | awk '{print $2}')
            printf "$f" "󰇚" "Transfer" "$(_fmt_bytes "$rx") rx / $(_fmt_bytes "$tx") tx"
        fi
    else
        printf "$f" "󰤭" "Status" "Disconnected"
    fi

    if [[ -f "$WARP_CONF" ]]; then
        printf "$f" "󰋊" "Config" "$WARP_CONF"
    else
        printf "$f" "󰅙" "Config" "Not found"
    fi

    if [[ -f "$WARP_STATUS" ]]; then
        printf "$f" "󰒓" "Persist" "Will reconnect on boot"
    else
        printf "$f" "󰒓" "Persist" "Will not reconnect on boot"
    fi

    echo ""
}

# --- Router ---
case "$1" in
    on)     warp_on ;;
    off)    warp_off ;;
    rotate) warp_rotate ;;
    status) warp_status ;;
    *)
        _print_header "󰖂" "WireGuard WARP Manager"
        printf "  ${NORD_CYAN}%-8s${RST}${NORD_POLAR_4} 󰁔 ${RST}${NORD_SNOW_1}%s${RST}\n" "on"     "Connect tunnel"
        printf "  ${NORD_CYAN}%-8s${RST}${NORD_POLAR_4} 󰁔 ${RST}${NORD_SNOW_1}%s${RST}\n" "off"    "Disconnect tunnel"
        printf "  ${NORD_CYAN}%-8s${RST}${NORD_POLAR_4} 󰁔 ${RST}${NORD_SNOW_1}%s${RST}\n" "rotate" "Rotate WARP credentials"
        printf "  ${NORD_CYAN}%-8s${RST}${NORD_POLAR_4} 󰁔 ${RST}${NORD_SNOW_1}%s${RST}\n" "status" "Show tunnel status"
        echo ""
        exit 1
        ;;
esac