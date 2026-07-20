#!/bin/bash

# WireGuard Manager (wpm)

source "$ARCH_CONFIG_PATH/helpers/colors-nord.sh"
source "$ARCH_CONFIG_PATH/helpers/printer.sh"
source "$ARCH_CONFIG_PATH/helpers/dep-checker.sh"
source "$ARCH_CONFIG_PATH/helpers/wpm-helper.sh"

_test_dependencies wireproxy ss fzf || exit 1

BINARY_PATH="/usr/bin/wireproxy"

if [ "$EUID" -ne 0 ]; then
    sudo -n true 2>/dev/null || printfc "$NORD_YELLOW" "Elevating..."
    exec sudo -E bash "$(realpath "$0")" "$@"
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

_wpm_set_paths "$REAL_HOME"

_wpm_tunnel_info() {
    local service="$1"
    NAME=$(basename "$service" .service)
    STATUS=$(systemctl is-active "$NAME")
    CONF_FILE="$CONF_DIR/${NAME%-wpm}.conf"
    PORT=$(grep "BindAddress" "$CONF_FILE" 2>/dev/null | tr -d ' ' | awk -F':' '{print $NF}')
    [[ "$STATUS" == "active" ]] && S_COL="${NORD_GREEN}" || S_COL="${NORD_RED}"
}

wpm_add() {
    if [[ -z "$1" || -z "$2" || -z "$3" ]]; then
        printfc "$NORD_YELLOW" "Usage: wpm add <name> <config> <port>"
        return 1
    fi

    local NAME="$1"
    CONFIG_PATH=$(realpath "$2" 2>/dev/null)
    if [[ -z "$CONFIG_PATH" ]]; then
        printfc "$NORD_RED" "File not found: %s" "$2"
        return 1
    fi

    local SERVICE_NAME="${NAME}-wpm"
    local CONF_DEST="$CONF_DIR/${NAME}.conf"

    if [[ -f "$CONF_DEST" || -f "/etc/systemd/system/${SERVICE_NAME}.service" ]]; then
        printfc "$NORD_RED" "Name '%s' already in use" "$NAME"
        return 1
    fi

    PORT=$3
    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
        printfc "$NORD_RED" "Invalid port: %s" "$PORT"
        return 1
    fi

    if ss -tlnp | grep -q ":$PORT "; then
        printfc "$NORD_RED" "Port %s is already in use" "$PORT"
        return 1
    fi

    local f existing_port
    for f in "$CONF_DIR"/*.conf; do
        [[ -f "$f" ]] || continue
        existing_port=$(grep "BindAddress" "$f" 2>/dev/null | tr -d ' ' | awk -F':' '{print $NF}')
        if [[ "$existing_port" == "$PORT" ]]; then
            printfc "$NORD_RED" "Port %s already assigned to %s" "$PORT" "$(basename "$f" .conf)"
            return 1
        fi
    done

    printfc "$NORD_BLUE" "\n>Installing: %s" "$NAME"

    mkdir -p "$CONF_DIR"
    cp "$CONFIG_PATH" "$CONF_DEST"
    chmod 600 "$CONF_DEST"
    printfc "$NORD_GREEN" "Config copied"

    if grep -q "BindAddress" "$CONF_DEST"; then
        sed -i "s/BindAddress = .*/BindAddress = 127.0.0.1:$PORT/" "$CONF_DEST"
    else
        echo -e "\n[Socks5]\nBindAddress = 127.0.0.1:$PORT" >> "$CONF_DEST"
    fi
    printfc "$NORD_GREEN" "Bound to port %s" "$PORT"

    cat <<UNIT > /etc/systemd/system/${SERVICE_NAME}.service
[Unit]
Description=wpm tunnel ($NAME)
After=network.target

[Service]
Type=simple
ExecStart=$BINARY_PATH -c $CONF_DEST
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

    if systemctl daemon-reload; then
        printfc "$NORD_GREEN" "Reloaded daemon"
    else
        printfc "$NORD_RED" "Failed to reload daemon"
    fi

    if systemctl enable "$SERVICE_NAME"; then
        printfc "$NORD_GREEN" "Enabled service"
    else
        printfc "$NORD_RED" "Failed to enable service"
    fi

    if systemctl restart "$SERVICE_NAME"; then
        printfc "$NORD_GREEN" "Started service"
    else
        printfc "$NORD_RED" "Failed to start service"
    fi

    echo ""
}

