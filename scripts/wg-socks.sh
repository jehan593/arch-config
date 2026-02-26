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

HEADER_LINE="${NORD_POLAR_4}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"

BINARY_PATH="/usr/bin/wireproxy"
CONF_DIR="/etc/wireproxy"

# Elevation check
if [ "$EUID" -ne 0 ]; then
    echo -e "\n${NORD_ORANGE}󰒃${RST}  ${NORD_SNOW_1}Elevating privileges for wg-socks...${RST}"
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

install_socks() {
    if [[ -z "$1" || -z "$2" ]]; then
        _print_header "${NORD_RED}󰅙${RST}" "Installation Error"
        _print_status "󰅙" "Usage: wg-socks install <config_path> <port>"
        _print_footer; exit 1
    fi

    [[ -f "$BINARY_PATH" ]] || {
        _print_header "${NORD_RED}󰅙${RST}" "Missing Binary"
        _print_status "󰅙" "wireproxy not found at $BINARY_PATH"
        _print_footer; exit 1
    }

    CONFIG_PATH=$(realpath "$1" 2>/dev/null) || {
        _print_header "${NORD_RED}󰅙${RST}" "File Error"
        _print_status "󰅙" "File not found: $1"
        _print_footer; exit 1
    }

    PORT=$2
    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
        _print_header "${NORD_RED}󰅙${RST}" "Port Error"
        _print_status "󰅙" "Invalid port: $PORT"
        _print_footer; exit 1
    fi

    ss -tlnp | grep -q ":$PORT " && {
        _print_header "${NORD_RED}󰅙${RST}" "Port Conflict"
        _print_status "󰅙" "Port $PORT is already in use."
        _print_footer; exit 1
    }

    local CONFIG_BASE=$(basename "$CONFIG_PATH" .conf)
    local SERVICE_NAME="${CONFIG_BASE}-wgsocks"
    local CONF_DEST="$CONF_DIR/${CONFIG_BASE}.conf"

    _print_header "${NORD_CYAN}󰖂${RST}" "Installing Tunnel: $CONFIG_BASE"

    mkdir -p "$CONF_DIR"
    cp "$CONFIG_PATH" "$CONF_DEST"
    chmod 600 "$CONF_DEST"
    _print_row "󰄬" "Config" "Copied to $CONF_DIR"

    if grep -q "BindAddress" "$CONF_DEST"; then
        sed -i "s/BindAddress = .*/BindAddress = 127.0.0.1:$PORT/" "$CONF_DEST"
    else
        echo -e "\n[Socks5]\nBindAddress = 127.0.0.1:$PORT" >> "$CONF_DEST"
    fi
    _print_row "󰄬" "SOCKS5" "Bound to 127.0.0.1:$PORT"

    cat <<EOF > /etc/systemd/system/${SERVICE_NAME}.service
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
EOF

    _run "Daemon reload" systemctl daemon-reload
    _run "Enable service" systemctl enable "$SERVICE_NAME"
    _run "Start service" systemctl restart "$SERVICE_NAME"

    _print_row "󱄄" "Service" "$SERVICE_NAME"
    _print_row "󰩟" "Port" "$PORT"
    _print_row "󰋊" "Status" "$(systemctl is-active "$SERVICE_NAME")"
    _print_footer
}

