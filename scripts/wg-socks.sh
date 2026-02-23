#!/bin/bash

# Nord Colors
CYAN='\033[38;2;143;188;187m'
BLUE='\033[38;2;136;192;208m'
D_BLUE='\033[38;2;129;161;193m'
GREEN='\033[38;2;163;190;140m'
RED='\033[38;2;191;97;106m'
RST='\033[0m'

BINARY_PATH="/usr/bin/wireproxy"
CONF_DIR="/etc/wireproxy"

# If not running as root, restart the script with sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${BLUE}󰒃  Elevating privileges for wg-socks...${RST}"
    exec sudo bash "$(realpath "$0")" "$@"
fi

# --- Helpers ---

print_header() {
    echo -e "\n  ${CYAN}󰖂  $1${RST}"
    echo -e "     ${D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
}

print_footer() {
    echo -e "     ${D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}\n"
}

print_row() {
    printf "     ${BLUE}%-2s ${D_BLUE} %-12s ${RST}${BLUE}%s${RST}\n" "$1" "$2" "$3"
}

print_ok()   { printf "     ${GREEN}󰄬  %s${RST}\n" "$1"; }
print_err()  { printf "     ${RED}󰅙  %s${RST}\n" "$1"; }
print_info() { printf "     ${BLUE}󰋼  %s${RST}\n" "$1"; }

# --- Actions ---

install_socks() {
    if [[ -z "$1" || -z "$2" ]]; then
        print_header "Install Tunnel"
        print_err "Usage: wg-socks install <config_path> <port>"
        print_footer
        exit 1
    fi

    # Check wireproxy is installed
    [[ -f "$BINARY_PATH" ]] || { print_err "wireproxy not found at $BINARY_PATH"; exit 1; }

    # Validate config file
    CONFIG_PATH=$(realpath "$1" 2>/dev/null) || { print_err "File not found: $1"; exit 1; }
    [[ -f "$CONFIG_PATH" ]] || { print_err "Not a file: $CONFIG_PATH"; exit 1; }

    # Validate port
    PORT=$2
    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
        print_err "Invalid port '$PORT'. Must be a number between 1 and 65535."
        exit 1
    fi

    # Check port not already in use
    ss -tlnp | grep -q ":$PORT " && { print_err "Port $PORT is already in use."; exit 1; }

    CONFIG_BASE=$(basename "$CONFIG_PATH" .conf)
    SERVICE_NAME="${CONFIG_BASE}-wgsocks"
    CONF_DEST="$CONF_DIR/${CONFIG_BASE}.conf"

    print_header "Installing Tunnel"

    mkdir -p "$CONF_DIR"
    cp "$CONFIG_PATH" "$CONF_DEST"
    chmod 600 "$CONF_DEST"
    print_info "Config copied to $CONF_DEST"

    # Port Injection
    if grep -q "BindAddress" "$CONF_DEST"; then
        sed -i "s/BindAddress = .*/BindAddress = 127.0.0.1:$PORT/" "$CONF_DEST"
    else
        echo -e "\n[Socks5]\nBindAddress = 127.0.0.1:$PORT" >> "$CONF_DEST"
    fi
    print_info "SOCKS5 bound to 127.0.0.1:$PORT"

    # Create Systemd Service
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

    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME" &>/dev/null
    systemctl restart "$SERVICE_NAME"

    print_row "󰄬" "Service" "$SERVICE_NAME"
    print_row "󰩟" "Port" "$PORT"
    print_row "󰋊" "Status" "$(systemctl is-active "$SERVICE_NAME")"
    print_footer
}

