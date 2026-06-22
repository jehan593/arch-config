#!/bin/bash

# WireGuard SOCKS5 Manager

source "$HOME/arch-config/scripts/helpers.sh"

BINARY_PATH="/usr/bin/wireproxy"
CONF_DIR="/etc/wireproxy"
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

if [ "$EUID" -ne 0 ]; then
    echo -e "${NORD_CYAN}󰌆  Elevating...${RST}"
    exec sudo -E bash "$(realpath "$0")" "$@"
fi

_socks_info() {
    local service="$1"
    NAME=$(basename "$service" .service)
    STATUS=$(systemctl is-active "$NAME")
    CONF_FILE="$CONF_DIR/${NAME%-wgsocks}.conf"
    PORT=$(grep "BindAddress" "$CONF_FILE" 2>/dev/null | tr -d ' ' | awk -F':' '{print $NF}')
    [[ "$STATUS" == "active" ]] && S_COL="${NORD_GREEN}" || S_COL="${NORD_RED}"
}

install_socks() {
    if [[ -z "$1" || -z "$2" ]]; then
        _print_status "󰀦" "Usage: wg-socks install <config_path> <port>"
        return 1
    fi

    if [[ ! -f "$BINARY_PATH" ]]; then
        _print_status "󰅙" "wireproxy not found"
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

    _print_header "󱌣" "Installing: $CONFIG_BASE"

    mkdir -p "$CONF_DIR"
    cp "$CONFIG_PATH" "$CONF_DEST"
    chmod 600 "$CONF_DEST"
    _print_status "󰄬" "Config copied"

    if grep -q "BindAddress" "$CONF_DEST"; then
        sed -i "s/BindAddress = .*/BindAddress = 127.0.0.1:$PORT/" "$CONF_DEST"
    else
        echo -e "\n[Socks5]\nBindAddress = 127.0.0.1:$PORT" >> "$CONF_DEST"
    fi
    _print_status "󰄬" "SOCKS5 bound to port $PORT"

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
    _print_result $? "Reloaded daemon"

    systemctl enable "$SERVICE_NAME"
    _print_result $? "Enabled service"

    systemctl restart "$SERVICE_NAME"
    _print_result $? "Started service"

    echo ""
}

list_socks() {
    shopt -s nullglob
    local services=(/etc/systemd/system/*-wgsocks.service)

    _print_header "󰒄" "SOCKS5 Tunnels"

    if [[ ${#services[@]} -eq 0 ]]; then
        _print_status "󰅙" "No tunnels found"
        echo ""; return
    fi

    printf "  ${NORD_D_BLUE}%-25s %-12s %-10s${RST}\n" "SERVICE" "STATUS" "PORT"
    echo -e " ${NORD_POLAR_4}─────────────────────────────────────────────────────${RST}"

    for service in "${services[@]}"; do
        _socks_info "$service"
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
        _print_status "󰅙" "No tunnels found"
        echo ""; return
    fi

    printf "  ${NORD_D_BLUE}%-6s %-25s %-12s %-10s${RST}\n" "NO." "SERVICE" "STATUS" "PORT"
    echo -e " ${NORD_POLAR_4}─────────────────────────────────────────────────────${RST}"

    local i=1
    for service in "${services[@]}"; do
        _socks_info "$service"
        printf "  ${NORD_CYAN}%-6s${RST} ${NORD_BLUE}%-25s${RST} ${S_COL}%-12s${RST} ${NORD_SNOW_1}%s${RST}\n" \
            "$i" "$NAME" "$STATUS" "$PORT"
        (( i++ ))
    done

    echo ""
    read -p "$(echo -e "${NORD_BLUE}Enter numbers to uninstall (comma separated): ${RST}")" input
    [[ -z "$input" ]] && { _print_status "󰀦" "Cancelled"; echo ""; return; }

    IFS=',' read -ra selections <<< "$input"
    local to_remove=()
    for sel in "${selections[@]}"; do
        sel=$(echo "$sel" | tr -d ' ')
        if ! [[ "$sel" =~ ^[0-9]+$ ]] || (( sel < 1 || sel >= i )); then
            _print_status "󰅙" "Invalid selection: $sel"
            continue
        fi
        to_remove+=("${services[$((sel - 1))]}")
    done

    if [[ ${#to_remove[@]} -eq 0 ]]; then
        _print_status "󰅙" "No valid selections"
        echo ""; return
    fi

    echo ""
    _print_status "󰀦" "Will uninstall ${#to_remove[@]} tunnel(s):"
    for service in "${to_remove[@]}"; do
        echo -e "  ${NORD_RED}󰆑  $(basename "$service" .service)${RST}"
    done

    echo ""
    read -p "$(echo -e "${NORD_BLUE}Confirm? [y/N]: ${RST}")" confirm
    [[ ! "$confirm" =~ ^[Yy]$ ]] && { _print_status "󰀦" "Cancelled"; echo ""; return; }

    echo ""
    local DESKTOP="$REAL_HOME/Desktop"
    mkdir -p "$DESKTOP"

    for service in "${to_remove[@]}"; do
        local NAME=$(basename "$service" .service)
        local CONF_FILE="$CONF_DIR/${NAME%-wgsocks}.conf"

        if [[ -f "$CONF_FILE" ]]; then
            cp "$CONF_FILE" "$DESKTOP/${NAME%-wgsocks}-wgsocks-backup.conf"
            _print_status "󰄬" "Backup saved to Desktop"
        fi

        systemctl stop "$NAME"
        systemctl disable "$NAME"
        rm -f "$service" "$CONF_FILE"
        systemctl daemon-reload
        _print_status "󰄬" "Removed $NAME"
        echo ""
    done
}

refresh_socks() {
    shopt -s nullglob
    local services=(/etc/systemd/system/*-wgsocks.service)

    _print_header "󰑮" "Refreshing Tunnels"

    if [[ ${#services[@]} -eq 0 ]]; then
        _print_status "󰅙" "No tunnels found"
        echo ""; return
    fi

    for service in "${services[@]}"; do
        local NAME=$(basename "$service" .service)
        systemctl restart "$NAME"
        _print_result $? "Restarted $NAME"
    done

    echo ""
}

case "$1" in
    install)   install_socks "$2" "$3" ;;
    list)      list_socks ;;
    uninstall) uninstall_socks ;;
    refresh)   refresh_socks ;;
    *)
        _print_header "󰒄" "SOCKS5 Manager"
        printf "  ${NORD_CYAN}%-12s${RST}${NORD_POLAR_4} 󰁔 ${RST}${NORD_SNOW_1}%s${RST}\n" "install"   "<conf> <port>  Install SOCKS5 tunnel"
        printf "  ${NORD_CYAN}%-12s${RST}${NORD_POLAR_4} 󰁔 ${RST}${NORD_SNOW_1}%s${RST}\n" "list"      "List tunnels"
        printf "  ${NORD_CYAN}%-12s${RST}${NORD_POLAR_4} 󰁔 ${RST}${NORD_SNOW_1}%s${RST}\n" "uninstall" "Uninstall tunnels"
        printf "  ${NORD_CYAN}%-12s${RST}${NORD_POLAR_4} 󰁔 ${RST}${NORD_SNOW_1}%s${RST}\n" "refresh"   "Restart tunnels"
        echo ""
        exit 1
        ;;
esac