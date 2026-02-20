#!/bin/bash

# If not running as root, restart the script with sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "\033[0;34m🔐 Elevating privileges for wg-socks...\033[0m"
    exec sudo bash "$(realpath "$0")" "$@"
fi

BINARY_PATH="/usr/bin/wireproxy"
CONF_DIR="/etc/wireproxy"

# --- Actions ---

install_socks() {
    if [[ -z "$1" || -z "$2" ]]; then
        echo "Usage: wg-socks install <config_path> <port>"
        exit 1
    fi

    # Validate config file exists
    CONFIG_PATH=$(realpath "$1" 2>/dev/null) || { echo "Error: File not found: $1"; exit 1; }
    [[ -f "$CONFIG_PATH" ]] || { echo "Error: Not a file: $CONFIG_PATH"; exit 1; }

    # Validate port
    PORT=$2
    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
        echo "Error: Invalid port '$PORT'. Must be a number between 1 and 65535."
        exit 1
    fi

    CONFIG_BASE=$(basename "$CONFIG_PATH" .conf)
    SERVICE_NAME="${CONFIG_BASE}-wgsocks"
    CONF_DEST="$CONF_DIR/${CONFIG_BASE}.conf"

    mkdir -p "$CONF_DIR"
    cp "$CONFIG_PATH" "$CONF_DEST"
    chmod 600 "$CONF_DEST"

    # Port Injection
    if grep -q "BindAddress" "$CONF_DEST"; then
        sed -i "s/BindAddress = .*/BindAddress = 0.0.0.0:$PORT/" "$CONF_DEST"
    else
        echo -e "\n[Socks5]\nBindAddress = 0.0.0.0:$PORT" >> "$CONF_DEST"
    fi

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
    systemctl enable "$SERVICE_NAME"
    systemctl restart "$SERVICE_NAME"
    echo "SUCCESS: $SERVICE_NAME is active on port $PORT"
}

list_socks() {
    shopt -s nullglob
    services=(/etc/systemd/system/*-wgsocks.service)

    if [[ ${#services[@]} -eq 0 ]]; then
        echo "No tunnels found."
        return
    fi

    printf "%-30s %-10s %-10s\n" "SERVICE NAME" "STATUS" "PORT"
    echo "------------------------------------------------------------"

    for service in "${services[@]}"; do
        NAME=$(basename "$service" .service)
        STATUS=$(systemctl is-active "$NAME")
        CONF_FILE="$CONF_DIR/${NAME%-wgsocks}.conf"
        PORT=$(grep "BindAddress" "$CONF_FILE" | tr -d ' ' | awk -F':' '{print $NF}')
        printf "%-30s %-10s %-10s\n" "$NAME" "$STATUS" "$PORT"
    done
}

test_socks() {
    NAME=$1
    [[ -z "$NAME" ]] && { echo "Usage: wg-socks test <name>"; exit 1; }

    # Accept both "myconfig" and "myconfig-wgsocks"
    CONF_FILE="$CONF_DIR/${NAME%-wgsocks}.conf"
    [[ -f "$CONF_FILE" ]] || { echo "Error: Config not found for '$NAME'"; exit 1; }

    PORT=$(grep "BindAddress" "$CONF_FILE" | tr -d ' ' | awk -F':' '{print $NF}')
    [[ -z "$PORT" ]] && { echo "Error: Could not determine port from config."; exit 1; }

    echo "Testing proxy on port $PORT..."
    IP=$(curl -s --socks5-hostname "127.0.0.1:$PORT" https://ifconfig.me)

    if [[ $? -eq 0 && -n "$IP" ]]; then
        echo "Proxy Working! IP: $IP"
    else
        echo "Test Failed. Is the service running? Try: wg-socks logs ${NAME%-wgsocks}-wgsocks"
    fi
}

remove_socks() {
    NAME=$1
    [[ -z "$NAME" ]] && { echo "Usage: wg-socks remove <name>"; exit 1; }

    SERVICE_FILE="/etc/systemd/system/${NAME}.service"
    CONF_FILE="$CONF_DIR/${NAME%-wgsocks}.conf"

    [[ -f "$SERVICE_FILE" ]] || { echo "Error: Service '$NAME' not found."; exit 1; }

    systemctl stop "$NAME"
    systemctl disable "$NAME"
    rm -f "$SERVICE_FILE"
    rm -f "$CONF_FILE"
    systemctl daemon-reload
    echo "Removed $NAME."
}

show_logs() {
    [[ -z "$1" ]] && { echo "Usage: wg-socks logs <name>"; exit 1; }

    # Accept both "myconfig" and "myconfig-wgsocks"
    NAME=$1
    [[ "$NAME" != *-wgsocks ]] && NAME="${NAME}-wgsocks"

    journalctl -u "$NAME" -f
}

# --- Router ---
case "$1" in
    install) install_socks "$2" "$3" ;;
    list)    list_socks ;;
    remove)  remove_socks "$2" ;;
    logs)    show_logs "$2" ;;
    test)    test_socks "$2" ;;
    *)
        echo "Usage: wg-socks {install|list|remove|logs|test}"
        echo ""
        echo "  install <config_path> <port>  Install a new WireGuard SOCKS5 tunnel"
        echo "  list                          List all tunnels and their status"
        echo "  test <name>                   Test a tunnel by checking its public IP"
        echo "  logs <name>                   Follow live logs for a tunnel"
        echo "  remove <name>                 Stop and remove a tunnel"
        exit 1
        ;;
esac