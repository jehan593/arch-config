#!/bin/bash

# ==============================================================================
# WIREGUARD SOCKS5 MANAGER (Nord Aesthetic)
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

BINARY_PATH="/usr/bin/wireproxy"
CONF_DIR="/etc/wireproxy"
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

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

# --- Actions ---

install_socks() {
    if [[ -z "$1" || -z "$2" ]]; then
        _print_status "󰀦" "Usage: wg-socks install <config_path> <port>"
        return 1
    fi

    if [[ ! -f "$BINARY_PATH" ]]; then
        _print_status "󰅙" "wireproxy not found at $BINARY_PATH"
        return 1
    fi

    CONFIG_PATH=$(realpath "$1" 2>/dev/null)
    if [[ -z "$CONFIG_PATH" ]]; then
        _print_status "󰅙" "File not found: $1"
        return 1
    fi

    PORT=$2
    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
        _print_status "󰅙" "Invalid port: $PORT"
        return 1
    fi

    if ss -tlnp | grep -q ":$PORT "; then
        _print_status "󰅙" "Port $PORT is already in use"
        return 1
    fi

    local CONFIG_BASE=$(basename "$CONFIG_PATH" .conf)
    local SERVICE_NAME="${CONFIG_BASE}-wgsocks"
    local CONF_DEST="$CONF_DIR/${CONFIG_BASE}.conf"

    _print_header "󱌣" "Installing Tunnel: $CONFIG_BASE"

    mkdir -p "$CONF_DIR"
    cp "$CONFIG_PATH" "$CONF_DEST"
    chmod 600 "$CONF_DEST"
    _print_status "󰄬" "Config copied to $CONF_DIR"

    if grep -q "BindAddress" "$CONF_DEST"; then
        sed -i "s/BindAddress = .*/BindAddress = 127.0.0.1:$PORT/" "$CONF_DEST"
    else
        echo -e "\n[Socks5]\nBindAddress = 127.0.0.1:$PORT" >> "$CONF_DEST"
    fi
    _print_status "󰄬" "SOCKS5 bound to 127.0.0.1:$PORT"

    cat <<UNIT > /etc/systemd/system/${SERVICE_NAME}.service
[Unit]
Description=WireGuard Socks5 ($CONFIG_BASE)
After=network.target

[Service]
Type=simple
ExecStart=$BINARY_PATH -c $CONF_DEST
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

    systemctl daemon-reload
    _print_status "$([ $? -eq 0 ] && echo 󰄬 || echo 󰅙)" "Daemon reloaded"

    systemctl enable "$SERVICE_NAME"
    _print_status "$([ $? -eq 0 ] && echo 󰄬 || echo 󰅙)" "Service enabled"

    systemctl restart "$SERVICE_NAME"
    _print_status "$([ $? -eq 0 ] && echo 󰄬 || echo 󰅙)" "Service started — port $PORT"

    echo ""
}

