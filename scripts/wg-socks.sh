#!/bin/bash

# If not running as root, restart the script with sudo
if [ "$EUID" -ne 0 ]; then 
  echo -e "\033[0;34m🔐 Elevating privileges for wg-socks...\033[0m"
  # "$0" is the script itself, "$@" passes all original arguments
  exec sudo "$0" "$@"
fi

BINARY_PATH="/usr/bin/wireproxy"
CONF_DIR="/etc/wireproxy"

# --- Actions ---

install_socks() {
    if [[ -z "$1" || -z "$2" ]]; then
        echo "Usage: wg-socks install <config_path> <port>"
        exit 1
    fi

    CONFIG_PATH=$(realpath "$1")
    PORT=$2
    CONFIG_BASE=$(basename "$CONFIG_PATH" .conf)
    SERVICE_NAME="${CONFIG_BASE}-wgsocks"
    CONF_DEST="$CONF_DIR/${CONFIG_BASE}.conf"

    mkdir -p "$CONF_DIR"
    cp "$CONFIG_PATH" "$CONF_DEST"

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
    printf "%-30s %-10s %-10s\n" "SERVICE NAME" "STATUS" "PORT"
    echo "------------------------------------------------------------"
    for service in /etc/systemd/system/*-wgsocks.service; do
        [ -e "$service" ] || { echo "No tunnels found."; return; }
        NAME=$(basename "$service" .service)
        STATUS=$(systemctl is-active "$NAME")
        CONF_FILE="$CONF_DIR/${NAME%-wgsocks}.conf"
        PORT=$(grep "BindAddress" "$CONF_FILE" | awk -F':' '{print $NF}')
        printf "%-30s %-10s %-10s\n" "$NAME" "$STATUS" "$PORT"
    done
}

test_socks() {
    NAME=$1
    [[ -z "$NAME" ]] && { echo "Usage: wg-socks test <name>"; exit 1; }
    CONF_FILE="$CONF_DIR/${NAME%-wgsocks}.conf"
    PORT=$(grep "BindAddress" "$CONF_FILE" | awk -F':' '{print $NF}')
    echo "Testing proxy on port $PORT..."
    IP=$(curl -s --socks5-hostname 127.0.0.1:$PORT https://ifconfig.me)
    [ $? -eq 0 ] && echo "Proxy Working! IP: $IP" || echo "Test Failed."
}

remove_socks() {
    NAME=$1
    [[ -z "$NAME" ]] && { echo "Usage: wg-socks remove <name>"; exit 1; }
    systemctl stop "$NAME"
    systemctl disable "$NAME"
    rm -f "/etc/systemd/system/${NAME}.service"
    rm -f "$CONF_DIR/${NAME%-wgsocks}.conf"
    systemctl daemon-reload
    echo "Removed $NAME."
}

show_logs() {
    [[ -z "$1" ]] && { echo "Usage: wg-socks logs <name>"; exit 1; }
    journalctl -u "$1" -f
}

# --- Router ---
case "$1" in
    install) install_socks "$2" "$3" ;;
    list)    list_socks ;;
    remove)  remove_socks "$2" ;;
    logs)    show_logs "$2" ;;
    test)    test_socks "$2" ;;
    *)       echo "Usage: wg-socks {install|list|remove|logs|test}"; exit 1 ;;
esac