list_socks() {
    shopt -s nullglob
    local services=(/etc/systemd/system/*-wgsocks.service)

    _print_header "${NORD_CYAN}󰖂${RST}" "Active SOCKS5 Tunnels"

    if [[ ${#services[@]} -eq 0 ]]; then
        _print_status "󰋼" "No tunnels found."
        _print_footer; return
    fi

    printf "${NORD_POLAR_4}│${RST}  ${NORD_D_BLUE}%-25s %-12s %-10s${RST}\n" "SERVICE" "STATUS" "PORT"
    echo -e "${NORD_POLAR_4}├─────────────────────────────────────────────────────${RST}"

    for service in "${services[@]}"; do
        local NAME=$(basename "$service" .service)
        local STATUS=$(systemctl is-active "$NAME")
        local CONF_FILE="$CONF_DIR/${NAME%-wgsocks}.conf"
        local PORT=$(grep "BindAddress" "$CONF_FILE" 2>/dev/null | tr -d ' ' | awk -F':' '{print $NF}')

        [[ "$STATUS" == "active" ]] && S_COL="${NORD_GREEN}" || S_COL="${NORD_RED}"

        printf "${NORD_POLAR_4}│${RST}  ${NORD_BLUE}%-25s${RST} ${S_COL}${STATUS}${RST}%-$((12 - ${#STATUS}))s ${NORD_SNOW_1}%s${RST}\n" "$NAME" "" "$PORT"
    done
    _print_footer
}

start_socks() {
    if [[ -z "$1" ]]; then
        _print_header "${NORD_RED}󰅙${RST}" "Error"
        _print_status "󰅙" "Usage: wg-socks start <n>"
        _print_footer; exit 1
    fi
    local NAME=${1%-wgsocks}
    local SERVICE="${NAME}-wgsocks"
    _print_header "${NORD_GREEN}󰐊${RST}" "Starting Tunnel"
    _run "Start service" systemctl start "$SERVICE"
    _print_row "󰋊" "Service" "$SERVICE"
    _print_row "󱄄" "Status" "$(systemctl is-active "$SERVICE")"
    _print_footer
}

stop_socks() {
    if [[ -z "$1" ]]; then
        _print_header "${NORD_RED}󰅙${RST}" "Error"
        _print_status "󰅙" "Usage: wg-socks stop <n>"
        _print_footer; exit 1
    fi
    local NAME=${1%-wgsocks}
    local SERVICE="${NAME}-wgsocks"
    _print_header "${NORD_RED}󰓛${RST}" "Stopping Tunnel"
    _run "Stop service" systemctl stop "$SERVICE"
    _print_row "󰋊" "Service" "$SERVICE"
    _print_row "󰤭" "Status" "$(systemctl is-active "$SERVICE")"
    _print_footer
}

test_socks() {
    if [[ -z "$1" ]]; then
        _print_header "${NORD_RED}󰅙${RST}" "Error"
        _print_status "󰅙" "Usage: wg-socks test <n>"
        _print_footer; exit 1
    fi
    local NAME=${1%-wgsocks}
    local CONF_FILE="$CONF_DIR/${NAME}.conf"
    [[ -f "$CONF_FILE" ]] || {
        _print_header "${NORD_RED}󰅙${RST}" "Error"
        _print_status "󰅙" "Config not found for '$NAME'"
        _print_footer; exit 1
    }

    local PORT=$(grep "BindAddress" "$CONF_FILE" | tr -d ' ' | awk -F':' '{print $NF}')

    _print_header "${NORD_CYAN}󰛳${RST}" "Testing Tunnel: $NAME"
    _print_status "󰒓" "Fetching public IP via port $PORT..."

    local IP
    IP=$(curl -s --max-time 10 --socks5-hostname "127.0.0.1:$PORT" https://ifconfig.me 2>/dev/null) \
    || IP=$(curl -s --max-time 10 --socks5-hostname "127.0.0.1:$PORT" https://api.ipify.org 2>/dev/null)

    if [[ -n "$IP" ]]; then
        _print_row "󰄬" "SOCKS5" "Working"
        _print_row "󰩟" "IP" "$IP"
    else
        _print_status "󰅙" "Test failed. Is the service running?"
        _print_status "󰋼" "Try: wg-socks logs $NAME"
    fi
    _print_footer
}

remove_socks() {
    if [[ -z "$1" ]]; then
        _print_header "${NORD_RED}󰅙${RST}" "Error"
        _print_status "󰅙" "Usage: wg-socks remove <n>"
        _print_footer; exit 1
    fi
    local NAME=${1%-wgsocks}
    local SERVICE="${NAME}-wgsocks"
    local SERVICE_FILE="/etc/systemd/system/${SERVICE}.service"
    local CONF_FILE="$CONF_DIR/${NAME}.conf"

    [[ -f "$SERVICE_FILE" ]] || {
        _print_header "${NORD_RED}󰅙${RST}" "Error"
        _print_status "󰅙" "Service '$SERVICE' not found."
        _print_footer; exit 1
    }

    _print_header "${NORD_RED}󰆑${RST}" "Remove Tunnel"
    _print_status "󰀦" "Danger: This will delete $SERVICE"
    printf "${NORD_POLAR_4}│${RST}  ${NORD_SNOW_1}Confirm removal? [y/N]: ${RST}"
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        _run "Stop service" systemctl stop "$SERVICE"
        _run "Disable service" systemctl disable "$SERVICE"
        rm -f "$SERVICE_FILE" "$CONF_FILE"
        _run "Daemon reload" systemctl daemon-reload
        _print_status "󰄬" "Removal complete."
    else
        _print_status "󰋼" "Aborted."
    fi
    _print_footer
}

show_logs() {
    if [[ -z "$1" ]]; then
        _print_header "${NORD_RED}󰅙${RST}" "Error"
        _print_status "󰅙" "Usage: wg-socks logs <n>"
        _print_footer; exit 1
    fi
    local NAME=${1%-wgsocks}
    local SERVICE="${NAME}-wgsocks"
    _print_header "${NORD_BLUE}󰟠${RST}" "Logs: $SERVICE"
    journalctl -u "$SERVICE" -f
}

# --- Router ---
case "$1" in
    install) install_socks "$2" "$3" ;;
    list)    list_socks ;;
    start)   start_socks "$2" ;;
    stop)    stop_socks "$2" ;;
    remove)  remove_socks "$2" ;;
    logs)    show_logs "$2" ;;
    test)    test_socks "$2" ;;
    *)
        _print_header "${NORD_CYAN}󰖂${RST}" "WireGuard SOCKS5 Manager"
        printf "${NORD_POLAR_4}│${RST}  ${NORD_BLUE}%-8s${RST} ${NORD_SNOW_1}%-40s${RST}\n" "install" "<conf> <port>  Install new tunnel"
        printf "${NORD_POLAR_4}│${RST}  ${NORD_BLUE}%-8s${RST} ${NORD_SNOW_1}%-40s${RST}\n" "list"    "               List all tunnels"
        printf "${NORD_POLAR_4}│${RST}  ${NORD_BLUE}%-8s${RST} ${NORD_SNOW_1}%-40s${RST}\n" "start"   "<n>      Start tunnel"
        printf "${NORD_POLAR_4}│${RST}  ${NORD_BLUE}%-8s${RST} ${NORD_SNOW_1}%-40s${RST}\n" "stop"    "<n>      Stop tunnel"
        printf "${NORD_POLAR_4}│${RST}  ${NORD_BLUE}%-8s${RST} ${NORD_SNOW_1}%-40s${RST}\n" "test"    "<n>      Check public IP"
        printf "${NORD_POLAR_4}│${RST}  ${NORD_BLUE}%-8s${RST} ${NORD_SNOW_1}%-40s${RST}\n" "logs"    "<n>      Live log feed"
        printf "${NORD_POLAR_4}│${RST}  ${NORD_BLUE}%-8s${RST} ${NORD_SNOW_1}%-40s${RST}\n" "remove"  "<n>      Delete tunnel"
        _print_footer
        exit 1
        ;;
esac