list_socks() {
    shopt -s nullglob
    services=(/etc/systemd/system/*-wgsocks.service)

    print_header "Active Tunnels"

    if [[ ${#services[@]} -eq 0 ]]; then
        print_info "No tunnels found."
        print_footer
        return
    fi

    printf "     ${D_BLUE}%-30s %-12s %-10s${RST}\n" "SERVICE" "STATUS" "PORT"
    echo -e "     ${D_BLUE}──────────────────────────────────────────────────${RST}"

    for service in "${services[@]}"; do
        NAME=$(basename "$service" .service)
        STATUS=$(systemctl is-active "$NAME")
        CONF_FILE="$CONF_DIR/${NAME%-wgsocks}.conf"
        PORT=$(grep "BindAddress" "$CONF_FILE" 2>/dev/null | tr -d ' ' | awk -F':' '{print $NF}')

        if [[ "$STATUS" == "active" ]]; then
            STATUS_COLOR="${GREEN}${STATUS}${RST}"
        else
            STATUS_COLOR="${RED}${STATUS}${RST}"
        fi

        printf "     ${BLUE}%-30s${RST} ${STATUS_COLOR}%-$((12 - ${#STATUS}))s${RST} ${BLUE}%s${RST}\n" "$NAME" "" "$PORT"
    done

    print_footer
}

start_socks() {
    [[ -z "$1" ]] && { print_err "Usage: wg-socks start <name>"; exit 1; }
    NAME=$1
    [[ "$NAME" != *-wgsocks ]] && NAME="${NAME}-wgsocks"
    print_header "Starting Tunnel"
    systemctl start "$NAME"
    print_row "$(systemctl is-active "$NAME" | grep -q active && echo 󰄬 || echo 󰅙)" "Service" "$NAME"
    print_row "󰋊" "Status" "$(systemctl is-active "$NAME")"
    print_footer
}

stop_socks() {
    [[ -z "$1" ]] && { print_err "Usage: wg-socks stop <name>"; exit 1; }
    NAME=$1
    [[ "$NAME" != *-wgsocks ]] && NAME="${NAME}-wgsocks"
    print_header "Stopping Tunnel"
    systemctl stop "$NAME"
    print_row "󰋊" "Service" "$NAME"
    print_row "󰤭" "Status" "$(systemctl is-active "$NAME")"
    print_footer
}

test_socks() {
    NAME=$1
    [[ -z "$NAME" ]] && { print_err "Usage: wg-socks test <name>"; exit 1; }

    CONF_FILE="$CONF_DIR/${NAME%-wgsocks}.conf"
    [[ -f "$CONF_FILE" ]] || { print_err "Config not found for '$NAME'"; exit 1; }

    PORT=$(grep "BindAddress" "$CONF_FILE" | tr -d ' ' | awk -F':' '{print $NF}')
    [[ -z "$PORT" ]] && { print_err "Could not determine port from config."; exit 1; }

    print_header "Testing Tunnel"
    print_info "Testing proxy on port $PORT..."

    IP=$(curl -s --max-time 10 --socks5-hostname "127.0.0.1:$PORT" https://ifconfig.me 2>/dev/null \
      || curl -s --max-time 10 --socks5-hostname "127.0.0.1:$PORT" https://api.ipify.org 2>/dev/null)

    if [[ -n "$IP" ]]; then
        print_row "󰄬" "Status" "Proxy working"
        print_row "󰩟" "Public IP" "$IP"
    else
        print_err "Test failed. Is the service running?"
        print_info "Try: wg-socks logs ${NAME%-wgsocks}"
    fi
    print_footer
}

remove_socks() {
    NAME=$1
    [[ -z "$NAME" ]] && { print_err "Usage: wg-socks remove <name>"; exit 1; }

    SERVICE_FILE="/etc/systemd/system/${NAME}.service"
    CONF_FILE="$CONF_DIR/${NAME%-wgsocks}.conf"

    [[ -f "$SERVICE_FILE" ]] || { print_err "Service '$NAME' not found."; exit 1; }

    print_header "Remove Tunnel"
    print_err "This will permanently remove $NAME."
    printf "     ${BLUE}󰋼  Continue? [y/N]: ${RST}"
    read -r confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { print_info "Aborted."; print_footer; exit 0; }

    systemctl stop "$NAME"
    systemctl disable "$NAME" &>/dev/null
    rm -f "$SERVICE_FILE"
    rm -f "$CONF_FILE"
    systemctl daemon-reload

    print_ok "Removed $NAME successfully."
    print_footer
}

show_logs() {
    [[ -z "$1" ]] && { print_err "Usage: wg-socks logs <name>"; exit 1; }
    NAME=$1
    [[ "$NAME" != *-wgsocks ]] && NAME="${NAME}-wgsocks"
    print_header "Logs: $NAME"
    journalctl -u "$NAME" -f
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
        echo -e "\n  ${CYAN}󰖂  WireGuard SOCKS5 Manager${RST}"
        echo -e "     ${D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
        printf "     ${BLUE}%-8s${RST} %-45s\n" "install" "<config_path> <port>  Install a new tunnel"
        printf "     ${BLUE}%-8s${RST} %-45s\n" "list"    "                      List all tunnels"
        printf "     ${BLUE}%-8s${RST} %-45s\n" "start"   "<name>                Start a tunnel"
        printf "     ${BLUE}%-8s${RST} %-45s\n" "stop"    "<name>                Stop a tunnel"
        printf "     ${BLUE}%-8s${RST} %-45s\n" "test"    "<name>                Test tunnel public IP"
        printf "     ${BLUE}%-8s${RST} %-45s\n" "logs"    "<name>                Follow live logs"
        printf "     ${BLUE}%-8s${RST} %-45s\n" "remove"  "<name>                Remove a tunnel"
        echo -e "     ${D_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}\n"
        exit 1
        ;;
esac