list_socks() {
    shopt -s nullglob
    local services=(/etc/systemd/system/*-wgsocks.service)

    _print_header "󰒄" "SOCKS5 Tunnels"

    if [[ ${#services[@]} -eq 0 ]]; then
        _print_status "󰋼" "No tunnels found."
        echo ""; return
    fi

    printf "  ${NORD_D_BLUE}%-25s %-12s %-10s${RST}\n" "SERVICE" "STATUS" "PORT"
    echo -e "${NORD_POLAR_4}─────────────────────────────────────────────────────${RST}"

    for service in "${services[@]}"; do
        local NAME=$(basename "$service" .service)
        local STATUS=$(systemctl is-active "$NAME")
        local CONF_FILE="$CONF_DIR/${NAME%-wgsocks}.conf"
        local PORT=$(grep "BindAddress" "$CONF_FILE" 2>/dev/null | tr -d ' ' | awk -F':' '{print $NF}')
        [[ "$STATUS" == "active" ]] && S_COL="${NORD_GREEN}" || S_COL="${NORD_RED}"
        printf "  ${NORD_BLUE}%-25s${RST} ${S_COL}%-12s${RST} ${NORD_SNOW_1}%s${RST}\n" \
            "$NAME" "$STATUS" "$PORT"
    done

    echo ""
}

uninstall_socks() {
    shopt -s nullglob
    local services=(/etc/systemd/system/*-wgsocks.service)

    _print_header "󰆑" "Uninstall Tunnel"

    if [[ ${#services[@]} -eq 0 ]]; then
        _print_status "󰋼" "No tunnels found."
        echo ""; return
    fi

    printf "  ${NORD_D_BLUE}%-6s %-25s %-12s %-10s${RST}\n" "NO." "SERVICE" "STATUS" "PORT"
    echo -e "${NORD_POLAR_4}─────────────────────────────────────────────────────${RST}"

    local i=1
    for service in "${services[@]}"; do
        local NAME=$(basename "$service" .service)
        local STATUS=$(systemctl is-active "$NAME")
        local CONF_FILE="$CONF_DIR/${NAME%-wgsocks}.conf"
        local PORT=$(grep "BindAddress" "$CONF_FILE" 2>/dev/null | tr -d ' ' | awk -F':' '{print $NF}')
        [[ "$STATUS" == "active" ]] && S_COL="${NORD_GREEN}" || S_COL="${NORD_RED}"
        printf "  ${NORD_CYAN}%-6s${RST} ${NORD_BLUE}%-25s${RST} ${S_COL}%-12s${RST} ${NORD_SNOW_1}%s${RST}\n" \
            "$i" "$NAME" "$STATUS" "$PORT"
        (( i++ ))
    done

    echo ""
    read -p "$(echo -e "${NORD_BLUE}Enter numbers to uninstall (comma separated): ${RST}")" input
    [[ -z "$input" ]] && { _print_status "󰋼" "Aborted."; echo ""; return; }

    IFS=',' read -ra selections <<< "$input"
    local to_remove=()
    for sel in "${selections[@]}"; do
        sel=$(echo "$sel" | tr -d ' ')
        if ! [[ "$sel" =~ ^[0-9]+$ ]] || (( sel < 1 || sel >= i )); then
            _print_status "󰅙" "Invalid selection: $sel — skipping"
            continue
        fi
        to_remove+=("${services[$((sel - 1))]}")
    done

    if [[ ${#to_remove[@]} -eq 0 ]]; then
        _print_status "󰅙" "No valid selections."
        echo ""; return
    fi

    echo ""
    _print_status "󰀦" "Will uninstall ${#to_remove[@]} tunnel(s):"
    for service in "${to_remove[@]}"; do
        echo -e "  ${NORD_RED}󰆑  $(basename "$service" .service)${RST}"
    done

    echo ""
    read -p "$(echo -e "${NORD_BLUE}Confirm? [y/N]: ${RST}")" confirm
    [[ ! "$confirm" =~ ^[Yy]$ ]] && { _print_status "󰋼" "Aborted."; echo ""; return; }

    echo ""
    local DESKTOP="$REAL_HOME/Desktop"
    mkdir -p "$DESKTOP"

    for service in "${to_remove[@]}"; do
        local NAME=$(basename "$service" .service)
        local CONF_FILE="$CONF_DIR/${NAME%-wgsocks}.conf"

        if [[ -f "$CONF_FILE" ]]; then
            cp "$CONF_FILE" "$DESKTOP/${NAME%-wgsocks}-wgsocks-backup.conf"
            _print_status "󰄬" "Backed up to Desktop/${NAME%-wgsocks}-wgsocks-backup.conf"
        fi

        systemctl stop "$NAME"
        systemctl disable "$NAME"
        rm -f "$service" "$CONF_FILE"
        systemctl daemon-reload
        _print_status "󰄬" "$NAME removed"
        echo ""
    done
}

refresh_socks() {
    shopt -s nullglob
    local services=(/etc/systemd/system/*-wgsocks.service)

    _print_header "󰑮" "Refreshing Tunnels"

    if [[ ${#services[@]} -eq 0 ]]; then
        _print_status "󰋼" "No tunnels found."
        echo ""; return
    fi

    for service in "${services[@]}"; do
        local NAME=$(basename "$service" .service)
        _print_status "󰑐" "$NAME"
        systemctl restart "$NAME"
        _print_status "$([ $? -eq 0 ] && echo 󰄬 || echo 󰅙)" "$([ $? -eq 0 ] && echo Restarted || echo Failed)"
    done

    echo ""
}

# --- Router ---
case "$1" in
    install)   install_socks "$2" "$3" ;;
    list)      list_socks ;;
    uninstall) uninstall_socks ;;
    refresh)   refresh_socks ;;
    *)
        _print_header "󰒄" "WireGuard SOCKS5 Manager"
        printf "  ${NORD_CYAN}%-12s${RST}${NORD_POLAR_4} 󰁔 ${RST}${NORD_SNOW_1}%s${RST}\n" "install"   "<conf> <port>  Install new tunnel"
        printf "  ${NORD_CYAN}%-12s${RST}${NORD_POLAR_4} 󰁔 ${RST}${NORD_SNOW_1}%s${RST}\n" "list"      "List all tunnels"
        printf "  ${NORD_CYAN}%-12s${RST}${NORD_POLAR_4} 󰁔 ${RST}${NORD_SNOW_1}%s${RST}\n" "uninstall" "Uninstall tunnel(s)"
        printf "  ${NORD_CYAN}%-12s${RST}${NORD_POLAR_4} 󰁔 ${RST}${NORD_SNOW_1}%s${RST}\n" "refresh"   "Restart all tunnels"
        echo ""
        exit 1
        ;;
esac