wpm_ls() {
    shopt -s nullglob
    local services=(/etc/systemd/system/*-wpm.service)

    printfc "$NORD_BLUE" "\n>wpm Tunnels"

    if [[ ${#services[@]} -eq 0 ]]; then
        printfc "$NORD_RED" "No tunnels found"
        echo ""; return
    fi

    printfc "$NORD_SNOW_1" "%-25s %-12s %-10s" "SERVICE" "STATUS" "PORT"
    printfc "$NORD_POLAR_4" "─────────────────────────────────────────────────────"

    local service
    for service in "${services[@]}"; do
        _wpm_tunnel_info "$service"
        printfc "$S_COL" "%-25s %-12s %-10s" "$NAME" "$STATUS" "$PORT"
    done

    echo ""
}

_wpm_pick_tunnels() {
    local prompt="$1"

    shopt -s nullglob
    local services=(/etc/systemd/system/*-wpm.service)

    if [[ ${#services[@]} -eq 0 ]]; then
        printfc "$NORD_RED" "No tunnels found"
        return 1
    fi

    local lines=() service
    for service in "${services[@]}"; do
        _wpm_tunnel_info "$service"
        lines+=("$(printf "%-25s %-12s %-10s" "$NAME" "$STATUS" "$PORT")")
    done

    local selected
    selected=$(printf '%s\n' "${lines[@]}" | fzf -m \
        --bind=ctrl-a:toggle-all \
        --header="TAB: select | CTRL-A: toggle all | ENTER: confirm" \
        --prompt="$prompt > " --reverse --height=40%)
    if [[ -z "$selected" ]]; then
        printfc "$NORD_YELLOW" "Cancelled"
        return 1
    fi

    WPM_PICKED=()
    local name
    while IFS= read -r line; do
        name=$(awk '{print $1}' <<< "$line")
        WPM_PICKED+=("/etc/systemd/system/${name}.service")
    done <<< "$selected"
}

wpm_rm() {
    printfc "$NORD_BLUE" "\n>Uninstall Tunnel"
    _wpm_pick_tunnels "Uninstall" || { echo ""; return; }
    local to_remove=("${WPM_PICKED[@]}") service

    echo ""
    printfc "$NORD_YELLOW" "Will uninstall %s tunnel(s):" "${#to_remove[@]}"
    for service in "${to_remove[@]}"; do
        printfc "$NORD_RED" "%s" "$(basename "$service" .service)"
    done

    echo ""
    mkdir -p "$BACKUP_ROOT"
    chown -R "$REAL_USER:$REAL_USER" "$BACKUP_ROOT"

    for service in "${to_remove[@]}"; do
        local NAME=$(basename "$service" .service)
        local CONF_FILE="$CONF_DIR/${NAME%-wpm}.conf"

        if [[ -f "$CONF_FILE" ]]; then
            local backup_file="$BACKUP_ROOT/${NAME%-wpm}.conf"
            cp "$CONF_FILE" "$backup_file"
            printfc "$NORD_GREEN" "Backup: %s" "$backup_file"
        fi

        systemctl stop "$NAME"
        systemctl disable "$NAME"
        rm -f "$service" "$CONF_FILE"
        systemctl daemon-reload
        printfc "$NORD_GREEN" "Removed %s" "$NAME"
        echo ""
    done
}

_wpm_bulk_action() {
    local verb="$1" header_text="$2" past_tense="$3" prompt="$4"

    printfc "$NORD_BLUE" "\n>%s" "$header_text"
    _wpm_pick_tunnels "$prompt" || { echo ""; return; }

    local service
    for service in "${WPM_PICKED[@]}"; do
        local NAME=$(basename "$service" .service)
        if systemctl "$verb" "$NAME"; then
            printfc "$NORD_GREEN" "%s %s" "$past_tense" "$NAME"
        else
            printfc "$NORD_RED" "Failed to %s %s" "$verb" "$NAME"
        fi
    done

    echo ""
}

wpm_start()   { _wpm_bulk_action start   "Starting Tunnels"   "Started"   "Start"; }
wpm_stop()    { _wpm_bulk_action stop    "Stopping Tunnels"   "Stopped"   "Stop"; }
wpm_restart() { _wpm_bulk_action restart "Restarting Tunnels" "Restarted" "Restart"; }

# --- Router ---
case "$1" in
    add)     wpm_add "$2" "$3" "$4" ;;
    ls)      wpm_ls ;;
    rm)      wpm_rm ;;
    start)   wpm_start ;;
    stop)    wpm_stop ;;
    restart) wpm_restart ;;
    *)
        printfc "$NORD_BLUE" "\n>wpm Manager\n"
        printfc "$NORD_SNOW_1" "add <name> <conf> <port>     Install tunnel"
        printfc "$NORD_SNOW_1" "ls                           List tunnels"
        printfc "$NORD_SNOW_1" "rm                           Uninstall tunnels"
        printfc "$NORD_SNOW_1" "start                        Start tunnels"
        printfc "$NORD_SNOW_1" "stop                         Stop tunnels"
        printfc "$NORD_SNOW_1" "restart                      Restart tunnels"
        echo ""
        exit 1
        ;;
esac
